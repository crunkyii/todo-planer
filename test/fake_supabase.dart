import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_liste/data/cloud.dart';

/// Kleiner nachgebauter Supabase-Server (nur PostgREST-Teile, die der Sync braucht).
/// Läuft im Test auf localhost – es wird nie eine echte Datenbank benutzt.
///
/// Nachgebaut sind: Upsert über `on_conflict`, der `sync_guard`-Trigger aus
/// `supabase/schema.sql` (neuester Stand gewinnt, `synced_at` setzt der Server) und
/// der Abruf mit `synced_at=gte.…`, `order` und `limit`.
class FakeSupabase {
  FakeSupabase._(this._server);

  final HttpServer _server;
  final Map<String, List<Map<String, Object?>>> tables = {};

  /// Liefert `true` für Zeilen, die der Server ablehnen soll (wie ein CHECK-Fehler).
  bool Function(String table, Map<String, Object?> row)? reject;

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
      } else {
        final keys = (req.uri.queryParameters['on_conflict'] ?? 'id').split(',');
        final at = _now();
        for (final r in list) {
          _upsert(table, keys, r, at);
        }
        status = 201;
      }
    } else {
      var result = List.of(rows(table));
      final since = req.uri.queryParameters['synced_at'];
      if (since != null) {
        final op = since.substring(0, since.indexOf('.'));
        final t = DateTime.parse(since.substring(op.length + 1));
        result = result.where((r) {
          final c = DateTime.parse(r['synced_at'] as String).compareTo(t);
          return op == 'gte' ? c >= 0 : c > 0;
        }).toList();
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

  void _upsert(String table, List<String> keys, Map<String, Object?> row, String at) {
    final list = rows(table);
    final i = list.indexWhere((r) => keys.every((k) => r[k] == row[k]));
    if (i < 0) {
      list.add({...row, 'synced_at': at});
      return;
    }
    // sync_guard: Ein älterer Stand darf einen neueren nicht überschreiben
    final old = DateTime.parse(list[i]['updated_at'] as String);
    if (DateTime.parse(row['updated_at'] as String).isBefore(old)) return;
    list[i] = {...list[i], ...row, 'synced_at': at};
  }
}

/// [Cloud] ohne echtes Supabase: angemeldeter Test-User, Anfragen gehen an [FakeSupabase].
class FakeCloud extends Cloud {
  FakeCloud(String url)
    : _client = SupabaseClient(url, 'sb_publishable_test_key_123', authOptions: const AuthClientOptions(autoRefreshToken: false));

  final SupabaseClient _client;
  bool signedIn = true;

  @override
  bool get ready => true;

  @override
  SupabaseClient get client => _client;

  @override
  User? get user => signedIn
      ? const User(id: 'user-1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-01-01')
      : null;
}
