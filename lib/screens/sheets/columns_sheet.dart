import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../data/settings_store.dart';
import '../../theme/tokens.dart';
import '../../util/task_logic.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/select.dart';
import '../../widgets/ui.dart';
import '../tasks_board.dart';
import 'sheet_parts.dart';

/// Aufgaben am PC: wie viele Listen nebeneinander stehen, welche Zeiträume es gibt und
/// welche Kategorien eine eigene Liste bekommen. Jede Änderung gilt sofort (nur an diesem Gerät).
/// Die eigenen Spalten selbst gibt es auf allen Geräten.
class ColumnsSheet extends StatelessWidget {
  const ColumnsSheet({super.key, required this.board, required this.onEdit});

  /// Am PC (Listen nebeneinander) gibt es zusätzlich die Anzahl, die nebeneinander steht.
  final bool board;

  /// Eigene Spalte bearbeiten oder (`null`) eine neue anlegen.
  final ValueChanged<BoardColumn?> onEdit;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final l = context.l;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.store]),
      builder: (context, _) {
        final s = app.settings;
        Widget toggle(String title, bool on, ValueChanged<bool> onChanged, {Color? color, VoidCallback? onEdit}) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (color != null) ...[Dot(color), const SizedBox(width: 10)],
                  Expanded(
                    child: Text(title, style: TextStyle(fontSize: 16, color: context.tok.text)),
                  ),
                  if (onEdit != null) IconBtn(Ic.edit, label: l.editNamed(title), size: 20, onTap: onEdit),
                  AppSwitch(value: on, label: title, onChanged: onChanged),
                ],
              ),
            );
        return SheetBody(
          footer: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(label: l.close, onTap: () => Navigator.pop(context)),
            ),
          ],
          children: [
            SheetTitle(l.columns),
            if (board)
              SelectRow<int>(
                title: l.columnsVisible,
                padding: const EdgeInsets.symmetric(vertical: 8),
                options: [
                  for (var n = SettingsStore.boardVisibleMin; n <= SettingsStore.boardVisibleMax; n++) (n, '$n'),
                ],
                value: s.boardVisible,
                onChanged: (v) => s.updateDevice((x) => x.boardVisible = v),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                board ? '${l.columnsNarrowHint} ${l.columnsDragHint}' : l.columnsDragHintTouch,
                style: TextStyle(fontSize: Fs.meta, color: context.tok.sub),
              ),
            ),
            LabeledField(
              label: l.columnsPeriods,
              child: Column(
                children: [
                  for (final sec in Section.values)
                    toggle(
                      sectionLabel(l, sec),
                      !s.boardHidden.contains(sec.name),
                      (on) => s.updateDevice((x) => on ? x.boardHidden.remove(sec.name) : x.boardHidden.add(sec.name)),
                    ),
                ],
              ),
            ),
            LabeledField(
              label: l.columnsOwn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in app.store.boardColumns)
                    toggle(
                      c.name,
                      !s.boardHidden.contains(c.listId),
                      (on) => s.updateDevice((x) => on ? x.boardHidden.remove(c.listId) : x.boardHidden.add(c.listId)),
                      color: context.tok.item(c.color).c,
                      onEdit: () => onEdit(c),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton(label: l.addColumn, icon: Ic.plus, kind: BtnKind.text, onTap: () => onEdit(null)),
                  ),
                ],
              ),
            ),
            if (app.store.categories.isNotEmpty)
              LabeledField(
                label: l.columnsCategories,
                child: Column(
                  children: [
                    for (final c in app.store.categories)
                      toggle(
                        c.name,
                        s.boardCats.contains(c.id),
                        (on) => s.updateDevice((x) => on ? x.boardCats.add(c.id) : x.boardCats.remove(c.id)),
                        color: context.tok.item(c.color).c,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
