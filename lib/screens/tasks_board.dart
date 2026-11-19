import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/holidays.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/pickers.dart';
import '../widgets/ui.dart';
import 'older_done.dart';
import 'task_card.dart';
import 'ui_state.dart';

/// Eine Liste im Aufgaben-Tab: ein Zeitraum („Heute“, [section] gesetzt) oder eine Kategorie
/// ([color] gesetzt).
typedef TaskGroup = ({String id, String label, List<Task> items, Color? color, Section? section});

/// Name eines Zeitraums („Heute“, „Diese Woche“ …).
String sectionLabel(AppLocalizations l, Section s) => switch (s) {
  Section.overdue => l.overdue,
  Section.today => l.today,
  Section.tomorrow => l.tomorrow,
  Section.week => l.thisWeek,
  Section.later => l.later,
  Section.done => l.done,
};

/// Aufgaben am PC: jede Gruppe ist eine eigene Liste nebeneinander. [maxVisible] davon sind
/// gleichzeitig zu sehen (einstellbar unter ⋮ → Spalten); die übrigen erreicht man durch
/// Wischen oder mit den Pfeilen. Mit [onMove] lassen sich die Listen an ihrer Überschrift
/// umsortieren.
class TasksBoard extends StatelessWidget {
  const TasksBoard({
    super.key,
    required this.ui,
    required this.groups,
    required this.showOlder,
    this.olderCat,
    this.maxVisible = 3,
    this.onMove,
  });
  final UiState ui;
  final List<TaskGroup> groups;
  final int maxVisible;

  /// Liste `id` wurde auf die Liste `target` gezogen. `null` = Reihenfolge steht fest.
  final void Function(String id, String target)? onMove;

  /// Ältere erledigte Aufgaben liegen noch online – der Hinweis steht am Ende von „Erledigt“.
  final bool showOlder;
  final String? olderCat;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Die eingestellte Anzahl gilt – weniger nur, wenn es nicht so viele Listen gibt oder
      // das Fenster dafür wirklich zu schmal ist.
      final fit = math.max(1, (box.maxWidth / Sizes.boardListMin).floor());
      final visible = math.max(1, [maxVisible, groups.length, fit].reduce(math.min));
      // Der Schlüssel wechselt mit der Anzahl: Der Seiten-Regler kennt seine Breite nur beim Anlegen.
      return _Lists(key: ValueKey(visible), board: this, visible: visible);
    },
  );
}

class _Lists extends StatefulWidget {
  const _Lists({super.key, required this.board, required this.visible});
  final TasksBoard board;
  final int visible;

  @override
  State<_Lists> createState() => _ListsState();
}

class _ListsState extends State<_Lists> {
  late final _pages = PageController(viewportFraction: 1 / widget.visible);

  /// Die Maus steht auf einer Überschrift: Ziehen greift dann die Liste, statt zu blättern.
  bool _grab = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.board;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            padEnds: false,
            physics: _grab ? const NeverScrollableScrollPhysics() : null,
            itemCount: b.groups.length,
            itemBuilder: (context, i) {
              final g = b.groups[i];
              final move = b.groups.length > 1 ? b.onMove : null;
              return _ListPanel(
                key: ValueKey(g.id),
                ui: b.ui,
                group: g,
                older: b.showOlder && g.section == Section.done,
                olderCat: b.olderCat,
                onDrop: move == null ? null : (id) => move(id, g.id),
                onGrab: (on) => setState(() => _grab = on),
                onLeft: move == null || i == 0 ? null : () => move(g.id, b.groups[i - 1].id),
                onRight: move == null || i == b.groups.length - 1 ? null : () => move(g.id, b.groups[i + 1].id),
              );
            },
          ),
        ),
        if (b.groups.length > widget.visible) _Pager(pages: _pages, count: b.groups.length, visible: widget.visible),
      ],
    );
  }
}

/// Pfeile und Punkte unter den Listen: zeigen, welche gerade zu sehen sind.
class _Pager extends StatelessWidget {
  const _Pager({required this.pages, required this.count, required this.visible});
  final PageController pages;
  final int count;
  final int visible;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    return AnimatedBuilder(
      animation: pages,
      builder: (context, _) {
        final first = (pages.hasClients && pages.position.haveDimensions ? pages.page ?? 0 : 0).round();
        final last = count - visible;
        void go(int to) => pages.animateToPage(
          to.clamp(0, last),
          duration: Motion.of(context, Motion.page),
          curve: Curves.easeOutCubic,
        );
        // Beim Umsortieren blättert ein Pfeil schon, wenn man die Liste darüber hält.
        Widget hover(int to, Widget child) => DragTarget<String>(
          onWillAcceptWithDetails: (_) {
            go(to);
            return false;
          },
          builder: (context, _, _) => child,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            hover(first - 1, IconBtn(Ic.left, label: l.prevLists, onTap: first > 0 ? () => go(first - 1) : null)),
            ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.fast),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i >= first && i < first + visible ? tok.p : tok.line,
                      ),
                    ),
                ],
              ),
            ),
            hover(first + 1, IconBtn(Ic.right, label: l.nextLists, onTap: first < last ? () => go(first + 1) : null)),
          ],
        );
      },
    );
  }
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({
    super.key,
    required this.ui,
    required this.group,
    required this.older,
    this.olderCat,
    this.onDrop,
    this.onGrab,
    this.onLeft,
    this.onRight,
  });
  final UiState ui;
  final TaskGroup group;
  final bool older;
  final String? olderCat;

  /// Eine andere Liste (ihre ID) wurde auf diese gezogen. `null` = Reihenfolge steht fest.
  final ValueChanged<String>? onDrop;

  /// Die Maus kommt auf die Überschrift (`true`) oder verlässt sie.
  final ValueChanged<bool>? onGrab;

  /// Diese Liste um einen Platz verschieben (für Screenreader und Tastatur-Hilfen).
  final VoidCallback? onLeft, onRight;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final g = group;
    final overdue = g.section == Section.overdue;
    final title = TextStyle(
      fontSize: Fs.task,
      fontWeight: FontWeight.w500,
      color: overdue ? tok.err : tok.text,
      decoration: TextDecoration.none,
    );
    Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Semantics(
        header: true,
        label: l.sectionCount(g.label, g.items.length),
        excludeSemantics: true,
        customSemanticsActions: {
          CustomSemanticsAction(label: l.moveLeft): ?onLeft,
          CustomSemanticsAction(label: l.moveRight): ?onRight,
        },
        child: Row(
          children: [
            if (g.color != null) ...[Dot(g.color!), const SizedBox(width: 8)],
            Expanded(
              child: Text(g.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: title),
            ),
            Text(
              '${g.items.length}',
              style: TextStyle(fontSize: Fs.meta, color: tok.sub, fontFeatures: Fs.tabular),
            ),
          ],
        ),
      ),
    );
    if (onDrop != null) {
      // Das Kärtchen, das beim Ziehen am Zeiger hängt.
      final feedback = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: tok.card,
          borderRadius: BorderRadius.circular(Sizes.rCard),
          border: Border.all(color: tok.p),
          boxShadow: tok.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (g.color != null) ...[Dot(g.color!), const SizedBox(width: 8)],
            Text(g.label, style: title),
          ],
        ),
      );
      final dim = Opacity(opacity: 0.35, child: header);
      final grab = MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => onGrab?.call(true),
        onExit: (_) => onGrab?.call(false),
        child: header,
      );
      // Mit der Maus sofort ziehen; am Touchscreen erst nach langem Druck, damit Wischen
      // weiter zwischen den Listen blättert.
      final touch = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
      header = touch
          ? LongPressDraggable<String>(data: g.id, feedback: feedback, childWhenDragging: dim, child: grab)
          : Draggable<String>(data: g.id, feedback: feedback, childWhenDragging: dim, child: grab);
    }
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => onDrop != null && d.data != g.id,
      onAcceptWithDetails: (d) => onDrop?.call(d.data),
      builder: (context, over, _) => _panel(context, header, drop: over.isNotEmpty),
    );
  }

  Widget _panel(BuildContext context, Widget header, {required bool drop}) {
    final tok = context.tok;
    final l = context.l;
    final g = group;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: tok.glass,
        borderRadius: BorderRadius.circular(Sizes.rCardLarge),
        // Leuchtet, solange eine gezogene Liste darüber schwebt: Hier landet sie.
        border: Border.all(color: drop ? tok.p : tok.glassEdge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: ListView(
              // Mehrere Listen nebeneinander: keine teilt sich den Scroll-Regler der Seite.
              primary: false,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final t in g.items) TaskCard(key: ValueKey(t.id), task: t, ui: ui),
                if (g.items.isEmpty && !older)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                    child: Text(
                      l.noTasks,
                      style: TextStyle(fontSize: Fs.meta, color: tok.sub),
                    ),
                  ),
                if (older) OlderDoneHint(categoryId: olderCat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seitenleiste neben den Listen: Stand von heute, Gewohnheiten und der laufende Monat.
class TasksSide extends StatelessWidget {
  const TasksSide({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(0, 14, 4, Sizes.wideBottom),
      children: [
        const _TodayPanel(),
        // Viele Gewohnheiten schieben den Monat nicht aus dem Fenster: Die Liste scrollt in sich.
        HabitsTaskCard(
          ui: ui,
          listMaxHeight: (box.maxHeight - Sizes.sideFixed).clamp(Sizes.sideHabitsMin, double.infinity),
        ),
        _MonthPanel(ui: ui),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tok.card,
        borderRadius: BorderRadius.circular(Sizes.rCard),
        boxShadow: tok.cardShadow,
      ),
      child: child,
    );
  }
}

/// Wie viel von heute geschafft ist: Ring mit „erledigt/gesamt“ und was noch offen ist.
/// Es zählt, was heute dran ist oder war (überfällig oder heute zu tun) – eine Aufgabe von
/// nächster Woche, die man heute schon abhakt, verändert den Ring nicht.
class _TodayPanel extends StatelessWidget {
  const _TodayPanel();

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    final tok = context.tok;
    final l = context.l;
    final now = clock();
    var open = 0, late = 0, done = 0;
    for (final t in store.tasks) {
      final off = store.catOf(t.categoryId).offset;
      if (t.done) {
        final at = t.doneAt;
        if (at != null && sameDay(at.toLocal(), now) && !doDate(t, off).isAfter(sod(now))) done++;
        continue;
      }
      final s = sectionOf(t, off, now: now);
      if (s == Section.overdue) late++;
      if (s == Section.overdue || s == Section.today) open++;
    }
    final total = open + done;
    final summary = open == 0 ? l.todayAllDone : (late > 0 ? l.todayOpenLate(open, late) : l.todayOpen(open));
    return _Panel(
      child: Semantics(
        container: true,
        label: '${l.today}: ${l.progress(done, total)}, $summary',
        excludeSemantics: true,
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: total == 0 ? 0 : done / total),
              duration: Motion.of(context, Motion.bar),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => CustomPaint(
                painter: _RingPainter(value: v, color: tok.p, track: tok.pc),
                child: child,
              ),
              child: SizedBox.square(
                dimension: 60,
                child: Center(
                  child: Text(
                    l.progress(done, total),
                    style: TextStyle(
                      fontSize: Fs.meta,
                      fontWeight: FontWeight.w500,
                      color: tok.text,
                      fontFeatures: Fs.tabular,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.today,
                    style: TextStyle(fontSize: Fs.task, fontWeight: FontWeight.w500, color: tok.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: TextStyle(fontSize: Fs.meta, color: late > 0 ? tok.err : tok.sub),
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

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color, required this.track});
  final double value;
  final Color color;
  final Color track;

  static const _stroke = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value.clamp(0, 1), false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

/// Der laufende Monat mit Punkten an den Tagen, an denen etwas fällig ist. Ein Tipp auf einen
/// Tag öffnet ihn im Kalender.
class _MonthPanel extends StatelessWidget {
  const _MonthPanel({required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final now = today();
    final month = DateTime(now.year, now.month);
    final catsByDay = openCategoriesByDay(store.tasksWithOlder);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              f.monthYear(month),
              style: TextStyle(fontSize: Fs.task, fontWeight: FontWeight.w500, color: tok.text),
            ),
          ),
          const SizedBox(height: 6),
          MonthGrid(
            month: month,
            padding: EdgeInsets.zero,
            wdFontSize: 11,
            wdPadding: 4,
            cell: (d, other) {
              final holiday = holidayOn(d);
              return DayCell(
                day: d,
                other: other,
                selected: false,
                holiday: holiday != null,
                height: 42,
                circle: 30,
                semanticLabel: holiday == null ? f.dayMonth(d) : '${f.dayMonth(d)}, ${holidayName(l, holiday)}',
                below: DayDots(
                  colors: [
                    for (final id in catsByDay[isoDate(d)] ?? const <String>{}) tok.item(store.catOf(id).color).c,
                  ],
                ),
                onTap: () {
                  ui.calSel = d;
                  ui.calMonth = DateTime(d.year, d.month);
                  ui.goTab(AppTab.calendar);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
