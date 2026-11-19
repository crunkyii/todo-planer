import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings_store.dart';

/// Prüft die Eingaben der Einrichtung wie im Prototyp (`submitSetup`).
enum SetupError { url, secretKey, keyFormat }

SetupError? validateSetup(String url, String key) {
  if (!RegExp(r'^https://[a-z0-9-]+\.supabase\.(co|in)$', caseSensitive: false).hasMatch(url)) {
    return SetupError.url;
  }
  if (key.startsWith('sb_secret_') || key.contains('service_role')) return SetupError.secretKey;
  if (!RegExp(r'^sb_publishable_\S{10,}$').hasMatch(key) && !RegExp(r'^eyJ\S{40,}$').hasMatch(key)) {
    return SetupError.keyFormat;
  }
  // Alte JWT-Keys: service_role steckt Base64-kodiert im Mittelteil
  if (key.startsWith('eyJ') && _jwtRole(key) == 'service_role') return SetupError.secretKey;
  return null;
}

String? _jwtRole(String jwt) {
  final parts = jwt.split('.');
  if (parts.length < 2) return null;
  try {
    final payload = String.fromCharCodes(base64Url.decode(base64Url.normalize(parts[1])));
    return RegExp(r'"role"\s*:\s*"([^"]+)"').firstMatch(payload)?.group(1);
  } on FormatException {
    return null;
  }
}

/// Normalisiert die eingegebene URL (Leerzeichen und `/` am Ende weg).
String normalizeUrl(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

/// Echter Verbindungstest: fragt die Tabelle `categories` ab. Ohne Anmeldung liefert
/// RLS eine leere Liste – ein Fehler heißt: falsche URL/Key oder SQL nicht ausgeführt.
Future<bool> testConnection(String url, String key) async {
  final client = SupabaseClient(url, key, authOptions: const AuthClientOptions(autoRefreshToken: false));
  try {
    await client.from('categories').select('id').limit(1).timeout(const Duration(seconds: 12));
    return true;
  } on Object {
    return false;
  } finally {
    await client.dispose();
  }
}

/// Startet Supabase mit den gespeicherten Zugangsdaten (oder wechselt die Datenbank).
class Cloud {
  CloudConfig? _active;

  bool get ready => _active != null;

  /// Sind [url] und [key] eine erreichbare, eingerichtete Datenbank? (siehe [testConnection])
  Future<bool> canConnect(String url, String key) => testConnection(url, key);

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init(CloudConfig c) async {
    if (_active?.url == c.url && _active?.key == c.key) return;
    if (_active != null) await Supabase.instance.dispose();
    await Supabase.initialize(url: c.url, publishableKey: c.key);
    _active = c;
  }

  Session? get session => ready ? client.auth.currentSession : null;
  User? get user => session?.user;

  Stream<AuthState> get authChanges => ready ? client.auth.onAuthStateChange : const Stream.empty();

  Future<void> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  /// `true` = sofort angemeldet, `false` = E-Mail muss erst bestätigt werden.
  Future<bool> signUp(String email, String password) async {
    final r = await client.auth.signUp(email: email, password: password);
    return r.session != null;
  }

  Future<void> signOut() async {
    if (ready) await client.auth.signOut();
  }
}
