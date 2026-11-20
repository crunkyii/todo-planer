import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_services.dart';
import '../data/cloud.dart';
import '../data/settings_store.dart';
import '../services/error_messages.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/pressable.dart';
import '../widgets/snack.dart';
import '../widgets/ui.dart';
import 'auth_layout.dart';
import 'language_page.dart';

/// Ersteinrichtung: Willkommen (Konto erstellen, anmelden oder ohne Konto; Sprache) und
/// „Datenbank verbinden“.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.startAtDb = false});

  /// `true` = aus Anmeldung/Optionen geöffnet („Andere Datenbank verbinden“).
  final bool startAtDb;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late bool _db = widget.startAtDb;

  /// Nach dem Verbinden „Konto erstellen“ (`true`) oder „Anmelden“ zeigen.
  bool _register = true;

  /// Über „Ich habe schon ein Konto“ gekommen: kurze Seite ohne die Einrichtungsschritte.
  bool get _existing => !widget.startAtDb && !_register;
  final _url = TextEditingController();
  final _key = TextEditingController();
  String? _error;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final c = context.app.settings.cloud;
    if (c != null && widget.startAtDb) _url.text = c.url;
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  /// Weiter zu „Datenbank verbinden“ – ohne eigene Datenbank gibt es kein Konto. [register]
  /// merkt sich, ob danach „Konto erstellen“ oder „Anmelden“ kommt.
  void _toDb({required bool register}) => setState(() {
    _register = register;
    _db = true;
  });

  void _back() {
    if (widget.startAtDb) {
      context.app.closeSetup();
    } else {
      setState(() {
        _db = false;
        _error = null;
      });
    }
  }

  Future<void> _copySql() async {
    final app = context.app;
    final msg = context.l.sqlCopied;
    final sql = await rootBundle.loadString('supabase/schema.sql');
    await Clipboard.setData(ClipboardData(text: sql));
    app.snack.show(msg, icon: Ic.copy);
  }

  Future<void> _submit() async {
    if (_connecting) return; // Enter im Feld, während der Verbindungstest schon läuft
    final l = context.l;
    final app = context.app;
    final url = normalizeUrl(_url.text);
    final key = _key.text.trim();
    final err = validateSetup(url, key);
    setState(
      () => _error = switch (err) {
        SetupError.url => l.errUrl,
        SetupError.secretKey => l.errSecretKey,
        SetupError.keyFormat => l.errKeyFormat,
        null => null,
      },
    );
    if (err != null) return;
    setState(() => _connecting = true);
    final ok = await app.cloud.canConnect(url, key);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _connecting = false;
        _error = l.errNoConnection;
      });
      return;
    }
    final c = CloudConfig(url, key);
    try {
      await app.connectCloud(c, register: _register);
    } on Object catch (e) {
      // Ohne das bliebe der Knopf für immer auf „Verbinde …“ stehen.
      debugPrint('Verbinden fehlgeschlagen: ${errorLogLine(e)}');
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = l.errNoConnection;
        });
      }
      return;
    }
    app.snack.show(l.connectedTo(c.host), icon: Ic.cloudok);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    return Stack(
      children: [
        _db ? _dbStep(context) : _welcome(context),
        SnackHost(controller: app.snack, undoLabel: l.undo, bottom: 24),
      ],
    );
  }

  Widget _welcome(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final app = context.app;
    return AuthLayout(
      children: [
        LogoTitle(l.welcome),
        Transform.translate(
          offset: const Offset(0, -20),
          child: Text(
            l.setupLead,
            textAlign: TextAlign.center,
            style: TextStyle(color: tok.sub, fontSize: 15, height: 22 / 15),
          ),
        ),
        const SizedBox(height: 4),
        _Choice(icon: Ic.sync, title: l.createAccount, text: l.setupCloudText, onTap: () => _toDb(register: true)),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppButton(label: l.haveAccount, kind: BtnKind.text, big: true, onTap: () => _toDb(register: false)),
        ),
        _Choice(icon: Ic.phone, title: l.setupLocalTitle, text: l.setupLocalText, onTap: app.chooseLocal),
        const SizedBox(height: 12),
        Center(child: LangButton(settings: app.settings)),
      ],
    );
  }

  Widget _dbStep(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final stepStyle = TextStyle(fontSize: 14.5, height: 21 / 14.5, color: tok.text);
    Widget step(int n, String text, [Widget? action]) => Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(0, -2),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tok.pc, shape: BoxShape.circle),
                child: Text(
                  '$n',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tok.onPc),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichB(text, style: stepStyle),
                  if (action != null) Padding(padding: const EdgeInsets.only(top: 6), child: action),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final openSupabase = AppButton(
      label: l.openSupabase,
      icon: Ic.ext,
      kind: BtnKind.tonal,
      height: 34,
      fontSize: 13,
      padding: 14,
      onTap: () => launchUrl(Uri.parse('https://supabase.com/dashboard'), mode: LaunchMode.externalApplication),
    );
    return AuthLayout(
      topPadding: 8,
      top: TopBar(title: l.connectDb, onBack: _back, backLabel: l.back),
      children: [
        // Wer schon ein Konto hat, hat die Datenbank längst eingerichtet: nur erklären, warum
        // die Verbindung vor der Anmeldung kommt, statt die Einrichtung noch einmal zu zeigen.
        if (_existing) ...[
          RichB(l.connectExistingLead, style: stepStyle),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 18),
            child: Align(alignment: AlignmentDirectional.centerStart, child: openSupabase),
          ),
        ] else ...[
          step(1, l.setupStep1, openSupabase),
          step(
            2,
            l.setupStep2,
            AppButton(
              label: l.copySql,
              icon: Ic.copy,
              kind: BtnKind.tonal,
              height: 34,
              fontSize: 13,
              padding: 14,
              onTap: _copySql,
            ),
          ),
          step(3, l.setupStep3),
          step(4, l.setupStep4),
          const SizedBox(height: 4),
        ],
        AppField(
          label: l.projectUrl,
          controller: _url,
          hint: l.projectUrlHint,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        AppField(
          label: l.publishableKey,
          controller: _key,
          hint: l.publishableKeyHint,
          keyboardType: TextInputType.visiblePassword, // Schlüssel: keine Wortvorschläge
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ErrorBox(_error!),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RichB(
            l.secretNote,
            style: TextStyle(fontSize: 13, height: 19 / 13, color: tok.sub),
          ),
        ),
        AppButton(label: _connecting ? l.connecting : l.connect, big: true, loading: _connecting, onTap: _submit),
      ],
    );
  }
}

/// Auswahl-Karte im Willkommen-Bildschirm (.choice).
class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.text, required this.onTap});
  final Ic icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: onTap,
        pressScale: 0.97,
        radius: BorderRadius.circular(Sizes.rChoice),
        semanticLabel: '$title. $text',
        excludeChildSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tok.card,
            borderRadius: BorderRadius.circular(Sizes.rChoice),
            boxShadow: tok.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tok.pc, borderRadius: BorderRadius.circular(16)),
                child: AppIcon(icon, size: 26, color: tok.onPc),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: tok.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: TextStyle(fontSize: 13, height: 18 / 13, color: tok.sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
