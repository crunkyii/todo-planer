import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';

/// Gemeinsamer Rahmen für Einrichtung und Anmeldung (.login): Inhalt mittig,
/// bei wenig Höhe scrollbar, höchstens 380 breit, Farbverlauf im Hintergrund.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.children, this.top, this.topPadding = 24});
  final List<Widget> children;
  final Widget? top;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final low = MediaQuery.sizeOf(context).height < 640;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlobBackground(
        child: SafeArea(
          child: Column(children: [
            ?top,
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, low ? 16 : topPadding, 24, low ? 16 : 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - (low ? 32 : topPadding + 24)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// App-Logo (.logo) mit großem Titel darunter.
class LogoTitle extends StatelessWidget {
  const LogoTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final low = MediaQuery.sizeOf(context).height < 640;
    final s = low ? 64.0 : 84.0;
    return Column(children: [
      Container(
        width: s,
        height: s,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tok.pc, borderRadius: BorderRadius.circular(low ? 20 : 26)),
        child: AppIcon(Ic.tasks, size: low ? 36 : 46, stroke: 2, color: tok.onPc),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(0, low ? 14 : 24, 0, low ? 20 : 32),
        child: Semantics(
          header: true,
          child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: low ? 24 : Fs.login, height: 36 / 28, color: tok.text)),
        ),
      ),
    ]);
  }
}
