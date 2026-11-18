import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../services/error_messages.dart';

/// Anmeldung und Registrierung per E-Mail und Passwort.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _minPasswordLength = 6;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final email = _emailController.text;
    final password = _passwordController.text;
    try {
      if (_isRegister) {
        final signedIn = await widget.authService.signUp(
          email: email,
          password: password,
        );
        if (!signedIn && mounted) {
          setState(() {
            _isRegister = false;
            _info = 'Konto angelegt. Bitte bestätige deine E-Mail-Adresse '
                'über den Link in der Mail und melde dich dann an.';
          });
        }
      } else {
        await widget.authService.signIn(email: email, password: password);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Bitte gib deine E-Mail-Adresse ein.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Das ist keine gültige E-Mail-Adresse.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Bitte gib ein Passwort ein.';
    if (_isRegister && password.length < _minPasswordLength) {
      return 'Mindestens $_minPasswordLength Zeichen.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.checklist_rounded, size: 72, color: colors.primary),
                      const SizedBox(height: 16),
                      Text(
                        _isRegister ? 'Konto erstellen' : 'Willkommen zurück',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deine Todos – synchron auf allen Geräten.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-Mail',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enabled: !_busy,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Passwort anzeigen'
                                : 'Passwort verbergen',
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          _isRegister
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        enabled: !_busy,
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _MessageBox(
                          text: _error!,
                          icon: Icons.error_outline,
                          background: colors.errorContainer,
                          foreground: colors.onErrorContainer,
                        ),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 16),
                        _MessageBox(
                          text: _info!,
                          icon: Icons.info_outline,
                          background: colors.secondaryContainer,
                          foreground: colors.onSecondaryContainer,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isRegister ? 'Registrieren' : 'Anmelden'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _isRegister = !_isRegister;
                                  _error = null;
                                  _info = null;
                                }),
                        child: Text(_isRegister
                            ? 'Schon ein Konto? Anmelden'
                            : 'Noch kein Konto? Registrieren'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: foreground))),
          ],
        ),
      ),
    );
  }
}
