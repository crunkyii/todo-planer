import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../util/fmt.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/overlays.dart';
import '../../widgets/ui.dart';
import '../task_card.dart';
import '../ui_state.dart';
import 'sheet_parts.dart';

/// Antippen eines Blocks im Wochenplan: zeigt, wann er ist, und – wenn er aus einer Aufgabe
/// entstanden ist – diese Aufgabe mit Abgabe, Unteraufgaben und Notizen. Bearbeiten und Löschen
/// stehen im ⋮-Menü oben rechts; nichts geht beim Antippen gleich in den Bearbeiten-Modus.
class BlockViewSheet extends StatelessWidget {
  const BlockViewSheet({super.key, required this.blockId, required this.ui, required this.onEdit});
  final String blockId;
  final UiState ui;

  /// Öffnet das Formular „Block bearbeiten“ (nachdem diese Ansicht geschlossen ist).
  final ValueChanged<WeekBlock> onEdit;

  void _menu(BuildContext context, WeekBlock b, Rect rect) {
    final l = context.l;
    final app = context.app;
    Navigator.of(context).push(
      AppMenuRoute(
        anchor: rect,
        label: l.moreOptions,
        builder: (menuContext) => [
          MenuItemRow(
            entry: MenuEntry(
              label: l.edit,
              icon: Ic.edit,
              onTap: () {
                Navigator.pop(menuContext);
                Navigator.pop(context);
                onEdit(b);
              },
            ),
          ),
          MenuItemRow(
            entry: MenuEntry(
              label: l.delete,
              icon: Ic.trash,
              onTap: () {
                Navigator.pop(menuContext);
                Navigator.pop(context);
                final undo = app.store.deleteBlock(b);
                app.snack.show(l.blockDeleted, undo: undo);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final l = context.l;
        final tok = context.tok;
        final f = Fmt.of(context);
        final b = store.blockById(blockId);
        if (b == null) {
          return SheetBody(
            children: [
              Text(
                l.blockGone,
                style: TextStyle(fontSize: Fs.body, color: tok.sub),
              ),
            ],
          );
        }
        final week = b.weekStart == null ? null : DateTime.tryParse(b.weekStart!);
        final taskId = b.taskId;
        final task = taskId == null ? null : store.taskById(taskId);
        return SheetBody(
          children: [
            Row(
              children: [
                const SizedBox(width: 4),
                Dot(tok.item(b.color).c, size: Sizes.dotLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      b.name,
                      style: TextStyle(fontSize: Fs.sheetTitle, height: 26 / 20, color: tok.text),
                    ),
                  ),
                ),
                Builder(
                  builder: (btnContext) => IconBtn(
                    Ic.more,
                    label: l.moreOptions,
                    onTap: () {
                      final rect = anchorRect(btnContext);
                      if (rect != null) _menu(context, b, rect);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Info(Ic.calendar, f.wdLong(b.day)),
            _Info(Ic.clock, '${l.rangeDash(f.time(b.start), f.time(b.end))} · ${f.duration(b.end - b.start)}'),
            _Info(Ic.sync, week == null ? l.everyWeek : l.blockOnlyWeek(f.weekRange(week))),
            if (taskId != null) ...[
              CapsHeading(l.blockTask, padding: const EdgeInsets.fromLTRB(4, 20, 4, 8)),
              if (task == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    l.blockTaskGone,
                    style: TextStyle(fontSize: Fs.base, color: tok.sub),
                  ),
                )
              else
                // Dieselbe Karte wie in der Aufgabenliste: Abgabe, Unteraufgaben (abhakbar) und Notiz;
                // Antippen öffnet die ganze Aufgabe.
                TaskCard(task: task, ui: ui, highlightable: false),
            ],
          ],
        );
      },
    );
  }
}

/// Eine Zeile mit Symbol, z. B. „Mittwoch“ oder „13:10 – 14:50 · 1 Std. 40 Min.“.
class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);
  final Ic icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          AppIcon(icon, size: 18, color: tok.sub),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: Fs.base, color: tok.text, fontFeatures: Fs.tabular),
            ),
          ),
        ],
      ),
    );
  }
}
