import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud.dart';
import 'field_merge.dart';
import 'local_db.dart';
import 'models.dart';
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
    if (!bringsNews(change.table, change.newRecord)) return;
    schedule(remote: true);
  }

  /// Bringt eine Realtime-Meldung etwas Neues? Das eigene Echo nicht – sonst stieße jeder
  /// Upload gleich den nächsten Abgleich an. Im Zweifel (unbekannte Tabelle, unlesbare Zeile) ja.
  @visibleForTesting
  bool bringsNews(String table, Map<String, Object?> row) {
    if (row.isEmpty) return true;
    try {
      if (table == 'settings') return DateTime.parse(row['updated_at'] as String).isAfter(settings.updatedAt);
      final spec = syncTables.where((t) => t.name == table).firstOrNull;
      return spec == null || store.isNews(spec, row);
    } on Object {
      return true; // Zeile ohne lesbaren Zeitstempel: lieber einmal zu oft abgleichen.
    }
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

  /// Stand der Einstellungen, der schon ohne Sprache oben ist (älteres schema.sql kennt sie
  /// nicht). Er wird nicht bei jedem Abgleich neu gesendet – erst nach der nächsten Änderung
  /// oder dem nächsten Start wird die Sprache wieder versucht.
  DateTime? _sentWithoutLang;

  Future<void>? _running;

  /// Zählt die Abgleiche – daran merkt das Nachladen, ob währenddessen einer gelaufen ist.
  int _syncRuns = 0;

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
    _syncRuns++;
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
  /// je Feld als JSON-Objekt (lokal stehen sie als Text). Spalten, die der Server noch nicht
  /// kennt ([_missing]), bleiben weg – ohne `field_times` gilt dort wie früher die ganze Zeile.
  Map<String, Object?> _remote(TableSpec t, Map<String, Object?> row) => {
    for (final k in t.columns.keys)
      if (!_missing.contains('${t.name}.$k'))
        k: k == fieldTimesColumn
            ? decodeFieldTimes(row[k])
            : t.bools.contains(k)
            ? row[k] == 1 || row[k] == true
            : row[k],
  };

  /// Spalten, die spätere Versionen von `schema.sql` dazubringen. Fehlen sie am Server (das neue
  /// `schema.sql` ist noch nicht ausgeführt), geht der Abgleich ohne sie weiter.
  static const _optionalColumns = {fieldTimesColumn, 'task_id', 'remind_min'};

  /// Die davon, die der Server abgelehnt hat (`tabelle.spalte`) – bis zum nächsten App-Start
  /// oder bis ein Abruf die Spalte bringt.
  final Set<String> _missing = {};

  /// Der Server kennt eine Spalte nicht: einmal je App-Start melden. Ist es eine der
  /// [_optionalColumns], geht es ohne sie weiter, statt die Warteschlange zu blockieren.
  /// Gibt zurück, ob es sich lohnt, das Hochladen gleich noch einmal zu versuchen.
  bool _unknownColumn(TableSpec t, PostgrestException e) {
    if (e.code != 'PGRST204') return false; // „Spalte nicht gefunden“
    _schemaHint();
    final col = _optionalColumns
        .where((c) => !_missing.contains('${t.name}.$c') && e.message.contains("'$c'"))
        .firstOrNull;
    if (col == null) return false;
    _missing.add('${t.name}.$col');
    if (col != fieldTimesColumn) unawaited(settings.addUnsent('${t.name}.$col'));
    return true;
  }

  /// Bringt der Abruf eine Spalte, die bisher gefehlt hat (das neue `schema.sql` ist
  /// ausgeführt), gehen ihre Werte von diesem Gerät nachträglich hoch. Der Server hat die
  /// Zeilen schon, aber ohne den Wert – sonst gälte dort (und bald auch hier) der Standardwert.
  /// Vor [Store.applyRemote] aufrufen. Gibt zurück, ob etwas hochzuladen ist.
  Future<bool> _sendLater(TableSpec t, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return false;
    var any = false;
    for (final c in _optionalColumns) {
      final key = '${t.name}.$c';
      if (!rows.first.containsKey(c)) continue;
      _missing.remove(key);
      if (!settings.unsent.contains(key)) continue;
      any = store.resend(t, c) || any;
      await settings.removeUnsent(key);
    }
    return any;
  }

  /// Einmal je Sitzung: „Bitte schema.sql neu ausführen“.
  void _schemaHint() {
    if (_schemaHintShown) return;
    _schemaHintShown = true;
    _events.add(const SchemaOutdated());
  }

  Future<void> _push() async {
    final db = cloud.client;
    var bad = 0;
    for (final t in syncTables) {
      Future<void> send(Object rows) => db.from(t.name).upsert(rows, onConflict: t.keys.join(','));
      final rows = await store.dirtyRows(t);
      for (var i = 0; i < rows.length; i += _pushChunk) {
        final chunk = rows.sublist(i, i + _pushChunk > rows.length ? rows.length : i + _pushChunk);
        var ok = chunk;
        try {
          // Fehlt am Server eine Spalte, gleich noch einmal ohne sie (es können mehrere fehlen).
          while (true) {
            try {
              await send([for (final r in chunk) _remote(t, r)]);
              break;
            } on PostgrestException catch (e) {
              if (!_unknownColumn(t, e)) rethrow;
            }
          }
        } on PostgrestException {
          // Lehnt der Server ein Paket ab, Zeile für Zeile versuchen: Eine fehlerhafte Zeile
          // darf nicht die ganze Warteschlange blockieren. Sie bleibt `dirty` und wird gezählt.
          ok = [];
          for (final r in chunk) {
            try {
              await send(_remote(t, r));
              ok.add(r);
            } on PostgrestException catch (e) {
              bad++;
              debugPrint('Zeile in ${t.name} abgelehnt: ${e.code}');
              _unknownColumn(t, e);
            }
          }
        }
        await store.markClean(t, ok);
      }
    }
    rejected = bad;
    if (settings.dirty && settings.updatedAt != _sentWithoutLang) {
      final at = settings.updatedAt;
      Future<void> send(Map<String, Object?> row) => db.from('settings').upsert(row, onConflict: 'user_id');
      try {
        await send(settings.toRow());
        settings.markSettingsClean(at);
      } on PostgrestException catch (e) {
        // Älteres schema.sql kennt neue Sprachen noch nicht (CHECK auf `lang`): Den Rest trotzdem
        // hochladen und weiter abgleichen. Die Einstellungen bleiben vorgemerkt, damit die Sprache
        // nachkommt, sobald die Datenbank aktualisiert ist.
        if (e.code != '23514') rethrow;
        _schemaHint();
        await send(settings.toRow()..remove('lang'));
        _sentWithoutLang = at;
      }
    }
  }

  Future<void> _pull() async {
    final db = cloud.client;
    var again = false;
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
        again = await _sendLater(t, rows) || again;
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
    if (again) {
      await store.flush();
      await _push();
    }
  }

  // ---------- Ältere erledigte Aufgaben nachladen ----------

  /// So viele ältere erledigte Aufgaben kommen je Tipp auf „laden“ – und so viele IDs passen
  /// gut in eine Anfrage.
  static const olderPage = 50;

  /// Ob ältere erledigte Aufgaben gerade nachgeladen werden können (online und angemeldet).
  bool get canLoadOlder => _canSync && online;

  /// Läuft gerade ein Nachladen?
  bool loadingOlder = false;

  /// Aufgaben und Unteraufgaben zu den [ids], beides gleichzeitig abgerufen.
  ///
  /// Nie neben einem Abgleich: Brächte der inzwischen eine Änderung an einer dieser Aufgaben,
  /// wäre das hier Geholte schon veraltet. Dann wird noch einmal geholt.
  Future<(List<Map<String, Object?>>, List<Map<String, Object?>>)> _olderRows(List<String> ids) async {
    for (var attempt = 0; ; attempt++) {
      await idle();
      final run = _syncRuns;
      final rows = await (_rowsFor(tasksTable, 'id', ids), _rowsFor(subtasksTable, 'task_id', ids)).wait;
      if (run == _syncRuns || attempt == 2) return rows;
    }
  }

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
      final (tasks, subs) = await _olderRows(ids);
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

  /// Für den Export: alle älteren erledigten Aufgaben, die noch nicht nachgeladen sind – nur als
  /// Liste. Sie kommen nicht in die Aufgabenliste (sonst träfe „Erledigte löschen“ danach alle).
  /// `null`, wenn es nicht geklappt hat (offline, Server nicht erreichbar).
  Future<List<Task>?> fetchOlderDone() async {
    final ids = store.olderIdsToLoad(limit: store.olderWaiting());
    if (ids.isEmpty) return const [];
    if (!canLoadOlder) return null;
    try {
      final (tasks, subs) = await _olderRows(ids);
      return store.readOlder(tasks, subs);
    } on Object catch (e) {
      debugPrint('Nachladen fehlgeschlagen: ${e.runtimeType}');
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connSub?.cancel();
    _events.close();
    super.dispose();
  }
}
