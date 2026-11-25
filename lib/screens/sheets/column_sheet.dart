import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/color_math.dart';
import '../../theme/tokens.dart';
import '../../util/task_logic.dart';
import '../../widgets/pickers.dart';
import '../../widgets/select.dart';
import '../../widgets/ui.dart';
import '../tasks_board.dart';
import 'sheet_parts.dart';

/// Eigene Spalte anlegen oder bearbeiten: Name, Farbe und – freiwillig – Filter nach Kategorien,
/// Zeiträumen, Status und Text.
class ColumnSheet extends StatefulWidget {
  const ColumnSheet({super.key, required this.column});
  final BoardColumn? column;

  @override
  State<ColumnSheet> createState() => _ColumnSheetState();
}

class _ColumnSheetState extends State<ColumnSheet> {
  late final _name = TextEditingController(text: widget.column?.name ?? '');
  late final _query = TextEditingController(text: widget.column?.query ?? '');
  late String _color = widget.column?.color ?? ColorPreset.skyBlue.hex;
  late final Set<String> _categories = {...?widget.column?.categories};
  late final Set<String> _periods = {...?widget.column?.periods};
  late ColumnStatus _status = widget.column?.status ?? ColumnStatus.all;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  void _save() {
    final l = context.l;
    final app = context.app;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.errName);
      return;
    }
    // Der Stand von jetzt, nicht der vom Öffnen (siehe TaskSheet).
    final opened = widget.column;
    final c = opened == null ? null : app.store.boardColumnById(opened.id);
    if (opened != null && c == null) return closeSheetItemGone(context);
    // In der Reihenfolge der Liste; gelöschte Kategorien fallen weg. Nur wenn sonst keine bliebe,
    // bleiben sie stehen – leer hieße „Alle“.
    final known = [
      for (final k in app.store.categories)
        if (_categories.contains(k.id)) k.id,
    ];
    app.store.saveBoardColumn(
      c,
      name: name,
      color: _color,
      categories: known.isEmpty ? _categories.toList() : known,
      periods: [
        for (final s in Section.values)
          if (_periods.contains(s.name)) s.name,
      ],
      status: _status,
      query: _query.text.trim(),
    );
    Navigator.pop(context);
    showSavedToast(context, isNew: c == null);
  }

  void _delete() {
    final app = context.app;
    final l = context.l;
    final c = app.store.boardColumnById(widget.column!.id);
    if (c == null) return closeSheetItemGone(context);
    Navigator.pop(context);
    final undo = app.store.deleteBoardColumn(c);
    app.snack.show(l.deletedItem(c.name), undo: undo);
  }

  /// „Alle“ und die einzelnen Möglichkeiten; mehrere lassen sich wählen.
  Widget _choice(String label, Set<String> chosen, List<({String id, String label, ItemColors? colors})> options) {
    // Nur so breit wie der Text – sonst füllte jeder Chip eine ganze Zeile.
    Widget chip(AppChip c) => IntrinsicWidth(child: c);
    return LabeledField(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(
            AppChip(label: context.l.all, selected: chosen.isEmpty, height: 34, onTap: () => setState(chosen.clear)),
          ),
          for (final o in options)
            chip(
              AppChip(
                label: o.label,
                selected: chosen.contains(o.id),
                colors: o.colors,
                height: 34,
                onTap: () => setState(() => chosen.contains(o.id) ? chosen.remove(o.id) : chosen.add(o.id)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final edit = widget.column != null;
    return SheetBody(
      footer: [
        if (_error != null) SheetError(_error!),
        SheetActions(onSave: _save, onDelete: edit ? _delete : null),
      ],
      children: [
        SheetTitle(edit ? l.editColumn : l.newColumn),
        AppField(
          label: l.name,
          controller: _name,
          hint: l.columnHint,
          maxLength: 30,
          autofocus: !edit,
          onSubmitted: (_) => _save(),
        ),
        LabeledField(
          label: l.color,
          child: ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        _choice(l.categories, _categories, [
          for (final k in context.app.store.categories) (id: k.id, label: k.name, colors: tok.item(k.color)),
        ]),
        _choice(l.columnsPeriods, _periods, [
          for (final s in Section.values)
            if (s != Section.done) (id: s.name, label: sectionLabel(l, s), colors: null),
        ]),
        SelectRow<ColumnStatus>(
          title: l.columnStatus,
          padding: const EdgeInsets.symmetric(vertical: 8),
          options: [
            (ColumnStatus.all, l.all),
            (ColumnStatus.open, l.columnOnlyOpen),
            (ColumnStatus.done, l.columnOnlyDone),
          ],
          value: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
        AppField(
          label: l.columnText,
          controller: _query,
          hint: l.columnTextHint,
          maxLength: 60,
          onSubmitted: (_) => _save(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l.columnFilterNote,
            style: TextStyle(fontSize: Fs.meta, color: tok.sub),
          ),
        ),
      ],
    );
  }
}
