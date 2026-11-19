import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/pickers.dart';
import '../../widgets/ui.dart';
import 'sheet_parts.dart';

/// Neue Gewohnheit oder Gewohnheit bearbeiten: Name und Farbe.
class HabitSheet extends StatefulWidget {
  const HabitSheet({super.key, required this.habit});
  final Habit? habit;

  @override
  State<HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<HabitSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.habit?.name ?? '');
  late String _color = widget.habit?.color ?? ColorPreset.sunYellow.hex;
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
    if (name.isEmpty) {
      setState(() => _error = l.errName);
      return;
    }
    // Der Stand von jetzt, nicht der vom Öffnen (siehe TaskSheet).
    final opened = widget.habit;
    final h = opened == null ? null : app.store.habitById(opened.id);
    if (opened != null && h == null) return closeSheetItemGone(context);
    if (h == null) {
      app.store.addHabit(name: name, color: _color);
    } else {
      app.store.updateHabit(h, name: name, color: _color);
    }
    Navigator.pop(context);
    app.snack.show(l.saved);
  }

  void _delete() {
    final app = context.app;
    final l = context.l;
    final h = app.store.habitById(widget.habit!.id);
    if (h == null) return closeSheetItemGone(context);
    Navigator.pop(context);
    final undo = app.store.deleteHabit(h);
    app.snack.show(l.deletedItem(h.name), undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final edit = widget.habit != null;
    return SheetBody(
      footer: [
        if (_error != null) SheetError(_error!),
        SheetActions(onSave: _save, onDelete: edit ? _delete : null),
      ],
      children: [
        SheetTitle(edit ? l.editHabit : l.newHabit),
        AppField(
          label: l.name,
          controller: _name,
          hint: l.habitHint,
          maxLength: 40,
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
        LabeledField(
          label: l.color,
          child: ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
        ),
      ],
    );
  }
}
