import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../util/dates.dart';
import '../../util/fmt.dart';
import '../../util/task_logic.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pickers.dart';
import '../../widgets/pressable.dart';
import '../../widgets/ui.dart';
import '../ui_state.dart';
import 'sheet_parts.dart';

class _SubEdit {
  _SubEdit(String text, this.done) : ctrl = TextEditingController(text: text), focus = FocusNode();
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool done;
}

/// Eingabefeld für den Titel: Das Wort, das die Aufgabe jährlich macht („Geburtstag“),
/// wird farbig hinterlegt – so sieht man sofort, dass die Wiederholung aktiv ist.
class _TitleController extends TextEditingController {
  _TitleController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final m = yearlyMatch(text);
    if (m == null) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final tok = context.tok;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, m.start)),
        TextSpan(
          text: text.substring(m.start, m.end),
          style: TextStyle(color: tok.p, fontWeight: FontWeight.w600, backgroundColor: tok.p.withValues(alpha: 0.16)),
        ),
        TextSpan(text: text.substring(m.end)),
      ],
    );
  }
}

/// Neue Aufgabe oder Aufgabe bearbeiten: Titel, Kategorie, Abgabe, Uhrzeit, Unteraufgaben.
class TaskSheet extends StatefulWidget {
  const TaskSheet({super.key, required this.task, required this.preset, required this.ui});
  final Task? task;
  final DateTime? preset;
  final UiState ui;

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
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
  bool _yearly = false;

  // Hinweis „Wiederholt sich jedes Jahr“ ein-/ausblenden, sobald das Wort getippt ist.
  void _titleChanged() {
    final y = isYearly(_title.text);
    if (y != _yearly) setState(() => _yearly = y);
  }

  @override
  void initState() {
    super.initState();
    final store = context.app.store;
    final t = widget.task;
    final cats = store.categories;
    _title = _TitleController(text: t?.title ?? '')..addListener(_titleChanged);
    _yearly = isYearly(_title.text);
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
    showSavedToast(context, isNew: t == null);
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
        if (_error != null) SheetError(_error!, margin: const EdgeInsets.fromLTRB(6, 8, 6, 0)),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(
            infoText,
            style: TextStyle(fontSize: 12.5, color: tok.sub, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        if (_yearly)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  AppIcon(Ic.sync, size: 15, color: tok.p),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l.yearlyHint,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: tok.p),
                    ),
                  ),
                ],
              ),
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
                      child: DateTimeButton(
                        icon: Ic.calendar,
                        label: l.dueOn,
                        value: f.dateLabel(_date),
                        open: _dt == 'cal',
                        onTap: () => setState(() => _dt = _dt == 'cal' ? null : 'cal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DateTimeButton(
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
                  PopCard(
                    child: MiniCalendar(
                      selected: _date,
                      onPick: (d) => setState(() {
                        _date = d;
                        _dateTouched = true;
                      }),
                    ),
                  ),
                if (_dt == 'time')
                  PopCard(
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
