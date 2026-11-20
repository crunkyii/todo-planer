import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/settings_store.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/overlays.dart';
import '../widgets/pressable.dart';
import '../widgets/ui.dart';

/// Öffnet die Seite „Sprache“ (von den Optionen und vom Willkommen-Bildschirm).
Future<void> openLanguagePage(BuildContext context, SettingsStore settings) =>
    Navigator.of(context).push<void>(slideInRoute((_) => LanguagePage(settings: settings)));

/// Name einer Sprache in ihrer eigenen Schreibweise („Español“) – so findet man sie auch,
/// wenn die App gerade in einer fremden Sprache ist.
String nativeLangName(AppLocalizations l, String code) => switch (code) {
  'en' => l.langEn,
  'es' => l.langEs,
  'fr' => l.langFr,
  'it' => l.langIt,
  _ => l.langDe,
};

/// Name einer Sprache in der gerade eingestellten Sprache („Spanisch“).
String langNameIn(AppLocalizations l, String code) => switch (code) {
  'en' => l.langNameEn,
  'es' => l.langNameEs,
  'fr' => l.langNameFr,
  'it' => l.langNameIt,
  _ => l.langNameDe,
};

/// Gewählte Sprache in der Hauptfarbe mit Pfeil „weiter“ (Zeile „Sprache“ in den Optionen).
class LangValue extends StatelessWidget {
  const LangValue({super.key, required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nativeLangName(context.l, lang),
          style: TextStyle(fontSize: Fs.base, fontWeight: FontWeight.w500, color: tok.p),
        ),
        const SizedBox(width: 6),
        AppIcon(Ic.right, size: 18, color: tok.sub),
      ],
    );
  }
}

/// Willkommen-Bildschirm: kleiner Knopf mit der Sprache, öffnet die Seite „Sprache“.
class LangButton extends StatelessWidget {
  const LangButton({super.key, required this.settings});
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Pressable(
      onTap: () => openLanguagePage(context, settings),
      pressScale: 0.95,
      semanticLabel: '${l.languageBoth}: ${nativeLangName(l, settings.lang)}',
      excludeChildSemantics: true,
      child: Container(
        height: Sizes.selectCompactH,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
        child: LangValue(lang: settings.lang),
      ),
    );
  }
}

/// Sprache wählen: eine Karte je Sprache mit runder Flagge, dem Namen in der eigenen Sprache
/// und rechts klein in der gerade eingestellten. Antippen wechselt sofort.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, required this.settings});
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final l = context.l;
        final tok = context.tok;
        void pick(String code) => settings.update((s) => s.lang = code);
        return Material(
          color: tok.bg,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(title: l.language),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          Semantics(
                            label: l.language,
                            container: true,
                            explicitChildNodes: true,
                            child: Column(
                              children: [
                                for (final code in SettingsStore.languages)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _LangCard(
                                      code: code,
                                      selected: settings.lang == code,
                                      onTap: () => pick(code),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          _DeviceRow(
                            label: l.langSameAsDevice,
                            onTap: () =>
                                pick(SettingsStore.deviceLang(View.of(context).platformDispatcher.locale.languageCode)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kopf: zurück links, Titel in der Mitte, blauer Haken „Fertig“ rechts.
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: Row(
        children: [
          IconBtn(Ic.back, label: l.back, onTap: () => Navigator.pop(context)),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Fs.title, height: 28 / 22, color: tok.text),
              ),
            ),
          ),
          Pressable(
            onTap: () => Navigator.pop(context),
            semanticLabel: l.finish,
            excludeChildSemantics: true,
            child: Container(
              width: Sizes.doneBtnW,
              height: Sizes.doneBtnH,
              decoration: BoxDecoration(color: tok.p, borderRadius: BorderRadius.circular(Sizes.doneBtnH / 2)),
              alignment: Alignment.center,
              child: AppIcon(Ic.check, size: 20, stroke: 2.6, color: tok.onP),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  const _LangCard({required this.code, required this.selected, required this.onTap});
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    const radius = BorderRadius.all(Radius.circular(Sizes.rLangCard));
    final native = nativeLangName(l, code);
    final local = langNameIn(l, code);
    return Pressable(
      onTap: onTap,
      pressScale: 0.97,
      radius: radius,
      selected: selected,
      semanticLabel: native == local ? native : '$native, $local',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: const BoxConstraints(minHeight: Sizes.langCardH),
        padding: EdgeInsets.symmetric(horizontal: selected ? 15 : 16),
        decoration: BoxDecoration(
          color: tok.card,
          borderRadius: radius,
          border: Border.all(color: selected ? tok.p : tok.lineSoft, width: selected ? 2 : 1),
          boxShadow: selected ? tok.selectedShadow : tok.cardShadow,
        ),
        child: Row(
          children: [
            LangFlag(code),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                native,
                locale: Locale(code),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: tok.text),
              ),
            ),
            const SizedBox(width: 8),
            Text('($local)', style: TextStyle(fontSize: 13.5, color: tok.sub)),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.pop),
              switchInCurve: Motion.spring,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: selected
                  ? Padding(
                      key: const ValueKey('on'),
                      padding: const EdgeInsetsDirectional.only(start: 14),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: tok.p, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: AppIcon(Ic.check, size: 14, stroke: 3, color: tok.onP),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('off')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gestrichelte Zeile „Wie das Gerät“.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    const radius = BorderRadius.all(Radius.circular(Sizes.rLangCard));
    return Pressable(
      onTap: onTap,
      pressScale: 0.97,
      radius: radius,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: CustomPaint(
        painter: _DashedBorder(color: tok.line, radius: Sizes.rLangCard),
        child: Container(
          constraints: const BoxConstraints(minHeight: Sizes.langDeviceH),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AppIcon(Ic.phone, size: 22, color: tok.sub),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: Fs.body, color: tok.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}

/// Runde Flagge (34 px) als Hilfe beim Finden – entscheidend ist der Name der Sprache.
class LangFlag extends StatelessWidget {
  const LangFlag(this.code, {super.key, this.size = Sizes.flag});
  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: context.tok.lineSoft, spreadRadius: 1)],
      ),
      child: ClipOval(
        child: CustomPaint(size: Size.square(size), painter: _FlagPainter(code)),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.code);
  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void rect(double x, double y, double rw, double rh, Color c) =>
        canvas.drawRect(Rect.fromLTWH(x * w, y * h, rw * w, rh * h), Paint()..color = c);
    switch (code) {
      case 'de':
        rect(0, 0, 1, 1 / 3, FlagColors.deBlack);
        rect(0, 1 / 3, 1, 1 / 3, FlagColors.deRed);
        rect(0, 2 / 3, 1, 1 / 3, FlagColors.deGold);
      case 'es':
        rect(0, 0, 1, 1, FlagColors.esRed);
        rect(0, 0.25, 1, 0.5, FlagColors.esYellow);
      case 'fr':
        rect(0, 0, 1 / 3, 1, FlagColors.frBlue);
        rect(1 / 3, 0, 1 / 3, 1, FlagColors.white);
        rect(2 / 3, 0, 1 / 3, 1, FlagColors.frRed);
      case 'it':
        rect(0, 0, 1 / 3, 1, FlagColors.itGreen);
        rect(1 / 3, 0, 1 / 3, 1, FlagColors.white);
        rect(2 / 3, 0, 1 / 3, 1, FlagColors.itRed);
      default:
        // Union Jack, vereinfacht wie im Entwurf (60 × 60).
        final s = w / 60;
        rect(0, 0, 1, 1, FlagColors.ukBlue);
        Paint line(Color c, double width) => Paint()
          ..color = c
          ..strokeWidth = width * s
          ..style = PaintingStyle.stroke;
        final diag = Path()
          ..moveTo(0, 0)
          ..lineTo(w, h)
          ..moveTo(w, 0)
          ..lineTo(0, h);
        canvas.drawPath(diag, line(FlagColors.white, 12));
        canvas.drawPath(diag, line(FlagColors.ukRed, 4));
        final cross = Path()
          ..moveTo(w / 2, 0)
          ..lineTo(w / 2, h)
          ..moveTo(0, h / 2)
          ..lineTo(w, h / 2);
        canvas.drawPath(cross, line(FlagColors.white, 18));
        canvas.drawPath(cross, line(FlagColors.ukRed, 10));
    }
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.code != code;
}
