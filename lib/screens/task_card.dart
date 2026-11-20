import 'dart:math' as math;

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
import '../widgets/splash.dart';
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
  const TaskCard({super.key, required this.task, required this.ui, this.highlightable = true});
  final Task task;
  final UiState ui;

  /// Reagiert auf [UiState.focusTask] (nur in der Aufgabenliste, nicht im Kalender).
  final bool highlightable;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final app = AppScope.of(context);
    final store = app.store;
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final yearly = isYearly(t.title);
    final c = store.catOf(t.categoryId);
    final cc = tok.item(c.color);
    final late = isLate(t);
    final when = c.offset > 0 ? l.infoHandIn(f.inText(f.day(t.dueDate))) : f.dayTime(t.dueDate, t.dueTime);
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
                splash: true,
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
                    if (yearly) l.yearly,
                    if (t.notes.isNotEmpty) '${l.notes}: ${t.notes}',
                  ].join(', '),
                  excludeChildSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StrikeText(
                          t.title,
                          done: t.done,
                          style: TextStyle(fontSize: Fs.task, height: 21 / 15.5, color: tok.text),
                          doneColor: tok.sub,
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
                            if (yearly)
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

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(Sizes.rCard),
      // Gelöscht wird im Formular der Aufgabe; Screenreader haben dafür eine eigene Aktion.
      child: Semantics(
        customSemanticsActions: {CustomSemanticsAction(label: l.deleteTask): () => deleteTaskWithUndo(context, t)},
        child: card,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: widget.highlightable
          ? _FocusPulse(taskId: t.id, focus: widget.ui.focusTask, color: tok.p, child: clipped)
          : clipped,
    );
  }
}

/// Hebt die Karte hervor, wenn [focus] auf ihre Aufgabe zeigt: ins Bild scrollen, zweimal größer
/// werden und in [color] leuchten. Danach wird [focus] wieder `null`.
class _FocusPulse extends StatefulWidget {
  const _FocusPulse({required this.taskId, required this.focus, required this.color, required this.child});
  final String taskId;
  final ValueNotifier<String?> focus;
  final Color color;
  final Widget child;

  @override
  State<_FocusPulse> createState() => _FocusPulseState();
}

class _FocusPulseState extends State<_FocusPulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.focus);

  /// Zweimal anschwellen: groß, fast zurück, noch einmal groß, weich zurück.
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.06).chain(CurveTween(curve: Curves.easeOut)), weight: 18),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.06, end: 1.01).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.01, end: 1.06).chain(CurveTween(curve: Curves.easeOut)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.06, end: 1).chain(CurveTween(curve: Motion.springSoft)),
      weight: 50,
    ),
  ]);

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_check);
    // Die Karte kann erst nach dem Tab-Wechsel entstehen – dann steht der Wunsch schon da.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(_FocusPulse old) {
    super.didUpdateWidget(old);
    if (old.focus != widget.focus) {
      old.focus.removeListener(_check);
      widget.focus.addListener(_check);
    }
  }

  void _check() {
    if (!mounted || widget.focus.value != widget.taskId) return;
    widget.focus.value = null;
    // Nach dem Aufbau des neuen Tabs scrollen, sonst stimmt die Position noch nicht.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = context;
      await Scrollable.ensureVisible(ctx, alignment: 0.3, duration: Motion.of(ctx, Motion.page), curve: Motion.enter);
      if (!mounted) return;
      _c.duration = Motion.of(context, Motion.focus);
      // „Animationen reduzieren“: nur das Leuchten, ohne Bewegung (siehe build).
      await _c.forward(from: 0).orCancel.catchError((_) {});
    });
  }

  @override
  void dispose() {
    widget.focus.removeListener(_check);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (_c.value == 0 || _c.value == 1) return child!;
        // Leuchten: an, bleibt während beider Hüpfer, klingt am Ende aus.
        final glow = (_c.value < 0.6 ? 1.0 : 1 - (_c.value - 0.6) / 0.4).clamp(0.0, 1.0);
        final ring = DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Sizes.rCard),
            border: Border.all(color: widget.color.withValues(alpha: 0.9 * glow), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45 * glow),
                blurRadius: 18 * glow,
              ),
            ],
          ),
          child: child,
        );
        return still ? ring : Transform.scale(scale: _scale.evaluate(_c), child: ring);
      },
      child: widget.child,
    );
  }
}

/// Feste Aufgabe „Gewohnheiten“ ganz oben: jede Gewohnheit ist eine Unteraufgabe für heute.
class HabitsTaskCard extends StatelessWidget {
  const HabitsTaskCard({super.key, required this.ui, this.listMaxHeight});
  final UiState ui;

  /// Höchste Höhe der Liste; darüber scrollt sie in sich (Seitenleiste am PC). `null` = so
  /// hoch wie nötig.
  final double? listMaxHeight;

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
    // Alle Gewohnheiten des Tages erledigt: kurze Funken über der Karte und eine Meldung.
    void celebrate() {
      if (!context.mounted || hs.isEmpty || !hs.every((h) => store.habitDone(h.id, k))) return;
      app.snack.show(l.allHabitsDone, icon: Ic.check);
      if (Motion.reduced(context)) return;
      final colors = [for (final p in _sparkColors) tok.item(p.hex).c];
      showBurst(
        BurstAnchor.of(context),
        duration: Motion.checkGrowAt + Motion.sparkStagger * 2 + Motion.sparks,
        painter: (ms) => SparkPainter(colors: colors, ms: ms),
      );
    }

    // Abgehakte rutschen nach unten; innerhalb bleibt die eigene Reihenfolge.
    final Widget rows = FlipColumn(
      children: [
        for (final h in [...hs.where((h) => !store.habitDone(h.id, k)), ...hs.where((h) => store.habitDone(h.id, k))])
          _HabitSub(key: ValueKey(h.id), habit: h, day: k, ui: ui, onChecked: celebrate),
      ],
    );
    final maxH = listMaxHeight;

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
                  splash: true,
                  onTap: () {
                    if (!store.toggleAllHabitsToday()) return;
                    buzz();
                    celebrate();
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
                            if (maxH == null)
                              rows
                            else
                              ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: maxH),
                                child: SingleChildScrollView(primary: false, child: rows),
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

/// Farben der Funken, wenn alle Gewohnheiten erledigt sind.
const _sparkColors = [
  ColorPreset.mintGreen,
  ColorPreset.sunYellow,
  ColorPreset.coral,
  ColorPreset.skyBlue,
  ColorPreset.lavender,
];

class _HabitSub extends StatelessWidget {
  const _HabitSub({super.key, required this.habit, required this.day, required this.ui, required this.onChecked});
  final Habit habit;
  final String day;
  final UiState ui;

  /// Nach dem Abhaken (nicht beim Wieder-Öffnen).
  final VoidCallback onChecked;

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
            splash: true,
            onTap: () {
              if (!store.toggleHabitDay(h.id, day)) return;
              buzz();
              onChecked();
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

/// Zahl oder kurzer Text (Serie, „2/3“): Ändert sich der Wert, kommt der neue kurz danach von
/// unten herein und blendet ein.
class _Rolling extends StatelessWidget {
  const _Rolling({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final total = Motion.countDelay + Motion.count;
    return AnimatedSwitcher(
      duration: Motion.of(context, total),
      switchInCurve: Interval(Motion.countDelay.inMilliseconds / total.inMilliseconds, 1, curve: Motion.emphasized),
      // Der alte Wert geht sofort.
      switchOutCurve: const Threshold(1),
      transitionBuilder: (child, a) => AnimatedBuilder(
        animation: a,
        builder: (context, c) => Opacity(
          opacity: a.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, Motion.countShift * (1 - a.value)), child: c),
        ),
        child: child,
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

/// Titel einer Aufgabe: Beim Abhaken wird er animiert durchgestrichen und blasser, beim
/// Wieder-Öffnen läuft es rückwärts. Steht er schon erledigt da, wird nichts animiert.
class StrikeText extends StatefulWidget {
  const StrikeText(this.text, {super.key, required this.done, required this.style, required this.doneColor});
  final String text;
  final bool done;
  final TextStyle style;
  final Color doneColor;

  @override
  State<StrikeText> createState() => _StrikeTextState();
}

class _StrikeTextState extends State<StrikeText> with SingleTickerProviderStateMixin {
  static final _total = Motion.doneFadeDelay + Motion.doneFade;
  late final _c = AnimationController(vsync: this, duration: _total, value: 1);

  /// Anteil eines Teils der Animation (0 = offen, 1 = erledigt).
  double _part(Duration delay, Duration dur, Curve curve) {
    final ms = _c.value * _total.inMilliseconds;
    final t = curve.transform(((ms - delay.inMilliseconds) / dur.inMilliseconds).clamp(0.0, 1.0));
    return widget.done ? t : 1 - t;
  }

  @override
  void didUpdateWidget(StrikeText old) {
    super.didUpdateWidget(old);
    if (old.done == widget.done) return;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
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
    builder: (context, _) {
      final style = widget.style;
      if (!_c.isAnimating) {
        return Text(
          widget.text,
          style: style.copyWith(
            color: widget.done ? widget.doneColor : style.color,
            decoration: widget.done ? TextDecoration.lineThrough : null,
            decorationColor: widget.doneColor,
          ),
        );
      }
      final shown = style.copyWith(
        color: Color.lerp(style.color, widget.doneColor, _part(Motion.doneFadeDelay, Motion.doneFade, Curves.ease)),
      );
      return CustomPaint(
        foregroundPainter: _StrikePainter(
          text: widget.text,
          // Gemessen wird mit der festen Schrift – die Farbe ändert die Zeilen nicht.
          style: DefaultTextStyle.of(context).style.merge(style),
          scaler: MediaQuery.textScalerOf(context),
          direction: Directionality.of(context),
          part: _part(Motion.strikeDelay, Motion.strike, Motion.emphasized),
          color: widget.doneColor,
        ),
        child: Text(widget.text, style: shown),
      );
    },
  );
}

/// Strich durch den Text, Zeile für Zeile bis zum Anteil [part] seiner ganzen Länge.
class _StrikePainter extends CustomPainter {
  _StrikePainter({
    required this.text,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.part,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final double part;
  final Color color;

  static final _line = Paint();

  /// Zeilen des zuletzt gemessenen Texts: Während des Strichs ändert sich nur [part], der Text
  /// wird also nicht in jedem Bild neu gesetzt.
  static Object? _measured;
  static List<LineMetrics> _lines = const [];

  List<LineMetrics> _measure(double maxWidth) {
    final key = (text, style, scaler, direction, maxWidth);
    if (key == _measured) return _lines;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    _lines = tp.computeLineMetrics();
    tp.dispose();
    _measured = key;
    return _lines;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (part <= 0) return;
    final lines = _measure(size.width + 0.5);
    // Lage und Stärke wie der Strich der Schrift (Roboto: ¼ bzw. 1/20 der Schriftgröße).
    final fs = scaler.scale(style.fontSize ?? Fs.task);
    final paint = _line
      ..color = color
      ..strokeWidth = math.max(1, fs * 0.05);
    var left = part * lines.fold<double>(0, (a, m) => a + m.width);
    for (final m in lines) {
      if (left <= 0) break;
      final w = math.min(left, m.width);
      final y = m.baseline - fs * 0.25;
      canvas.drawLine(Offset(m.left, y), Offset(m.left + w, y), paint);
      left -= w;
    }
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.part != part ||
      old.color != color ||
      old.text != text ||
      old.style != style ||
      old.scaler != scaler ||
      old.direction != direction;
}
