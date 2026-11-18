import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable.dart';
import '../../widgets/ui.dart';

// Bausteine, die mehrere Sheets teilen: Überschrift, Fehlermeldung, Knopfzeile,
// Datum/Zeit-Knopf und das Aufklapp-Kärtchen darunter.

/// Bestätigung nach dem Speichern: offline in der Cloud „Am Gerät gespeichert“.
void showSavedToast(BuildContext context, {required bool isNew}) {
  final app = context.app;
  final l = context.l;
  final off = app.offlineCloud;
  if (off) {
    app.snack.show(isNew ? l.savedOnDeviceLater : l.savedOnDevice, icon: Ic.cloudoff);
  } else {
    app.snack.show(isNew ? l.added : l.saved);
  }
}

/// Der Eintrag wurde gelöscht, während sein Sheet offen war (am anderen Gerät oder im
/// Widget): Sheet schließen und das sagen, statt den alten Stand wieder anzulegen.
void closeSheetItemGone(BuildContext context) {
  final app = context.app;
  final l = context.l;
  Navigator.pop(context);
  app.snack.show(l.itemGone);
}

/// Überschrift eines Sheets.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(fontSize: Fs.sheetTitle, height: 26 / 20, color: context.tok.text),
      ),
    ),
  );
}

/// Fehlermeldung im Sheet; Screenreader lesen sie sofort vor.
class SheetError extends StatelessWidget {
  const SheetError(this.text, {super.key, this.margin = const EdgeInsets.only(bottom: 8)});
  final String text;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: margin,
      child: Text(text, style: TextStyle(fontSize: 13, color: context.tok.err)),
    ),
  );
}

/// Löschen links, Abbrechen + Speichern rechts (.actions).
class SheetActions extends StatelessWidget {
  const SheetActions({super.key, required this.onSave, this.onDelete});
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          // Auf schmalen Handys passen die drei Knöpfe nicht nebeneinander: Dann wird nur
          // „Löschen“ etwas kleiner, Abbrechen und Speichern bleiben ganz.
          Expanded(
            child: onDelete == null
                ? const SizedBox()
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AppButton(label: l.delete, icon: Ic.trash, kind: BtnKind.danger, onTap: onDelete),
                    ),
                  ),
          ),
          AppButton(label: l.cancel, kind: BtnKind.text, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          AppButton(label: l.save, onTap: onSave),
        ],
      ),
    );
  }
}

/// Knopf mit Symbol, Untertitel und Wert (.dt-btn) – öffnet Kalender bzw. Uhrzeit-Rad.
class DateTimeButton extends StatelessWidget {
  const DateTimeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.open,
    required this.onTap,
  });
  final Ic icon;
  final String label;
  final String value;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Pressable(
      onTap: onTap,
      radius: BorderRadius.circular(Sizes.rDtBtn),
      semanticLabel: '$label: $value',
      toggled: open,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: Motion.fast,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tok.surf2,
          borderRadius: BorderRadius.circular(Sizes.rDtBtn),
          border: open ? Border.all(color: tok.p, width: 2) : null,
        ),
        child: Row(
          children: [
            AppIcon(icon, size: 22, color: tok.p),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: tok.sub)),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: tok.text,
                      fontFeatures: Fs.tabular,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aufklapp-Kärtchen unter den Datum/Zeit-Knöpfen (.dt-pop): springt auf.
class PopCard extends StatelessWidget {
  const PopCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final box = AppCard(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
      radius: Sizes.rPop,
      child: child,
    );
    if (Motion.reduced(context)) return box;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.82, end: 1),
      duration: Motion.pop,
      curve: Motion.springSoft,
      builder: (context, v, c) => Opacity(
        opacity: ((v - 0.82) / 0.18).clamp(0.0, 1.0),
        child: Transform.scale(scale: v, alignment: Alignment.topCenter, child: c),
      ),
      child: box,
    );
  }
}
