import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/flip.dart';
import '../widgets/pressable.dart';
import '../widgets/ui.dart';
import 'sheets.dart';
import 'ui_state.dart';

/// Abhaken einer Aufgabe mit Haptik und kurzer Meldung (wie `toggle` im Prototyp).
void toggleTaskWithToast(BuildContext context, Task t) {
  final app = context.app;
  final l = context.l;
  app.store.toggleTask(t);
  if (t.done) buzz();
  final done = isYearly(t.title) ? l.doneYearly : l.done;
  app.snack.show(t.done ? done : l.reopened, icon: t.done ? Ic.check : null);
}

void deleteTaskWithUndo(BuildContext context, Task t) {
  final app = context.app;
  final undo = app.store.deleteTask(t);
  app.snack.show(context.l.deletedItem(t.title), undo: undo);
}

/// Abschnitts-Überschrift zum Ein-/Ausklappen (.section-h).
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.label,
    required this.count,
    required this.open,
    required this.onTap,
    this.color,
    this.overdue = false,
  });
  final String label;
  final int count;
  final bool open;
  final VoidCallback onTap;
  final Color? color;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final fg = overdue ? tok.err : tok.sub;
    final text = context.l.sectionCount(label, count);
    return Semantics(
      expanded: open,
      child: Pressable(
        onTap: onTap,
        pressScale: 0.98,
        glow: false,
        radius: BorderRadius.zero,
        semanticLabel: text,
        excludeChildSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              if (color != null) ...[Dot(color!), const SizedBox(width: 6)],
              Expanded(
                child: Text(
                  text.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: Fs.section, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: fg),
                ),
              ),
              AnimatedRotation(
                turns: open ? 0 : -0.25,
                duration: Motion.of(context, Motion.fast),
                child: AppIcon(Ic.down, size: 20, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karte einer Aufgabe (.task-wrap/.task) – nach links wischen löscht sie.
class TaskCard extends StatefulWidget {
  const TaskCard({super.key, required this.task, required this.ui});
  final Task task;
  final UiState ui;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  double _dx = 0;
  bool _drag = false;
  bool _gone = false;

  void _end(double width) {
    if (_dx < -96) {
      setState(() {
        _gone = true;
        _drag = false;
        _dx = -width * 1.1;
      });
      Future.delayed(Motion.of(context, const Duration(milliseconds: 160)), () {
        if (mounted) deleteTaskWithUndo(context, widget.task);
      });
    } else {
      setState(() {
        _drag = false;
        _dx = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final app = AppScope.of(context);
    final store = app.store;
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final c = store.catOf(t.categoryId);
    final cc = tok.item(c.color);
    final late = isLate(t);
    final when = c.offset > 0 ? l.infoHandIn(f.day(t.dueDate)) : f.dayTime(t.dueDate, t.dueTime);
    final subDone = t.subs.where((s) => s.done).length;
    final pending = app.offlineCloud && store.pendingTaskIds.contains(t.id);
    final metaStyle = TextStyle(fontSize: Fs.meta, color: tok.sub, fontFeatures: Fs.tabular);

    final card = Container(
      decoration: BoxDecoration(
        color: tok.card,
        borderRadius: BorderRadius.circular(Sizes.rCard),
        border: Border(left: BorderSide(color: cc.c, width: 5)),
        boxShadow: tok.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CheckMark(
                on: t.done,
                colors: cc,
                label: t.done ? l.a11yReopen(t.title) : l.a11yDone(t.title),
                onTap: () => toggleTaskWithToast(context, t),
              ),
              Expanded(
                child: Pressable(
                  onTap: () => Sheets(context, widget.ui).task(t),
                  pressScale: 0.985,
                  radius: BorderRadius.circular(Sizes.rCard),
                  // Die Kinder sind ausgeschlossen – deshalb steht auch die ganze Notiz im Label.
                  semanticLabel: [
                    t.title,
                    c.name,
                    when,
                    if (isYearly(t.title)) l.yearly,
                    if (t.notes.isNotEmpty) '${l.notes}: ${t.notes}',
                  ].join(', '),
                  excludeChildSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontSize: Fs.task,
                            height: 21 / 15.5,
                            color: t.done ? tok.sub : tok.text,
                            decoration: t.done ? TextDecoration.lineThrough : null,
                            decorationColor: tok.sub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              when,
                              style: late ? metaStyle.copyWith(color: tok.err, fontWeight: FontWeight.w500) : metaStyle,
                            ),
                            if (t.subs.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(Ic.subtasks, size: 14, color: tok.sub),
                                  const SizedBox(width: 4),
                                  Text(l.progress(subDone, t.subs.length), style: metaStyle),
                                ],
                              ),
                            if (t.notes.isNotEmpty) AppIcon(Ic.notes, size: 14, color: tok.sub),
                            if (isYearly(t.title))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(Ic.sync, size: 14, color: tok.sub),
                                  const SizedBox(width: 4),
                                  Text(l.yearly, style: metaStyle),
                                ],
                              ),
                            if (pending)
                              Tooltip(
                                message: l.pendingSyncHint,
                                child: AppIcon(Ic.cloudoff, size: 14, color: tok.sub),
                              ),
                          ],
                        ),
                        if (t.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          // Nur ein Vorgeschmack: die ersten zwei Zeilen; ganz zu lesen im Formular.
                          Text(t.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: metaStyle),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (t.subs.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 12, 2),
                child: Column(
                  children: [
                    for (final s in t.subs)
                      Row(
                        children: [
                          CheckMark(
                            small: true,
                            on: s.done,
                            colors: cc,
                            label: s.done ? l.a11yReopenSub(s.title) : l.a11yCheckSub(s.title),
                            onTap: () => store.toggleSub(s),
                          ),
                          Expanded(
                            child: Text(
                              s.title,
                              style: TextStyle(
                                fontSize: 14,
                                color: s.done ? tok.sub : tok.text,
                                decoration: s.done ? TextDecoration.lineThrough : null,
                                decorationColor: tok.sub,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Sizes.rCard),
        child: LayoutBuilder(
          builder: (context, box) {
            return Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Container(
                      color: _dx < 0 ? tok.errC : Colors.transparent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: _dx < 0 ? AppIcon(Ic.trash, size: 22, color: tok.onErrC) : null,
                    ),
                  ),
                ),
                Semantics(
                  customSemanticsActions: {
                    CustomSemanticsAction(label: l.deleteTask): () => deleteTaskWithUndo(context, t),
                  },
                  child: GestureDetector(
                    onHorizontalDragStart: _gone ? null : (_) => setState(() => _drag = true),
                    onHorizontalDragUpdate: _gone
                        ? null
                        : (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(-box.maxWidth, 0)),
                    onHorizontalDragEnd: _gone ? null : (_) => _end(box.maxWidth),
                    onHorizontalDragCancel: _gone ? null : () => _end(box.maxWidth),
                    child: AnimatedContainer(
                      duration: _drag ? Duration.zero : Motion.of(context, Motion.springBack),
                      curve: Motion.springSoft,
                      transform: Matrix4.translationValues(_dx, 0, 0),
                      child: card,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Feste Aufgabe „Gewohnheiten“ ganz oben: jede Gewohnheit ist eine Unteraufgabe für heute.
class HabitsTaskCard extends StatelessWidget {
  const HabitsTaskCard({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final store = app.store;
    final tok = context.tok;
    final l = context.l;
    final k = isoDate(today());
    final hs = store.habits;
    final done = hs.where((h) => store.habitDone(h.id, k)).length;
    final all = hs.isNotEmpty && done == hs.length;
    final open = !ui.collapsed.contains(UiState.habitsCard);
    final cc = tok.item(habitColorHex);
    final metaStyle = TextStyle(fontSize: Fs.meta, color: tok.sub, fontFeatures: Fs.tabular);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: tok.card,
          borderRadius: BorderRadius.circular(Sizes.rCard),
          border: Border(left: BorderSide(color: cc.c, width: 5)),
          boxShadow: tok.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CheckMark(
                  on: all,
                  colors: cc,
                  label: all ? l.habitsReopenAll : l.habitsCheckAll,
                  onTap: () {
                    if (store.toggleAllHabitsToday()) buzz();
                  },
                ),
                Expanded(
                  child: Semantics(
                    expanded: open,
                    child: Pressable(
                      onTap: () => ui.toggleCollapsed(UiState.habitsCard),
                      pressScale: 0.985,
                      radius: BorderRadius.circular(Sizes.rCard),
                      semanticLabel: '${l.habits}, ${l.daily}, ${l.progress(done, hs.length)}',
                      excludeChildSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.habits,
                                    style: TextStyle(fontSize: Fs.task, height: 21 / 15.5, color: tok.text),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      Text(l.daily, style: metaStyle),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AppIcon(Ic.subtasks, size: 14, color: tok.sub),
                                          const SizedBox(width: 4),
                                          _Rolling(text: l.progress(done, hs.length), style: metaStyle),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: AnimatedRotation(
                                turns: open ? 0.5 : 0,
                                duration: Motion.of(context, const Duration(milliseconds: 400)),
                                curve: Motion.springSoft,
                                child: AppIcon(Ic.down, size: 20, color: tok.sub),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Auf- und Zuklappen wächst weich, statt zu springen.
            Transform.translate(
              offset: const Offset(0, -4),
              child: AnimatedSize(
                // Nie ganz 0: Damit käme AnimatedSize beim Umklappen nicht zurecht.
                duration: Motion.reduced(context) ? const Duration(milliseconds: 1) : Motion.pop,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 12, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Abgehakte rutschen nach unten; innerhalb bleibt die eigene Reihenfolge.
                            FlipColumn(
                              children: [
                                for (final h in [
                                  ...hs.where((h) => !store.habitDone(h.id, k)),
                                  ...hs.where((h) => store.habitDone(h.id, k)),
                                ])
                                  _HabitSub(key: ValueKey(h.id), habit: h, day: k, ui: ui),
                              ],
                            ),
                            AppButton(
                              label: l.habit,
                              icon: Ic.plus,
                              kind: BtnKind.text,
                              height: 34,
                              padding: 8,
                              fontSize: 13,
                              onTap: () => Sheets(context, ui).habit(null),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitSub extends StatelessWidget {
  const _HabitSub({super.key, required this.habit, required this.day, required this.ui});
  final Habit habit;
  final String day;
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    final tok = context.tok;
    final l = context.l;
    final h = habit;
    final on = store.habitDone(h.id, day);
    final st = store.habitStreak(h.id);
    final hc = tok.item(h.color);
    return _CheckFlash(
      on: on,
      color: hc.c,
      child: Row(
        children: [
          CheckMark(
            small: true,
            on: on,
            colors: hc,
            label: on ? l.a11yHabitReopen(h.name) : l.a11yHabitDoneToday(h.name),
            onTap: () {
              if (store.toggleHabitDay(h.id, day)) buzz();
            },
          ),
          Expanded(
            child: Pressable(
              onTap: () => Sheets(context, ui).habit(h),
              pressScale: 0.97,
              glow: false,
              semanticLabel: l.editHabit,
              excludeChildSemantics: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                // Abgehakt wird nur blasser – durchgestrichen sähe nach „gestrichen“ aus, nicht nach „geschafft“.
                child: AnimatedDefaultTextStyle(
                  duration: Motion.of(context, Motion.pop),
                  style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14, color: on ? tok.sub : tok.text),
                  child: Text(h.name),
                ),
              ),
            ),
          ),
          if (st > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                label: l.streakDays(st),
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(Ic.flame, size: 13, stroke: 2, color: hc.c),
                    const SizedBox(width: 3),
                    _Rolling(
                      text: '$st',
                      style: TextStyle(fontSize: 12, color: tok.sub, fontFeatures: Fs.tabular),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kurzes Aufleuchten in der Farbe der Gewohnheit und ein kleiner Hüpfer, sobald abgehakt wird.
class _CheckFlash extends StatefulWidget {
  const _CheckFlash({required this.on, required this.color, required this.child});
  final bool on;
  final Color color;
  final Widget child;

  @override
  State<_CheckFlash> createState() => _CheckFlashState();
}

class _CheckFlashState extends State<_CheckFlash> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.springBack, value: 1);

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.035).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.035, end: 1).chain(CurveTween(curve: Motion.springSoft)),
      weight: 70,
    ),
  ]);

  @override
  void didUpdateWidget(_CheckFlash old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) {
      _c.duration = Motion.of(context, Motion.springBack);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.22 * (1 - Curves.easeOut.transform(_c.value))),
        borderRadius: BorderRadius.circular(Sizes.rInput),
      ),
      child: Transform.scale(scale: _scale.evaluate(_c), alignment: Alignment.centerLeft, child: child),
    ),
    child: widget.child,
  );
}

/// Zahl oder kurzer Text, der beim Ändern weich nach oben wegrollt (Serie, „2/3“).
class _Rolling extends StatelessWidget {
  const _Rolling({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, Motion.pop),
    switchInCurve: Motion.springSoft,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: Offset(0, child.key == ValueKey(text) ? 0.7 : -0.7), end: Offset.zero).animate(a),
        child: child,
      ),
    ),
    child: Text(text, key: ValueKey(text), style: style),
  );
}
