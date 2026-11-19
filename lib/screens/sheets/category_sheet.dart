import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../util/fmt.dart';
import '../../util/task_logic.dart';
import '../../widgets/pickers.dart';
import '../../widgets/ui.dart';
import '../ui_state.dart';
import 'sheet_parts.dart';

/// Neue Kategorie oder Kategorie bearbeiten: Name, Farbe, Vorlauf („wann erledigen“) und
/// ab welchem Abschnitt ihre Aufgaben in der Liste stehen.
class CategorySheet extends StatefulWidget {
  const CategorySheet({super.key, required this.cat, required this.ui});
  final TaskCategory? cat;
  final UiState ui;

  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
  late final TextEditingController _name = TextEditingController(text: widget.cat?.name ?? '');
  late String _color = widget.cat?.color ?? ColorPreset.mintGreen.hex;
  late int _offset = widget.cat?.offset ?? 0;
  late ListFrom _listFrom = widget.cat?.listFrom ?? ListFrom.always;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final l = context.l;
    final app = context.app;
    final name = _name.text.trim();
    // Der Stand von jetzt, nicht der vom Öffnen (siehe TaskSheet).
    final opened = widget.cat;
    final c = opened == null ? null : app.store.categoryById(opened.id);
    if (opened != null && c == null) return closeSheetItemGone(context);
    String? err;
    if (name.isEmpty) {
      err = l.errName;
    } else if (app.store.categories.any((k) => k.name.toLowerCase() == name.toLowerCase() && k.id != c?.id)) {
      err = l.errCategoryExists;
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (c == null) {
      app.store.addCategory(name: name, color: _color, offset: _offset, listFrom: _listFrom);
    } else {
      app.store.updateCategory(c, name: name, color: _color, offset: _offset, listFrom: _listFrom);
    }
    Navigator.pop(context);
    app.snack.show(l.saved);
  }

  void _delete() {
    final app = context.app;
    final l = context.l;
    final c = app.store.categoryById(widget.cat!.id);
    if (c == null) return closeSheetItemGone(context);
    Navigator.pop(context);
    final r = app.store.deleteCategory(c);
    if (r == null) return;
    if (widget.ui.filter == c.id) widget.ui.set((s) => s.filter = filterAll);
    app.snack.show(r.moved > 0 ? l.deletedCatMoved(c.name, r.target.name) : l.deletedItem(c.name), undo: r.undo);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final f = Fmt.of(context);
    final edit = widget.cat != null;
    final canDelete = edit && context.app.store.categories.length > 1;
    return SheetBody(
      footer: [
        if (_error != null) SheetError(_error!),
        SheetActions(onSave: _save, onDelete: canDelete ? _delete : null),
      ],
      children: [
        SheetTitle(edit ? l.editCategory : l.newCategory),
        AppField(
          label: l.name,
          controller: _name,
          hint: l.categoryHint,
          maxLength: 30,
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
        LabeledField(
          label: l.color,
          child: ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        LabeledField(
          label: l.doWhen,
          child: Seg<int>(
            wrap: true,
            options: [
              for (final o in const [0, 1, 2, 7]) (o, f.offsetLabel(o)),
            ],
            value: _offset,
            onChanged: (v) => setState(() => _offset = v),
          ),
        ),
        LabeledField(
          label: l.showInTasks,
          child: Seg<ListFrom>(
            wrap: true,
            options: [for (final o in ListFrom.values) (o, f.listFromLabel(o))],
            value: _listFrom,
            onChanged: (v) => setState(() => _listFrom = v),
          ),
        ),
      ],
    );
  }
}
