import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../util/fmt.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pickers.dart';
import '../../widgets/pressable.dart';
import '../../widgets/ui.dart';
import '../ui_state.dart';
import 'sheet_parts.dart';

/// Neuer Block im Wochenplan oder Block bearbeiten: Name, Farbe, Tage, Von/Bis, jede Woche.
class BlockSheet extends StatefulWidget {
  const BlockSheet({
    super.key,
    required this.block,
    required this.days,
    required this.start,
    required this.end,
    required this.ui,
  });
  final WeekBlock? block;
  final List<int> days;
  final int start;
  final int end;
  final UiState ui;

  @override
  State<BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<BlockSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.block?.name ?? '');
  late String _color = widget.block?.color ?? ColorPreset.skyBlue.hex;
  late final Set<int> _days = {...widget.days};
  late int _start = widget.start;
  late int _end = widget.end;
  late bool _repeat = widget.block?.repeat ?? true;
  String? _open; // 'von' | 'bis'
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  int get _raster => context.app.settings.raster;

  /// Spätestes „Bis“: der letzte Raster-Schritt vor Mitternacht (24:00 kann das Rad nicht zeigen).
  int get _lastEnd => 24 * 60 - _raster;

  void _setStart(int v) => setState(() {
    // „Von“ lässt immer mindestens einen Raster-Schritt Platz bis zum spätesten „Bis“ …
    _start = math.min(v, _lastEnd - _raster);
    // … und „Bis“ rutscht mit, wenn „Von“ darüber hinaus geschoben wird.
    if (_end <= _start) _end = math.min(_start + 60, _lastEnd);
  });

  void _save() {
    final l = context.l;
    final app = context.app;
    final name = _name.text.trim();
    final r = _raster;
    // Nur gerundet wird, was der User geändert hat – wer einen alten 10:15-Block nach dem
    // Wechsel auf ein 30-Minuten-Raster nur umbenennt, behält 10:15.
    int snap(int v, int orig) => v == orig ? v : (v / r).round() * r;
    final start = snap(_start, widget.start), end = snap(_end, widget.end);
    String? err;
    if (name.isEmpty) {
      err = l.errName;
    } else if (_days.isEmpty) {
      err = l.errPickDay;
    } else if (end <= start) {
      err = l.errToAfterFrom;
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // Der Stand von jetzt, nicht der vom Öffnen (siehe TaskSheet).
    final opened = widget.block;
    final b = opened == null ? null : app.store.blockById(opened.id);
    if (opened != null && b == null) return closeSheetItemGone(context);
    final days = _days.toList()..sort();
    if (b != null) {
      app.store.updateBlock(
        b,
        name: name,
        color: _color,
        day: days.first,
        start: start,
        end: end,
        repeat: _repeat,
        weekStart: widget.ui.weekStart,
      );
      Navigator.pop(context);
      app.snack.show(l.saved);
    } else {
      final n = app.store.addBlocks(
        name: name,
        color: _color,
        days: days,
        start: start,
        end: end,
        repeat: _repeat,
        weekStart: widget.ui.weekStart,
      );
      Navigator.pop(context);
      app.snack.show(n > 1 ? l.blocksAdded(n) : l.blockAdded);
    }
  }

  void _delete() {
    final app = context.app;
    final l = context.l;
    final b = app.store.blockById(widget.block!.id);
    if (b == null) return closeSheetItemGone(context);
    Navigator.pop(context);
    final undo = app.store.deleteBlock(b);
    app.snack.show(l.blockDeleted, undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final f = Fmt.of(context);
    final edit = widget.block != null;
    final dur = _end - _start;
    final durText = dur > 0 ? f.duration(dur) : l.durInvalid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(edit ? l.editBlock : l.newBlock),
        AppField(label: l.name, controller: _name, hint: l.blockHint, maxLength: 60, autofocus: true),
        LabeledField(
          label: l.color,
          child: ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        LabeledField(
          label: edit ? l.day : l.days,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Pressable(
                    onTap: () => setState(() {
                      if (edit) {
                        _days
                          ..clear()
                          ..add(i);
                      } else if (!_days.remove(i)) {
                        _days.add(i);
                      }
                    }),
                    semanticLabel: f.wdLong(i),
                    selected: _days.contains(i),
                    excludeChildSemantics: true,
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _days.contains(i) ? tok.p : Colors.transparent,
                        border: Border.all(color: _days.contains(i) ? tok.p : tok.line),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Text(
                        f.wd(i),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _days.contains(i) ? tok.onP : tok.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        LabeledField(
          label: l.timeWithDuration(durText),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DateTimeButton(
                      icon: Ic.clock,
                      label: l.from,
                      value: f.time(_start),
                      open: _open == 'von',
                      onTap: () => setState(() => _open = _open == 'von' ? null : 'von'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DateTimeButton(
                      icon: Ic.clock,
                      label: l.to,
                      value: f.time(_end),
                      open: _open == 'bis',
                      onTap: () => setState(() => _open = _open == 'bis' ? null : 'bis'),
                    ),
                  ),
                ],
              ),
              if (_open == 'von')
                PopCard(
                  child: TimeWheel(key: const ValueKey('von'), value: _start, step: _raster, onChanged: _setStart),
                ),
              if (_open == 'bis')
                PopCard(
                  child: TimeWheel(
                    key: const ValueKey('bis'),
                    value: _end,
                    step: _raster,
                    quick: [
                      (minutes: 30, label: l.quickPlus30),
                      (minutes: 60, label: l.quickPlus60),
                      (minutes: 90, label: l.quickPlus90),
                      (minutes: 120, label: l.quickPlus120),
                    ],
                    // Die Chips sind Dauern ab „Von“, keine Uhrzeiten.
                    isSelected: (q) => _end - _start == q.minutes,
                    onQuick: (q) => setState(() => _end = math.min(_start + q.minutes!, _lastEnd)),
                    onChanged: (v) => setState(() => _end = v),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(l.everyWeek, style: TextStyle(fontSize: 16, color: tok.text)),
              ),
              AppSwitch(value: _repeat, label: l.repeatEveryWeek, onChanged: (v) => setState(() => _repeat = v)),
            ],
          ),
        ),
        if (_error != null) SheetError(_error!),
        SheetActions(onSave: _save, onDelete: edit ? _delete : null),
      ],
    );
  }
}
