import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud.dart';
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

  bool online = true;
  bool syncing = false;

  /// Nur wenn `true` (App-Bildschirm mit Konto) werden Toasts gezeigt.
  bool active = false;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _again = false;

  static const _boolCols = {'done', 'deleted', 'repeat', 'remind'};
  static const _overlap = Duration(seconds: 5);

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
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', callback: (_) => schedule(pullOnly: true))
        .subscribe();
    await sync();
  }

  Future<void> detach() async {
    active = false;
    final ch = _channel;
    _channel = null;
    if (ch != null && cloud.ready) await cloud.client.removeChannel(ch);
  }

  /// Nach einer lokalen Änderung: kurz warten (mehrere Änderungen bündeln), dann hochladen.
  void schedule({bool pullOnly = false}) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: pullOnly ? 600 : 400), () => sync());
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
    try {
      await store.flush();
      await _push();
      await _pull();
      store.markSynced();
      if (announce) _events.add(const AllSynced());
    } on Object catch (e) {
      debugPrint('Sync fehlgeschlagen: ${e.runtimeType}');
    } finally {
      syncing = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      unawaited(sync());
    }
  }

  Map<String, Object?> _remote(TableSpec t, Map<String, Object?> row) => {
        for (final k in t.columns.keys) k: _boolCols.contains(k) ? row[k] == 1 || row[k] == true : row[k],
      };

  Future<void> _push() async {
    final db = cloud.client;
    for (final t in syncTables) {
      final rows = await store.db.dirtyRows(t);
      for (var i = 0; i < rows.length; i += 200) {
        final chunk = rows.sublist(i, i + 200 > rows.length ? rows.length : i + 200);
        await db.from(t.name).upsert(chunk.map((r) => _remote(t, r)).toList(), onConflict: t.keys.join(','));
        // Ein Commit pro Paket statt einem pro Zeile.
        await store.db.transaction(() async {
          for (final r in chunk) {
            await store.db.markClean(t, r);
          }
        });
      }
    }
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
        if (since != null) q = q.gt('synced_at', since);
        final rows = (await q.order('synced_at', ascending: true).limit(500)).cast<Map<String, Object?>>();
        await store.applyRemote(t, rows);
        if (rows.isEmpty) break;
        since = rows.last['synced_at'] as String;
        await settings.setCursor(t.name, since);
        if (rows.length < 500) break;
      }
    }
    final s = await db.from('settings').select().maybeSingle();
    if (s != null) settings.mergeRemote(s);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connSub?.cancel();
    _events.close();
    super.dispose();
  }
}
