import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/overlays.dart';
import '../widgets/pickers.dart';
import '../widgets/pressable.dart';
import '../widgets/ui.dart';
import 'ui_state.dart';

/// Öffnet die Sheets (Aufgabe, Block, Gewohnheit, Kategorie) wie im Prototyp.
class Sheets {
  Sheets(this.context, this.ui);
  final BuildContext context;
  final UiState ui;

  void task(Task? t, {DateTime? preset}) {
    final l = context.l;
    final app = context.app;
    if (app.store.categories.isEmpty) app.ensureCategoriesNow(l);
    showAppSheet<void>(
      context,
      label: t == null ? l.newTask : l.editTask,
      builder: (_) => _TaskSheet(task: t, preset: preset, ui: ui),
    );
  }

  void newBlock({int? day, int? start}) {
    final l = context.l;
    final s = context.app.settings;
    final d = day ?? (ui.weekDay ?? (sameDay(ui.weekStart, monday(clock())) ? wdIndex(clock()) : 0));
    // Spätestes „Bis“ ist der letzte Raster-Schritt vor Mitternacht; „Von“ muss mindestens
    // einen Schritt davor liegen, sonst wäre der Block leer.
    final last = 24 * 60 - s.raster;
    final from = math.min(start ?? 15 * 60, last - s.raster);
    final to = start == null ? 16 * 60 : (from + 60).clamp(from + s.raster, last);
    showAppSheet<void>(
      context,
      label: l.newBlock,
      builder: (_) => _BlockSheet(block: null, days: [d], start: from, end: to, ui: ui),
    );
  }

  void block(WeekBlock b) {
    showAppSheet<void>(
      context,
      label: context.l.editBlock,
      builder: (_) => _BlockSheet(block: b, days: [b.day], start: b.start, end: b.end, ui: ui),
    );
  }

  void habit(Habit? h) {
    final l = context.l;
    showAppSheet<void>(
      context,
      label: h == null ? l.newHabit : l.editHabit,
      builder: (_) => _HabitSheet(habit: h),
    );
  }

  void category(TaskCategory? c) {
    final l = context.l;
    showAppSheet<void>(
      context,
      label: c == null ? l.newCategory : l.editCategory,
      builder: (_) => _CategorySheet(cat: c, ui: ui),
    );
  }
}

/// Bestätigung nach dem Speichern: offline in der Cloud „Am Gerät gespeichert“.
void _savedToast(BuildContext context, {required bool isNew}) {
  final app = context.app;
  final l = context.l;
  final off = app.offlineCloud;
  if (off) {
    app.snack.show(isNew ? l.savedOnDeviceLater : l.savedOnDevice, icon: Ic.cloudoff);
  } else {
    app.snack.show(isNew ? l.added : l.saved);
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: context.tok.sub),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

class _ErrMsg extends StatelessWidget {
  const _ErrMsg(this.text, {this.margin = const EdgeInsets.fromLTRB(6, 8, 6, 0)});
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
class _Actions extends StatelessWidget {
  const _Actions({required this.onSave, this.onDelete});
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (onDelete != null) AppButton(label: l.delete, icon: Ic.trash, kind: BtnKind.danger, onTap: onDelete),
          const Spacer(),
          AppButton(label: l.cancel, kind: BtnKind.text, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          AppButton(label: l.save, onTap: onSave),
        ],
      ),
    );
  }
}

/// Knopf mit Symbol, Untertitel und Wert (.dt-btn) – öffnet Kalender bzw. Uhrzeit-Rad.
class _DtButton extends StatelessWidget {
  const _DtButton({
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
                      fontFeatures: const [FontFeature.tabularFigures()],
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
class _Pop extends StatelessWidget {
  const _Pop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final box = Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
      decoration: BoxDecoration(
        color: tok.card,
        borderRadius: BorderRadius.circular(Sizes.rPop),
        boxShadow: tok.cardShadow,
      ),
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

// ---------------------------------------------------------------------------
// Aufgabe
// ---------------------------------------------------------------------------

class _SubEdit {
  _SubEdit(String text, this.done) : ctrl = TextEditingController(text: text), focus = FocusNode();
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool done;
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.task, required this.preset, required this.ui});
  final Task? task;
  final DateTime? preset;
  final UiState ui;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final TextEditingController _title;
  late String _cat;
  late DateTime _date;
  int? _time;
  late bool _dateTouched;
  late List<_SubEdit> _subs;
  bool _catOpen = false;
  late bool _dateOpen;
  late bool _subsOpen;
  String? _dt; // 'cal' | 'time'
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = context.app.store;
    final t = widget.task;
    final cats = store.categories;
    _title = TextEditingController(text: t?.title ?? '');
    final f = widget.ui.filter;
    _cat =
        t?.categoryId ??
        (f != 'alle' && f != 'habits' && store.categories.any((c) => c.id == f)
            ? f
            // sonst die Kategorie, die man zuletzt am häufigsten benutzt hat
            : (suggestCategory(store.tasks, [for (final c in cats) c.id]) ?? ''));
    _date = t?.dueDate ?? widget.preset ?? addDays(today(), store.catOf(_cat).offset);
    _time = t?.dueTime;
    _dateTouched = t != null || widget.preset != null;
    _subs = [for (final s in t?.subs ?? const <Subtask>[]) _SubEdit(s.title, s.done)];
    _dateOpen = widget.preset != null;
    _subsOpen = _subs.isNotEmpty;
  }

  @override
  void dispose() {
    _title.dispose();
    for (final s in _subs) {
      s.ctrl.dispose();
      s.focus.dispose();
    }
    super.dispose();
  }

  void _addSub() {
    final s = _SubEdit('', false);
    setState(() => _subs.add(s));
    WidgetsBinding.instance.addPostFrameCallback((_) => s.focus.requestFocus());
  }

  void _save() {
    final app = context.app;
    final l = context.l;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l.errTaskTitle);
      return;
    }
    final subs = [
      for (final s in _subs)
        if (s.ctrl.text.trim().isNotEmpty) (title: s.ctrl.text.trim(), done: s.done),
    ];
    // Wurde die gewählte Kategorie inzwischen (z. B. auf einem anderen Gerät) gelöscht,
    // landet die Aufgabe in der ersten vorhandenen – nie mit leerer Kategorie.
    final cats = app.store.categories;
    if (cats.isEmpty) app.ensureCategoriesNow(l);
    final cat = cats.any((c) => c.id == _cat) ? _cat : app.store.categories.first.id;
    final t = widget.task;
    if (t == null) {
      app.store.addTask(title: title, categoryId: cat, dueDate: _date, dueTime: _time, subs: subs);
    } else {
      app.store.updateTask(t, title: title, categoryId: cat, dueDate: _date, dueTime: _time, subs: subs);
    }
    Navigator.pop(context);
    _savedToast(context, isNew: t == null);
  }

  void _delete() {
    final app = context.app;
    final l = context.l;
    final t = widget.task!;
    Navigator.pop(context);
    final undo = app.store.deleteTask(t);
    app.snack.show(l.deletedItem(t.title), undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final f = Fmt.of(context);
    final store = context.app.store;
    final cat = store.catOf(_cat);
    final cc = tok.item(cat.color);
    final due = f.dayTime(_date, _time);
    final infoText = cat.offset > 0
        ? l.infoListFrom(l.infoHandIn(due), f.day(addDays(_date, -cat.offset)))
        : l.infoDue(due);
    final isEdit = widget.task != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppInput(
          controller: _title,
          hint: l.newTask,
          semanticLabel: l.task,
          maxLength: 200,
          filled: true,
          height: 52,
          fontSize: Fs.slim,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) _ErrMsg(_error!),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(
            infoText,
            style: TextStyle(fontSize: 12.5, color: tok.sub, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        if (_catOpen)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in store.categories)
                  AppChip(
                    label: k.name,
                    selected: k.id == _cat,
                    colors: tok.item(k.color),
                    height: 34,
                    onTap: () => setState(() {
                      _cat = k.id;
                      _catOpen = false;
                      if (!_dateTouched) _date = addDays(today(), k.offset);
                    }),
                  ),
              ],
            ),
          ),
        if (_dateOpen)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DtButton(
                        icon: Ic.calendar,
                        label: l.dueOn,
                        value: f.dateLabel(_date),
                        open: _dt == 'cal',
                        onTap: () => setState(() => _dt = _dt == 'cal' ? null : 'cal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DtButton(
                        icon: Ic.clock,
                        label: l.time,
                        value: _time == null ? l.none : f.time(_time!),
                        open: _dt == 'time',
                        onTap: () => setState(() => _dt = _dt == 'time' ? null : 'time'),
                      ),
                    ),
                  ],
                ),
                if (_dt == 'cal')
                  _Pop(
                    child: MiniCalendar(
                      selected: _date,
                      onPick: (d) => setState(() {
                        _date = d;
                        _dateTouched = true;
                      }),
                    ),
                  ),
                if (_dt == 'time')
                  _Pop(
                    child: TimeWheel(
                      value: _time,
                      step: 5,
                      quick: [
                        (minutes: null, label: l.timeNone),
                        for (final h in const [8, 12, 16, 20]) (minutes: h * 60, label: f.time(h * 60)),
                      ],
                      onQuick: (q) => setState(() {
                        _time = q.minutes;
                        _dateTouched = true;
                      }),
                      onChanged: (v) => setState(() {
                        _time = v;
                        _dateTouched = true;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        if (_subsOpen)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in _subs)
                  Padding(
                    key: ObjectKey(s),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            controller: s.ctrl,
                            focusNode: s.focus,
                            hint: l.subtask,
                            semanticLabel: l.subtask,
                            maxLength: 120,
                            height: 40,
                            fontSize: 15,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _addSub(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconBtn(
                          Ic.x,
                          size: 18,
                          label: l.removeSubtask,
                          onTap: () => setState(() {
                            _subs.remove(s);
                            s.ctrl.dispose();
                            s.focus.dispose();
                          }),
                        ),
                      ],
                    ),
                  ),
                // Gehört zum Eingeben: Die Tastatur bleibt offen und springt ins neue Feld.
                TextFieldTapRegion(
                  child: AppButton(label: l.subtask, icon: Ic.plus, kind: BtnKind.text, padding: 8, onTap: _addSub),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              // Chip und Symbole in einer eigenen Reihe: So bekommt der Chip den ganzen freien
              // Platz (bis zur Maximalbreite) und muss ihn nicht mit einem Spacer teilen.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Pressable(
                        onTap: () => setState(() => _catOpen = !_catOpen),
                        semanticLabel: l.categoryLabel(cat.name),
                        excludeChildSemantics: true,
                        child: Container(
                          height: 36,
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width <= 360 ? 112 : 150),
                          padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(color: cc.ct, borderRadius: BorderRadius.circular(18)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Dot(cc.c),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cc.ci),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconBtn(
                      Ic.calendar,
                      size: 22,
                      label: l.dateAndTime,
                      pressed: _dateOpen,
                      onTap: () => setState(() => _dateOpen = !_dateOpen),
                    ),
                    IconBtn(
                      Ic.subtasks,
                      size: 22,
                      label: l.subtasks,
                      pressed: _subsOpen,
                      onTap: () {
                        setState(() => _subsOpen = !_subsOpen);
                        if (_subsOpen && _subs.isEmpty) _addSub();
                      },
                    ),
                    if (isEdit) IconBtn(Ic.trash, size: 22, label: l.deleteTask, onTap: _delete),
                  ],
                ),
              ),
              Pressable(
                onTap: _save,
                semanticLabel: isEdit ? l.save : l.add,
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tok.p, shape: BoxShape.circle),
                  child: AppIcon(isEdit ? Ic.check : Ic.send, size: 24, stroke: 2.2, color: tok.onP),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Block im Wochenplan
// ---------------------------------------------------------------------------

class _BlockSheet extends StatefulWidget {
  const _BlockSheet({
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
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
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

  void _setStart(int v) => setState(() {
    _start = v;
    // „Bis“ rutscht mit, wenn „Von“ darüber hinaus geschoben wird
    if (_end <= _start) _end = (_start + 60).clamp(0, 24 * 60 - _raster);
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
    final b = widget.block;
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
    Navigator.pop(context);
    final undo = app.store.deleteBlock(widget.block!);
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
        _SheetTitle(edit ? l.editBlock : l.newBlock),
        AppField(label: l.name, controller: _name, hint: l.blockHint, maxLength: 60, autofocus: true),
        _Field(
          label: l.color,
          child: ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        _Field(
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
        _Field(
          label: l.timeWithDuration(durText),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DtButton(
                      icon: Ic.clock,
                      label: l.from,
                      value: f.time(_start),
                      open: _open == 'von',
                      onTap: () => setState(() => _open = _open == 'von' ? null : 'von'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DtButton(
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
                _Pop(
                  child: TimeWheel(key: const ValueKey('von'), value: _start, step: _raster, onChanged: _setStart),
                ),
              if (_open == 'bis')
                _Pop(
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
                    onQuick: (q) => setState(() => _end = (_start + q.minutes!).clamp(0, 24 * 60 - _raster)),
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
        if (_error != null) _ErrMsg(_error!, margin: const EdgeInsets.only(bottom: 8)),
        _Actions(onSave: _save, onDelete: edit ? _delete : null),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gewohnheit
// ---------------------------------------------------------------------------

class _HabitSheet extends StatefulWidget {
  const _HabitSheet({required this.habit});
  final Habit? habit;

  @override
  State<_HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<_HabitSheet> {
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
    final h = widget.habit;
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
    final h = widget.habit!;
    Navigator.pop(context);
    final undo = app.store.deleteHabit(h);
    app.snack.show(l.deletedItem(h.name), undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final edit = widget.habit != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTitle(edit ? l.editHabit : l.newHabit),
        AppField(
          label: l.name,
          controller: _name,
          hint: l.habitHint,
          maxLength: 40,
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
        _Field(
          label: l.color,
          child: ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        if (_error != null) _ErrMsg(_error!, margin: const EdgeInsets.only(bottom: 8)),
        _Actions(onSave: _save, onDelete: edit ? _delete : null),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kategorie
// ---------------------------------------------------------------------------

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.cat, required this.ui});
  final TaskCategory? cat;
  final UiState ui;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
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
        _SheetTitle(edit ? l.editCategory : l.newCategory),
        AppField(
          label: l.name,
          controller: _name,
          hint: l.categoryHint,
          maxLength: 30,
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
        _Field(
          label: l.color,
          child: ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        _Field(
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
        if (_error != null) _ErrMsg(_error!, margin: const EdgeInsets.only(bottom: 8)),
        _Actions(onSave: _save, onDelete: canDelete ? _delete : null),
      ],
    );
  }
}
