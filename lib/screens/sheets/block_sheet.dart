import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../util/dates.dart';
import '../../util/fmt.dart';
import '../../util/task_logic.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pickers.dart';
import '../../widgets/pressable.dart';
import '../../widgets/ui.dart';
import '../ui_state.dart';
import 'pick_tasks_page.dart';
import 'sheet_parts.dart';

/// Welches Zeit-Rad aufgeklappt ist.
enum _Edge { from, to }

/// Neuer Block im Wochenplan oder Block bearbeiten: Name, Farbe, Tage, Von/Bis, jede Woche.
class BlockSheet extends StatefulWidget {
  const BlockSheet({
    super.key,
    required this.block,
    required this.day,
    required this.start,
    required this.end,
    required this.ui,
  });
  final WeekBlock? block;

  /// Vorgewählter Wochentag (0 = Montag); beim Anlegen lassen sich weitere dazunehmen.
  final int day;
  final int start;
  final int end;
  final UiState ui;

  @override
  State<BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<BlockSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.block?.name ?? '');
  late String _color = widget.block?.color ?? ColorPreset.skyBlue.hex;
  late final Set<int> _days = {widget.day};
  late int _start = widget.start;
  late int _end = widget.end;
  late bool _repeat = widget.block?.repeat ?? true;
  _Edge? _open;
  String? _error;

  /// Die Aufgabe, aus der dieser Block wird (nur beim Anlegen): Sie gibt den Namen vor und
  /// bekommt beim Speichern die „Von“-Zeit als Uhrzeit.
  String? _taskId;

  /// „Von“, wie es die gewählte Aufgabe mit ihrer eigenen Uhrzeit vorgegeben hat. Bleibt es
  /// dabei, wird weder gerundet noch die Uhrzeit der Aufgabe angefasst.
  int? _taskStart;

  /// Der gewählte Tag der gezeigten Woche – nur bei einem neuen Block mit genau einem Tag.
  DateTime? get _date =>
      widget.block != null || _days.length != 1 ? null : sod(Store.dayInWeek(widget.ui.weekStart, _days.single));

  /// Offene Aufgaben, an denen man am gewählten Tag arbeitet: vom Tag, an dem sie laut
  /// Vorlauf ihrer Kategorie dran sind, bis zur Abgabe. Ein Test mit zwei Tagen Vorlauf steht
  /// also an allen drei Tagen. Der Vorlauf wird jedes Mal neu gelesen – stellt man ihn um,
  /// gilt sofort der neue.
  List<Task> get _dayTasks {
    final date = _date;
    if (date == null) return const [];
    final store = context.app.store;
    return store.tasks.where((t) {
      if (t.done) return false;
      final from = doDate(t, store.catOf(t.categoryId).offset);
      return !date.isBefore(from) && !date.isAfter(sod(t.dueDate));
    }).toList()..sort((a, b) {
      final c = sod(a.dueDate).compareTo(sod(b.dueDate));
      return c != 0 ? c : (a.dueTime ?? 24 * 60).compareTo(b.dueTime ?? 24 * 60);
    });
  }

  /// Über „+“ dazu gewählte Aufgaben (IDs): Sie stehen nur in diesem Blatt als weitere Chips,
  /// an der Aufgabe selbst ändert sich nichts.
  final List<String> _extra = [];

  /// Die Chips: die Aufgaben des Tages, dann die dazu gewählten (offen und noch nicht dabei).
  List<Task> get _rowTasks {
    final day = _dayTasks;
    final store = context.app.store;
    return [
      ...day,
      for (final id in _extra)
        if (store.taskById(id) case final t? when !t.done && !day.any((d) => d.id == id)) t,
    ];
  }

  /// „+“: Seite mit allen Aufgaben ab diesem Tag; die gewählten kommen als Chips dazu, die
  /// erste ist gleich ausgewählt.
  Future<void> _addTasks() async {
    final date = _date;
    if (date == null) return;
    final from = date.isBefore(today()) ? today() : date;
    final ids = await pickTasks(
      context,
      from: from,
      exclude: {for (final t in _dayTasks) t.id},
      initial: List.of(_extra),
    );
    if (ids == null || !mounted) return;
    setState(() {
      _extra
        ..clear()
        ..addAll(ids);
    });
    final first = ids.isEmpty ? null : context.app.store.taskById(ids.first);
    if (first != null && _taskId != first.id) _pickTask(first);
  }

  /// Ist [t] am gewählten Tag abzugeben? Nur dann gehören ihre Uhrzeit und der Block zusammen.
  bool _dueThatDay(Task t) {
    final date = _date;
    return date != null && sameDay(t.dueDate, date);
  }

  void _pickTask(Task t) => setState(() {
    _taskStart = null;
    if (_taskId == t.id) {
      _taskId = null;
      return;
    }
    _taskId = t.id;
    _name.text = t.title.length > 60 ? t.title.substring(0, 60) : t.title;
    _color = context.app.store.catOf(t.categoryId).color;
    // Eine Aufgabe ist an einem bestimmten Tag dran – der Block gilt nur für diese Woche.
    _repeat = false;
    // Die Uhrzeit der Abgabe nur am Abgabetag übernehmen – an den Tagen davor wird geübt.
    final time = _dueThatDay(t) ? t.dueTime : null;
    if (time != null) {
      _start = math.min(time, _lastEnd - _raster);
      _end = math.min(_start + 60, _lastEnd);
      _taskStart = _start;
    }
  });

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

  void _toggleWheel(_Edge e) => setState(() => _open = _open == e ? null : e);

  void _save() {
    final l = context.l;
    final app = context.app;
    final name = _name.text.trim();
    final r = _raster;
    // Nur gerundet wird, was der User geändert hat – wer einen alten 10:15-Block nach dem
    // Wechsel auf ein 30-Minuten-Raster nur umbenennt, behält 10:15.
    int snap(int v, int orig) => v == orig ? v : (v / r).round() * r;
    final fromTask = _start == _taskStart;
    final start = fromTask ? _start : snap(_start, widget.start), end = snap(_end, widget.end);
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
      // Die gewählte Aufgabe bekommt die Zeit des Blocks – wenn es sie noch gibt.
      final task = _taskId == null ? null : app.store.taskById(_taskId!);
      // Kam „Von“ unverändert von ihrer eigenen Uhrzeit, bleibt die Aufgabe, wie sie ist.
      // Nur am Abgabetag: Ein Block zum Lernen davor verschiebt nicht die Uhrzeit der Abgabe.
      if (task != null && !task.done && !fromTask && _dueThatDay(task) && _rowTasks.any((t) => t.id == task.id)) {
        app.store.setTaskTime(task, start);
      }
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
    final dayTasks = _rowTasks;
    final store = context.app.store;
    return SheetBody(
      footer: [
        if (_error != null) SheetError(_error!),
        SheetActions(onSave: _save, onDelete: edit ? _delete : null),
      ],
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
              // In der Reihenfolge der Woche (Wochenbeginn aus den Optionen).
              for (final i in [for (var p = 0; p < 7; p++) wdAt(p)]) ...[
                if (i != wdAt(0)) const SizedBox(width: 6),
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
        // Auch ohne Aufgaben an dem Tag: Über „+“ lassen sich spätere dazunehmen.
        if (_date != null)
          LabeledField(
            label: l.tasksThatDay,
            child: QuickRow(
              label: l.tasksThatDay,
              children: [
                for (final t in dayTasks)
                  AppChip(
                    // An den Tagen davor steht dabei, wann sie fällig ist.
                    label: _dueThatDay(t) ? t.title : '${t.title} · ${l.infoHandIn(f.wd(wdIndex(t.dueDate)))}',
                    selected: _taskId == t.id,
                    colors: tok.item(store.catOf(t.categoryId).color),
                    height: 32,
                    padding: 12,
                    fontSize: 13,
                    onTap: () => _pickTask(t),
                  ),
                _PlusChip(label: l.addTasksToDay, onTap: _addTasks),
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
                      open: _open == _Edge.from,
                      onTap: () => _toggleWheel(_Edge.from),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DateTimeButton(
                      icon: Ic.clock,
                      label: l.to,
                      value: f.time(_end),
                      open: _open == _Edge.to,
                      onTap: () => _toggleWheel(_Edge.to),
                    ),
                  ),
                ],
              ),
              if (_open == _Edge.from)
                PopCard(
                  child: TimeWheel(key: const ValueKey('von'), value: _start, step: _raster, onChanged: _setStart),
                ),
              if (_open == _Edge.to)
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
      ],
    );
  }
}

/// Der „+“-Chip am Ende der Aufgaben an diesem Tag.
class _PlusChip extends StatelessWidget {
  const _PlusChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      excludeChildSemantics: true,
      radius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tok.surf2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tok.line),
        ),
        child: AppIcon(Ic.plus, size: 18, color: tok.sub),
      ),
    );
  }
}
