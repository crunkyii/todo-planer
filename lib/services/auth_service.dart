import 'package:supabase_flutter/supabase_flutter.dart';

/// Anmeldung, Registrierung und Abmeldung per E-Mail und Passwort.
///
/// Die Sitzung speichert supabase_flutter automatisch auf dem Gerät,
/// daher bleibt man nach einem Neustart der App angemeldet.
class AuthService {
  AuthService(this._auth);

  final GoTrueClient _auth;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Gibt `true` zurück, wenn der User sofort angemeldet ist, und `false`,
  /// wenn er erst seine E-Mail-Adresse bestätigen muss.
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _auth.signUp(email: email.trim(), password: password);
    return response.session != null;
  }

  Future<void> signOut() => _auth.signOut();
}
