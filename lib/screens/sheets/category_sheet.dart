import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../util/fmt.dart';
import '../../widgets/pickers.dart';
import '../../widgets/ui.dart';
import '../ui_state.dart';
import 'sheet_parts.dart';

/// Neue Kategorie oder Kategorie bearbeiten: Name, Farbe, Vorlauf („wann erledigen“).
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
    final c = widget.cat;
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
      app.store.addCategory(name: name, color: _color, offset: _offset);
    } else {
      app.store.updateCategory(c, name: name, color: _color, offset: _offset);
    }
    Navigator.pop(context);
    app.snack.show(l.saved);
  }

  void _delete() {
    final app = context.app;
    final l = context.l;
    final c = widget.cat!;
    Navigator.pop(context);
    final r = app.store.deleteCategory(c);
    if (r == null) return;
    if (widget.ui.filter == c.id) widget.ui.set((s) => s.filter = 'alle');
    app.snack.show(r.moved > 0 ? l.deletedCatMoved(c.name, r.target.name) : l.deletedItem(c.name), undo: r.undo);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final f = Fmt.of(context);
    final edit = widget.cat != null;
    final canDelete = edit && context.app.store.categories.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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
        if (_error != null) SheetError(_error!),
        SheetActions(onSave: _save, onDelete: canDelete ? _delete : null),
      ],
    );
  }
}
