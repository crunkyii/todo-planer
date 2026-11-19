import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../services/flick_export.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/overlays.dart';
import '../widgets/ui.dart';

/// Optionen → „Flick-Shortcuts kopieren“: legt die Symbole ab, kopiert die Shortcuts und öffnet
/// die Anleitung [FlickGuidePage] (die sagt auch, dass kopiert wurde – eine Snackbar läge dahinter).
Future<void> copyFlickShortcutsAndGuide(BuildContext context) async {
  await _copy(context);
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(slideInRoute((_) => const FlickGuidePage()));
}

Future<void> _copy(BuildContext context) async {
  final app = context.app;
  final l = context.l;
  final dir = app.flick.dir;
  if (dir == null) return;
  await app.flick.writeIcons(rootBundle);
  await Clipboard.setData(ClipboardData(text: flickShortcuts(l, dir)));
}

/// Kurze Anleitung: die kopierten Shortcuts in die `config.toml` von Flick einfügen.
class FlickGuidePage extends StatefulWidget {
  const FlickGuidePage({super.key});

  @override
  State<FlickGuidePage> createState() => _FlickGuidePageState();
}

class _FlickGuidePageState extends State<FlickGuidePage> {
  /// „Nochmal kopieren“ wurde angetippt – der Knopf zeigt dann „kopiert“.
  bool _again = false;

  Future<void> _copyAgain() async {
    await _copy(context);
    if (mounted) setState(() => _again = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final s = context.app.settings;
    final steps = [
      (l.flickStep1, l.flickStep1Sub),
      (l.flickStep2, l.flickStep2Sub),
      (l.flickStep3, l.flickStep3Sub),
      (l.flickStep4, l.flickStep4Sub),
    ];
    final examples = [
      (FlickIcon.add, 'addAufgabe', l.flickAboutAdd),
      (FlickIcon.add, 'aufgabe …', l.flickAboutAddTitle),
      (FlickIcon.today, 'Aufgaben', l.flickAboutToday),
      (FlickIcon.open, 'todo …', l.flickAboutTab),
    ];
    return AppPage(
      title: l.flickGuideTitle,
      backLabel: l.back,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  l.flickGuideIntro,
                  style: TextStyle(fontSize: Fs.body, color: tok.sub),
                ),
              ),
              for (final (i, (title, sub)) in steps.indexed)
                SetRow(title: title, subtitle: sub, leading: _StepNumber(i + 1)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: _again ? l.flickCopied : l.flickCopyAgain,
                    icon: _again ? Ic.check : Ic.copy,
                    kind: BtnKind.tonal,
                    onTap: _copyAgain,
                  ),
                ),
              ),
              CapsHeading(l.flickGuideList),
              ListenableBuilder(
                listenable: s,
                builder: (context, _) => SetRow(
                  title: l.flickToday,
                  subtitle: l.flickTodaySub,
                  inline: true,
                  trailing: AppSwitch(
                    value: s.flick,
                    label: l.flickToday,
                    onChanged: (v) => s.updateDevice((x) => x.flick = v),
                  ),
                ),
              ),
              CapsHeading(l.flickGuideTry),
              for (final (icon, name, about) in examples)
                SetRow(
                  title: name,
                  subtitle: about,
                  leading: Image.asset(
                    icon.asset,
                    width: Sizes.flickIcon,
                    height: Sizes.flickIcon,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.square(dimension: Sizes.flickIcon),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Runde Nummer eines Schritts.
class _StepNumber extends StatelessWidget {
  const _StepNumber(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Container(
      width: Sizes.flickIcon,
      height: Sizes.flickIcon,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tok.pc, shape: BoxShape.circle),
      child: Text(
        '$n',
        style: TextStyle(fontSize: Fs.base, fontWeight: FontWeight.w600, color: tok.onPc),
      ),
    );
  }
}
