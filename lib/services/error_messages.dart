import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Übersetzt technische Fehler in verständliche deutsche Meldungen.
String friendlyErrorMessage(Object error) {
  if (_isNetworkError(error)) {
    return 'Keine Verbindung zum Server. Bitte prüfe deine Internetverbindung.';
  }

  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'E-Mail oder Passwort ist falsch.';
      case 'email_not_confirmed':
        return 'Bitte bestätige zuerst deine E-Mail-Adresse (Link in der Bestätigungs-Mail).';
      case 'user_already_exists':
      case 'email_exists':
        return 'Für diese E-Mail-Adresse gibt es bereits ein Konto. Bitte melde dich an.';
      case 'weak_password':
        return 'Das Passwort ist zu schwach. Verwende mindestens 6 Zeichen.';
      case 'email_address_invalid':
      case 'validation_failed':
        return 'Bitte gib eine gültige E-Mail-Adresse ein.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Zu viele Versuche. Bitte warte kurz und versuche es dann erneut.';
      case 'signup_disabled':
        return 'Registrierung ist derzeit deaktiviert.';
      case 'session_expired':
      case 'refresh_token_not_found':
        return 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';
    }
    if (error.statusCode == '400' &&
        error.message.toLowerCase().contains('invalid login')) {
      return 'E-Mail oder Passwort ist falsch.';
    }
    return 'Anmeldung fehlgeschlagen: ${error.message}';
  }

  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'Keine Berechtigung für diese Aktion. Bitte melde dich erneut an.';
    }
    if (error.code == '42P01') {
      return 'Die Tabelle "todos" fehlt. Wurde supabase/schema.sql ausgeführt?';
    }
    return 'Datenbankfehler: ${error.message}';
  }

  if (error is RealtimeSubscribeException) {
    return 'Live-Synchronisation unterbrochen. Bitte prüfe deine Internetverbindung.';
  }

  return 'Unerwarteter Fehler. Bitte versuche es erneut.';
}

bool _isNetworkError(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is AuthRetryableFetchException) {
    return true;
  }
  // http.ClientException ("Failed host lookup", "Connection refused" …)
  final text = error.toString().toLowerCase();
  return text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('socketexception') ||
      text.contains('connection refused') ||
      text.contains('network is unreachable');
}
