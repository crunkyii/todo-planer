import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/gen/app_localizations.dart';

/// Übersetzt technische Fehler in verständliche Meldungen (Deutsch/Englisch).
String friendlyErrorMessage(AppLocalizations l, Object error) {
  if (isNetworkError(error)) return l.errNetwork;

  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return l.errWrongLogin;
      case 'email_not_confirmed':
        return l.errEmailNotConfirmed;
      case 'user_already_exists':
      case 'email_exists':
        return l.errAccountExists;
      case 'weak_password':
        return l.errWeakPassword;
      case 'email_address_invalid':
      case 'validation_failed':
        return l.errEmail;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return l.errRateLimit;
      case 'signup_disabled':
        return l.errSignupDisabled;
      case 'session_expired':
      case 'refresh_token_not_found':
        return l.errSessionExpired;
    }
    if (error.statusCode == '400' && error.message.toLowerCase().contains('invalid login')) {
      return l.errWrongLogin;
    }
    return l.errAuthGeneric(error.message);
  }

  if (error is PostgrestException) {
    if (error.code == '42501') return l.errNoPermission;
    if (error.code == '42P01' || error.code == 'PGRST205') return l.errTableMissing;
    return l.errDbGeneric(error.message);
  }

  return l.errUnexpected;
}

bool isNetworkError(Object error) {
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
