import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_liste/data/cloud.dart';
import 'package:todo_liste/data/field_merge.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/settings_store.dart';

/// Kleiner nachgebauter Supabase-Server (nur PostgREST-Teile, die der Sync braucht).
/// Läuft im Test auf localhost – es wird nie eine echte Datenbank benutzt.
///
/// Nachgebaut sind: Upsert über `on_conflict`, der `sync_guard`-Trigger aus
/// `supabase/schema.sql` (je Feld gewinnt der neuere Wert, `synced_at` setzt der Server) und
/// der Abruf mit `synced_at=gte.…`, `order` und `limit` sowie die Filter `eq` und `in`.
class FakeSupabase {
  FakeSupabase._(this._server);

  final HttpServer _server;
  final Map<String, List<Map<String, Object?>>> tables = {};

  /// Liefert `true` für Zeilen, die der Server ablehnen soll (wie ein CHECK-Fehler).
  bool Function(String table, Map<String, Object?> row)? reject;

  /// `false` = Server mit älterem `schema.sql`: Er kennt die Spalte `field_times` nicht.
  bool knowsFieldTimes = true;

  /// `true` = Abrufe scheitern (Server nicht erreichbar).
  bool failReads = false;

  /// Anzahl der Anfragen je „METHODE tabelle“ (z. B. `GET tasks`).
  final Map<String, int> calls = {};

  var _clock = DateTime.utc(2026, 11, 18, 12);

  String get url => 'http://localhost:${_server.port}';

  static Future<FakeSupabase> start() async {
    final s = FakeSupabase._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen(s._handle);
    return s;
  }

  Future<void> stop() => _server.close(force: true);

  List<Map<String, Object?>> rows(String table) => tables[table] ??= [];

  /// Legt Zeilen direkt am Server ab – als hätte sie ein anderes Gerät hochgeladen.
  void seed(String table, List<Map<String, Object?>> list) {
    var at = '';
    for (final (i, row) in list.indexed) {
      // Wie echte Uploads in Paketen: höchstens 200 Zeilen teilen sich ein `synced_at`.
      if (i % 200 == 0) at = _now();
      rows(table).add({...row, 'synced_at': at});
    }
  }

  /// Ein Zeitstempel je Anfrage – wie `now()` in einer Transaktion.
  String _now() {
    _clock = _clock.add(const Duration(milliseconds: 10));
    return _clock.toIso8601String();
  }

  Future<void> _handle(HttpRequest req) async {
    final table = req.uri.pathSegments.last;
    calls['${req.method} $table'] = (calls['${req.method} $table'] ?? 0) + 1;
    final body = await utf8.decoder.bind(req).join();
    Object? out;
    var status = 200;
    if (req.method == 'POST') {
      final data = jsonDecode(body);
      final list = (data is List ? data : [data]).cast<Map>().map((m) => m.cast<String, Object?>()).toList();
      if (reject != null && list.any((r) => reject!(table, r))) {
        status = 400;
        out = {'code': '23514', 'message': 'check constraint', 'details': null, 'hint': null};
      } else if (!knowsFieldTimes && list.any((r) => r.containsKey(fieldTimesColumn))) {
        status = 400;
        out = {
          'code': 'PGRST204',
          'message': "Could not find the 'field_times' column of '$table' in the schema cache",
          'details': null,
          'hint': null,
        };
      } else {
        final keys = (req.uri.queryParameters['on_conflict'] ?? 'id').split(',');
        final at = _now();
        for (final r in list) {
          _upsert(table, keys, r, at);
        }
        status = 201;
      }
    } else {
      if (failReads) {
        req.response.statusCode = 500;
        await req.response.close();
        return;
      }
      var result = List.of(rows(table));
      for (final MapEntry(key: column, value: filter) in req.uri.queryParameters.entries) {
        if (const {'select', 'order', 'limit'}.contains(column)) continue;
        final op = filter.substring(0, filter.indexOf('.'));
        final value = filter.substring(op.length + 1);
        result = result.where((r) => _matches(r[column], op, value)).toList();
      }
      result.sort((a, b) => (a['synced_at'] as String).compareTo(b['synced_at'] as String));
      final limit = int.tryParse(req.uri.queryParameters['limit'] ?? '');
      if (limit != null && result.length > limit) result = result.sublist(0, limit);
      if ((req.headers.value('accept') ?? '').contains('vnd.pgrst.object')) {
        if (result.length == 1) {
          out = result.single;
        } else {
          status = 406;
          out = {'code': 'PGRST116', 'message': 'no rows', 'details': '0 rows', 'hint': null};
        }
      } else {
        out = result;
      }
    }
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(out == null ? '' : jsonEncode(out));
    await req.response.close();
  }

  /// Die Filter, die die App benutzt: `gte`/`gt` (Zeitstempel), `eq` und `in.(a,b)`.
  static bool _matches(Object? cell, String op, String value) {
    switch (op) {
      case 'gte' || 'gt':
        final c = DateTime.parse(cell as String).compareTo(DateTime.parse(value));
        return op == 'gte' ? c >= 0 : c > 0;
      case 'eq':
        return '$cell' == value;
      case 'in':
        final list = value.substring(1, value.length - 1).split(',').map((v) => v.replaceAll('"', ''));
        return list.contains('$cell');
      default:
        throw UnsupportedError('Filter $op');
    }
  }

  /// Lädt eine Zeile hoch wie eine ältere App-Version: nur die genannten Spalten, also ohne
  /// `field_times` – die übrigen behalten am Server ihren Wert.
  void put(String table, Map<String, Object?> row) => _upsert(table, ['id'], row, _now());

  static final _groups = {for (final t in syncTables) t.name: t.groups};

  /// Der Trigger `sync_guard` aus `supabase/schema.sql`, Zeile für Zeile nachgebaut.
  void _upsert(String table, List<String> keys, Map<String, Object?> row, String at) {
    final list = rows(table);
    final i = list.indexWhere((r) => keys.every((k) => r[k] == row[k]));
    if (i < 0) {
      list.add({...row, 'synced_at': at});
      return;
    }
    // Spalten, die nicht mitgeschickt werden, behalten ihren Wert (ON CONFLICT DO UPDATE).
    final old = list[i], neu = {...old, ...row};
    final groups = _groups[table] ?? const <String, List<String>>{};
    final oldAt = DateTime.parse(old['updated_at'] as String), newAt = DateTime.parse(neu['updated_at'] as String);
    final newTimes = groups.isEmpty ? null : validFieldTimes(neu);
    final oldTimes = groups.isEmpty ? null : validFieldTimes(old);
    if (newTimes == null || oldTimes == null) {
      // Wie früher: Ein älterer Stand darf einen neueren nicht überschreiben
      if (newAt.isBefore(oldAt)) return;
      if (groups.isNotEmpty && newTimes == null && newAt.isAtSameMomentAs(oldAt)) return;
      if (groups.isNotEmpty && newTimes == null && knowsFieldTimes) neu[fieldTimesColumn] = null;
    } else {
      // Je Gruppe gewinnt der neuere Wert
      final times = <String, DateTime>{};
      var won = false;
      for (final MapEntry(key: group, value: columns) in groups.entries) {
        final n = newTimes[group] ?? newAt, o = oldTimes[group] ?? oldAt;
        if (n.isAfter(o)) {
          won = true;
          times[group] = n;
        } else {
          times[group] = o;
          for (final c in columns) {
            neu[c] = old[c];
          }
        }
      }
      if (!won) return;
      neu[fieldTimesColumn] = encodeFieldTimes(times);
      neu['updated_at'] = (newAt.isAfter(oldAt) ? newAt : oldAt).toIso8601String();
    }
    list[i] = {...neu, 'synced_at': at};
  }
}

/// [Cloud] ohne echtes Supabase: angemeldeter Test-User, Anfragen gehen an [FakeSupabase].
class FakeCloud extends Cloud {
  FakeCloud(String url)
    : _client = SupabaseClient(
        url,
        'sb_publishable_test_key_123',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final SupabaseClient _client;
  bool signedIn = true;

  @override
  bool get ready => true;

  /// Ergebnis des Verbindungstests in der Einrichtung.
  bool reachable = true;

  @override
  Future<bool> canConnect(String url, String key) async => reachable;

  @override
  SupabaseClient get client => _client;

  /// Kein `Supabase.initialize` – der Client oben zeigt schon auf den nachgebauten Server.
  @override
  Future<void> init(CloudConfig c) async {}

  @override
  Stream<AuthState> get authChanges => const Stream.empty();

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  User? get user => signedIn
      ? const User(id: 'user-1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-01-01')
      : null;
}

/// Verbindung, die der Test ein- und ausschalten kann.
class FakeConnectivity implements Connectivity {
  final _c = StreamController<List<ConnectivityResult>>.broadcast();
  void set(bool online) => _c.add([online ? ConnectivityResult.wifi : ConnectivityResult.none]);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _c.stream;
}
