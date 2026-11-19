import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/holidays.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/pickers.dart';
import '../widgets/ui.dart';
import 'older_done.dart';
import 'sheets.dart';
import 'task_card.dart';
import 'ui_state.dart';

/// Eine Liste im Aufgaben-Tab: ein Zeitraum („Heute“, [section] gesetzt) oder eine Kategorie
/// ([color] gesetzt).
typedef TaskGroup = ({String id, String label, List<Task> items, Color? color, Section? section});

/// Aufgaben am PC: jede Gruppe ist eine eigene Liste nebeneinander. Höchstens drei sind
/// gleichzeitig zu sehen; die übrigen erreicht man durch Wischen oder mit den Pfeilen.
class TasksBoard extends StatelessWidget {
  const TasksBoard({super.key, required this.ui, required this.groups, required this.showOlder, this.olderCat});
  final UiState ui;
  final List<TaskGroup> groups;

  /// Ältere erledigte Aufgaben liegen noch online – der Hinweis steht am Ende von „Erledigt“.
  final bool showOlder;
  final String? olderCat;

  static const maxVisible = 3;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final visible = (box.maxWidth / Sizes.boardListMin).floor().clamp(1, maxVisible);
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
            itemCount: b.groups.length,
            itemBuilder: (context, i) {
              final g = b.groups[i];
              return _ListPanel(
                key: ValueKey(g.id),
                ui: b.ui,
                group: g,
                older: b.showOlder && g.section == Section.done,
                olderCat: b.olderCat,
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconBtn(Ic.left, label: l.prevLists, onTap: first > 0 ? () => go(first - 1) : null),
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
            IconBtn(Ic.right, label: l.nextLists, onTap: first < last ? () => go(first + 1) : null),
          ],
        );
      },
    );
  }
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({super.key, required this.ui, required this.group, required this.older, this.olderCat});
  final UiState ui;
  final TaskGroup group;
  final bool older;
  final String? olderCat;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final g = group;
    final overdue = g.section == Section.overdue;
    // Neue Aufgabe direkt in dieser Liste – nicht bei „Überfällig“ und „Erledigt“.
    final addable = g.section != Section.overdue && g.section != Section.done;
    final preset = switch (g.section) {
      Section.today => today(),
      Section.tomorrow => addDays(today(), 1),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: tok.glass,
        borderRadius: BorderRadius.circular(Sizes.rCardLarge),
        border: Border.all(color: tok.glassEdge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Semantics(
              header: true,
              label: l.sectionCount(g.label, g.items.length),
              excludeSemantics: true,
              child: Row(
                children: [
                  if (g.color != null) ...[Dot(g.color!), const SizedBox(width: 8)],
                  Expanded(
                    child: Text(
                      g.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Fs.task,
                        fontWeight: FontWeight.w500,
                        color: overdue ? tok.err : tok.text,
                      ),
                    ),
                  ),
                  Text(
                    '${g.items.length}',
                    style: TextStyle(fontSize: Fs.meta, color: tok.sub, fontFeatures: Fs.tabular),
                  ),
                ],
              ),
            ),
          ),
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
                if (addable)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: AppButton(
                        label: l.task,
                        icon: Ic.plus,
                        kind: BtnKind.text,
                        height: 36,
                        padding: 10,
                        fontSize: 13,
                        onTap: () => Sheets(context, ui).task(null, preset: preset),
                      ),
                    ),
                  ),
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
  Widget build(BuildContext context) => ListView(
    primary: false,
    padding: const EdgeInsets.fromLTRB(0, 14, 4, Sizes.wideBottom),
    children: [
      const _TodayPanel(),
      HabitsTaskCard(ui: ui),
      _MonthPanel(ui: ui),
    ],
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
      if (t.done) {
        final at = t.doneAt;
        if (at != null && sameDay(at.toLocal(), now)) done++;
        continue;
      }
      final s = sectionOf(t, store.catOf(t.categoryId).offset, now: now);
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
