import 'dart:convert' show utf8;

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../services/error_messages.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/snack.dart';
import '../widgets/ui.dart';
import 'auth_layout.dart';

/// Anmelden bzw. Konto erstellen – nur einmal pro Gerät, danach bleibt man angemeldet.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  late bool _register;
  bool _showPw = false;
  bool _busy = false;
  String? _error;

  /// Supabase (bcrypt) nimmt höchstens 72 Bytes. Bei Buchstaben und Ziffern sind das 72 Zeichen;
  /// Umlaute und Emoji zählen mehrfach – daher wird in Bytes geprüft.
  static const maxPasswordBytes = 72;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    final app = context.app;
    _register = app.registerNext;
    app.registerNext = false;
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return; // Enter im Feld, während die Anmeldung schon läuft
    final l = context.l;
    final app = context.app;
    final email = _email.text.trim(), pw = _pw.text;
    String? err;
    if (!_emailRe.hasMatch(email)) {
      err = l.errEmail;
    } else if (pw.isEmpty) {
      err = l.errPassword;
    } else if (_register && pw.length < 6) {
      err = l.errPasswordShort;
    } else if (_register && utf8.encode(pw).length > maxPasswordBytes) {
      err = l.errPasswordLong;
    }
    setState(() => _error = err);
    if (err != null) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        final signedIn = await app.cloud.signUp(email, pw);
        if (signedIn) {
          app.snack.show(l.accountCreatedHint, icon: Ic.database);
        } else {
          app.snack.show(l.confirmEmailHint, icon: Ic.database);
          if (mounted) setState(() => _register = false);
        }
      } else {
        await app.cloud.signIn(email, pw);
      }
    } on Object catch (e) {
      // Nur Art und Code ins Log – die Meldung selbst kann die E-Mail-Adresse enthalten.
      debugPrint('Anmeldung fehlgeschlagen: ${errorLogLine(e)}');
      if (mounted) setState(() => _error = friendlyErrorMessage(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final app = context.app;
    final host = app.settings.cloud?.host;
    return Stack(
      children: [
        AutofillGroup(
          child: AuthLayout(
            children: [
              LogoTitle(_register ? l.createAccount : l.signIn),
              AppField(
                label: l.email,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
              ),
              AppField(
                label: l.password,
                controller: _pw,
                obscure: !_showPw,
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 1),
                  child: IconBtn(
                    _showPw ? Ic.eyeoff : Ic.eye,
                    size: 22,
                    label: _showPw ? l.hidePassword : l.showPassword,
                    onTap: () => setState(() => _showPw = !_showPw),
                  ),
                ),
              ),
              if (_error != null) ErrorBox(_error!),
              AppButton(label: _register ? l.signUp : l.signIn, big: true, loading: _busy, onTap: _submit),
              const SizedBox(height: 4),
              AppButton(
                label: _register ? l.haveAccount : l.signUp,
                kind: BtnKind.text,
                big: true,
                onTap: () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
              ),
              if (host != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: AppButton(
                    label: host,
                    icon: Ic.database,
                    kind: BtnKind.text,
                    color: tok.sub,
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    onTap: app.openSetup,
                  ),
                ),
              ],
            ],
          ),
        ),
        SnackHost(controller: app.snack, undoLabel: l.undo, bottom: 24),
      ],
    );
  }
}
