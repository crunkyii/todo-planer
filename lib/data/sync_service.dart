import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud.dart';
import 'field_merge.dart';
import 'local_db.dart';
import 'settings_store.dart';
import 'store.dart';

/// Meldungen für die kurzen Toasts beim Offline-/Online-Wechsel.
sealed class SyncEvent {
  const SyncEvent();
}

class WentOffline extends SyncEvent {
  const WentOffline();
}

class BackOnline extends SyncEvent {
  const BackOnline(this.pending);
  final int pending;
}

class AllSynced extends SyncEvent {
  const AllSynced();
}

/// Der Server kennt eine Spalte nicht, die die App schickt: `supabase/schema.sql` ist älter als
/// die App und muss in Supabase noch einmal ausgeführt werden.
class SchemaOutdated extends SyncEvent {
  const SchemaOutdated();
}

/// Offline-First-Sync: Änderungen liegen zuerst lokal (Warteschlange = Zeilen mit `dirty = 1`)
/// und werden hochgeladen, sobald das Gerät online und angemeldet ist.
/// Danach werden neue Zeilen vom Server geholt (alles mit `synced_at` nach dem letzten Abruf).
class SyncService extends ChangeNotifier {
  SyncService({required this.store, required this.settings, required this.cloud, this.connectivity});

  final Store store;
  final SettingsStore settings;
  final Cloud cloud;
  final Connectivity? connectivity;

  final _events = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get events => _events.stream;

  /// Hat das Gerät gerade Netz? (Ob der Server erreichbar ist, zeigt erst der Abgleich.)
  bool online = true;

  /// Läuft gerade ein Abgleich?
  bool syncing = false;

  /// Nur wenn `true` (App-Bildschirm mit Konto) werden Toasts gezeigt.
  bool active = false;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _again = false;

  static const _overlap = Duration(seconds: 5);

  /// So viele Zeilen gehen in einem Paket hoch …
  static const _pushChunk = 200;

  /// … und so viele kommen je Seite herunter. Muss größer als [_pushChunk] sein: Ein Paket
  /// bekommt am Server einen gemeinsamen `synced_at`, und der Abruf blättert nach `synced_at`.
  static const _pullPage = 500;

  bool get _canSync => settings.syncMode == SyncMode.cloud && cloud.ready && cloud.user != null;

  Future<void> start() async {
    final c = connectivity ?? Connectivity();
    try {
      online = _isOnline(await c.checkConnectivity());
    } on Object {
      online = true;
    }
    _connSub ??= c.onConnectivityChanged.listen((r) => _setOnline(_isOnline(r)));
  }

  static bool _isOnline(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  void _setOnline(bool now) {
    if (now == online) return;
    online = now;
    notifyListeners();
    if (!active || settings.syncMode != SyncMode.cloud) return;
    if (!now) {
      _events.add(const WentOffline());
      return;
    }
    final n = store.pending + (settings.dirty ? 1 : 0);
    _events.add(BackOnline(n));
    unawaited(sync(announce: n > 0));
  }

  /// Nach dem Anmelden: Realtime abonnieren und alles abgleichen.
  Future<void> attach() async {
    active = true;
    if (!_canSync) return;
    await _channel?.unsubscribe();
    _channel = cloud.client
        .channel('todo-sync')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', callback: _onRemoteChange)
        // Nach jedem (Neu-)Verbinden des Kanals nachholen, was in der Zwischenzeit passiert ist.
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) schedule(remote: true);
        });
    await sync();
  }

  /// Realtime meldet jede Änderung – auch den eigenen Upload. Abgeglichen wird nur, wenn die
  /// Zeile hier fehlt oder älter ist; sonst liefe nach jeder eigenen Änderung ein zweiter
  /// voller Durchgang. Im Zweifel (unbekannte Tabelle, unlesbare Zeile) wird abgeglichen.
  void _onRemoteChange(PostgresChangePayload change) {
    try {
      final table = syncTables.where((t) => t.name == change.table).firstOrNull;
      if (table != null && change.newRecord.isNotEmpty && !store.isNews(table, change.newRecord)) return;
    } on Object {
      // Zeile ohne lesbaren Zeitstempel: lieber einmal zu oft abgleichen.
    }
    schedule(remote: true);
  }

  Future<void> detach() async {
    active = false;
    final ch = _channel;
    _channel = null;
    if (ch != null && cloud.ready) await cloud.client.removeChannel(ch);
  }

  /// Plant einen Abgleich: kurz warten, damit mehrere Änderungen in einen Durchgang fallen.
  /// [remote] = der Anstoß kam vom Server oder vom Zurückkommen in die App (etwas länger warten,
  /// weil solche Meldungen oft im Bündel eintreffen). Abgeglichen wird immer in beide Richtungen.
  void schedule({bool remote = false}) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: remote ? 600 : 400), () => sync());
  }

  /// Wird nach jedem erfolgreichen Abruf vom Server aufgerufen.
  void Function()? onPulled;

  /// Zeilen, die der Server beim letzten Hochladen abgelehnt hat (bleiben in der Warteschlange).
  int rejected = 0;

  bool _schemaHintShown = false;

  Future<void>? _running;

  /// Wartet, bis ein gerade laufender Abgleich fertig ist (z. B. vor dem Abmelden).
  Future<void> idle() async {
    while (_running != null) {
      await _running;
    }
  }

  /// Lädt die Warteschlange hoch und holt Neues vom Server.
  Future<void> sync({bool announce = false}) async {
    if (!_canSync || !online) return;
    if (syncing) {
      _again = true;
      return;
    }
    syncing = true;
    notifyListeners();
    final done = Completer<void>();
    _running = done.future;
    try {
      await store.flush();
      await _push();
      await _pull();
      // Erst jetzt ist alles oben: ältere erledigte Aufgaben liegen ab hier nur noch online.
      await store.archiveOldDone();
      store.markSynced();
      onPulled?.call();
      if (announce && rejected == 0) _events.add(const AllSynced());
    } on Object catch (e) {
      debugPrint('Sync fehlgeschlagen: ${e.runtimeType}');
    } finally {
      syncing = false;
      _running = null;
      done.complete();
      notifyListeners();
    }
    if (_again) {
      _again = false;
      unawaited(sync());
    }
  }

  /// Die Zeile, wie Supabase sie erwartet: Wahrheitswerte als `true`/`false`, die Zeitstempel
  /// je Feld als JSON-Objekt (lokal stehen sie als Text). Kennt der Server die Spalte
  /// `field_times` noch nicht, bleibt sie weg – dann gilt dort wie früher die ganze Zeile.
  Map<String, Object?> _remote(TableSpec t, Map<String, Object?> row) => {
    for (final k in t.columns.keys)
      if (k != fieldTimesColumn)
        k: t.bools.contains(k) ? row[k] == 1 || row[k] == true : row[k]
      else if (_serverMergesFields)
        k: switch (row[k]) {
          final String s => jsonDecode(s),
          final other => other,
        },
  };

  /// `false`, sobald der Server die Spalte `field_times` ablehnt (älteres `schema.sql`).
  bool _serverMergesFields = true;

  /// Der Server kennt eine Spalte nicht: einmal je App-Start melden. Ist es `field_times`,
  /// geht es ohne diese Spalte weiter, statt die Warteschlange zu blockieren.
  /// Gibt zurück, ob es sich lohnt, das Hochladen gleich noch einmal zu versuchen.
  bool _unknownColumn(PostgrestException e) {
    if (e.code != 'PGRST204') return false; // „Spalte nicht gefunden“
    if (!_schemaHintShown) {
      _schemaHintShown = true;
      _events.add(const SchemaOutdated());
    }
    final retry = _serverMergesFields && e.message.contains(fieldTimesColumn);
    if (retry) _serverMergesFields = false;
    return retry;
  }

  Future<void> _push() async {
    final db = cloud.client;
    var bad = 0;
    for (final t in syncTables) {
      final rows = await store.dirtyRows(t);
      for (var i = 0; i < rows.length; i += _pushChunk) {
        final chunk = rows.sublist(i, i + _pushChunk > rows.length ? rows.length : i + _pushChunk);
        var ok = chunk;
        try {
          try {
            await db.from(t.name).upsert(chunk.map((r) => _remote(t, r)).toList(), onConflict: t.keys.join(','));
          } on PostgrestException catch (e) {
            if (!_unknownColumn(e)) rethrow;
            await db.from(t.name).upsert(chunk.map((r) => _remote(t, r)).toList(), onConflict: t.keys.join(','));
          }
        } on PostgrestException {
          // Lehnt der Server ein Paket ab, Zeile für Zeile versuchen: Eine fehlerhafte Zeile
          // darf nicht die ganze Warteschlange blockieren. Sie bleibt `dirty` und wird gezählt.
          ok = [];
          for (final r in chunk) {
            try {
              await db.from(t.name).upsert(_remote(t, r), onConflict: t.keys.join(','));
              ok.add(r);
            } on PostgrestException catch (e) {
              bad++;
              debugPrint('Zeile in ${t.name} abgelehnt: ${e.code}');
              _unknownColumn(e);
            }
          }
        }
        await store.markClean(t, ok);
      }
    }
    rejected = bad;
    if (settings.dirty) {
      final at = settings.updatedAt;
      await db.from('settings').upsert(settings.toRow(), onConflict: 'user_id');
      settings.markSettingsClean(at);
    }
  }

  Future<void> _pull() async {
    final db = cloud.client;
    for (final t in syncTables) {
      final saved = settings.pullCursor[t.name];
      // Beim ersten Abruf etwas Überlappung, damit gleichzeitig gespeicherte Zeilen nicht fehlen
      // (doppelt geladene Zeilen schaden nicht: der neueste Stand gewinnt).
      String? since = saved == null ? null : DateTime.parse(saved).subtract(_overlap).toUtc().toIso8601String();
      while (true) {
        var q = db.from(t.name).select();
        // `gte` statt `gt`: Ein Paket (höchstens [_pushChunk] Zeilen) hat beim Server dasselbe
        // `synced_at`. Fällt eine Seitengrenze mitten hinein, kommt der Rest so auf der nächsten
        // Seite. Doppelt geladene Zeilen schaden nicht; weil ein Paket kleiner als eine Seite
        // ist, geht es immer weiter.
        if (since != null) q = q.gte('synced_at', since);
        final rows = (await q.order('synced_at', ascending: true).limit(_pullPage)).cast<Map<String, Object?>>();
        // Kommt eine ausgelagerte Aufgabe verändert zurück, zuerst ihre Unteraufgaben holen –
        // scheitert das, wird die Seite beim nächsten Abgleich noch einmal geladen.
        final back = t.name == 'tasks' ? store.returningFromArchive(rows) : const <String>[];
        final subs = await _rowsFor(subtasksTable, 'task_id', back);
        await store.applyRemote(t, rows);
        await store.applyRemote(subtasksTable, subs);
        if (rows.isEmpty) break;
        since = rows.last['synced_at'] as String;
        await settings.setCursor(t.name, since);
        if (rows.length < _pullPage) break;
      }
    }
    final s = await db.from('settings').select().maybeSingle();
    if (s != null) settings.mergeRemote(s);
  }

  // ---------- Ältere erledigte Aufgaben nachladen ----------

  /// So viele ältere erledigte Aufgaben kommen je Tipp auf „laden“ – und so viele IDs passen
  /// gut in eine Anfrage.
  static const olderPage = 50;

  /// Ob ältere erledigte Aufgaben gerade nachgeladen werden können (online und angemeldet).
  bool get canLoadOlder => _canSync && online;

  /// Läuft gerade ein Nachladen?
  bool loadingOlder = false;

  /// Alle Zeilen von [t], deren [column] einen der Werte [ids] hat.
  Future<List<Map<String, Object?>>> _rowsFor(TableSpec t, String column, List<String> ids) async {
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < ids.length; i += olderPage) {
      final chunk = ids.sublist(i, i + olderPage > ids.length ? ids.length : i + olderPage);
      out.addAll((await cloud.client.from(t.name).select().inFilter(column, chunk)).cast<Map<String, Object?>>());
    }
    return out;
  }

  /// Holt die nächsten älteren erledigten Aufgaben vom Server – nur in den Speicher, nicht in
  /// die lokale Datenbank. Auf Wunsch nur die einer Kategorie oder eines Abgabetags.
  /// `false`, wenn es nicht geklappt hat (offline, Server nicht erreichbar).
  Future<bool> loadOlderDone({String? categoryId, String? dueDay, int limit = olderPage}) async {
    if (!canLoadOlder || loadingOlder) return false;
    final ids = store.olderIdsToLoad(categoryId: categoryId, dueDay: dueDay, limit: limit);
    if (ids.isEmpty) return true;
    loadingOlder = true;
    notifyListeners();
    try {
      final tasks = await _rowsFor(tasksTable, 'id', ids);
      final subs = await _rowsFor(subtasksTable, 'task_id', ids);
      store.addOlder(ids, tasks, subs);
      return true;
    } on Object catch (e) {
      debugPrint('Nachladen fehlgeschlagen: ${e.runtimeType}');
      return false;
    } finally {
      loadingOlder = false;
      notifyListeners();
    }
  }

  /// Holt alle älteren erledigten Aufgaben (für den Export). `false`, wenn welche fehlen.
  Future<bool> loadAllOlderDone() async {
    while (store.olderWaiting() > 0) {
      if (!await loadOlderDone(limit: _pullPage)) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connSub?.cancel();
    _events.close();
    super.dispose();
  }
}
