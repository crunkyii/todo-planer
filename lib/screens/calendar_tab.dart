import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../widgets/app_icon.dart';
import '../widgets/pickers.dart';
import '../widgets/ui.dart';
import 'task_card.dart';
import 'ui_state.dart';

/// Tab „Kalender“: Monatsraster mit Farbpunkten je Kategorie und Liste des gewählten Tags.
class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.store, app.sync]),
      builder: (context, _) {
        final store = app.store;
        final tok = context.tok;
        final l = context.l;
        final f = Fmt.of(context);
        final m = ui.calMonth;
        final sel = ui.calSel;
        final tasks = store.tasks;
        final selTasks = tasks.where((t) => sameDay(t.dueDate, sel)).toList()..sort((a, b) => a.due.compareTo(b.due));

        // Ein Durchlauf: offene Kategorien je Tag (statt pro Zelle alle Aufgaben zu durchsuchen).
        final catsByDay = <String, Set<String>>{};
        for (final t in tasks) {
          if (!t.done) (catsByDay[isoDate(t.dueDate)] ??= <String>{}).add(t.categoryId);
        }

        Widget dots(DateTime d, bool selected) {
          final cats = (catsByDay[isoDate(d)] ?? const <String>{}).toList();
          return SizedBox(
            height: 9,
            child: cats.length > 4
                ? Text(
                    '${cats.length}',
                    style: TextStyle(
                      fontSize: 10,
                      height: 0.9,
                      fontWeight: FontWeight.w700,
                      color: selected ? tok.text : tok.sub,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < cats.length; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Dot(tok.item(store.catOf(cats[i]).color).c, size: 5),
                      ],
                    ],
                  ),
          );
        }

        void move(int dir) => ui.set((s) => s.calMonth = DateTime(m.year, m.month + dir));

        return ListView(
          padding: EdgeInsets.only(bottom: Sizes.contentBottom + MediaQuery.paddingOf(context).bottom),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        f.monthYear(m),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: tok.text),
                      ),
                    ),
                  ),
                  IconBtn(Ic.left, label: l.prevMonth, onTap: () => move(-1)),
                  IconBtn(Ic.right, label: l.nextMonth, onTap: () => move(1)),
                ],
              ),
            ),
            // Links/rechts wischen blättert den Monat (wie die Pfeile oben).
            _MonthSwipe(
              onMove: move,
              child: MonthGrid(
                month: m,
                cell: (d, other) {
                  final isSel = sameDay(d, sel);
                  return DayCell(
                    day: d,
                    other: other,
                    selected: isSel,
                    semanticLabel: f.dayMonth(d),
                    below: dots(d, isSel),
                    onTap: () => ui.set((s) {
                      s.calSel = d;
                      if (d.month != m.month || d.year != m.year) s.calMonth = DateTime(d.year, d.month);
                    }),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tok.lineSoft)),
              ),
              child: Semantics(
                header: true,
                child: Text(
                  f.longDate(sel),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tok.text),
                ),
              ),
            ),
            if (selTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(l.nothingDue, style: TextStyle(fontSize: 14, color: tok.sub)),
              )
            else
              for (final t in selTasks) TaskCard(key: ValueKey(t.id), task: t, ui: ui),
          ],
        );
      },
    );
  }
}

/// Erkennt waagrechtes Wischen über dem Monatsraster: nach links = nächster Monat,
/// nach rechts = voriger Monat. Zählt ab [_minDistance] Weg oder bei schnellem Wisch.
class _MonthSwipe extends StatefulWidget {
  const _MonthSwipe({required this.onMove, required this.child});
  final void Function(int dir) onMove;
  final Widget child;

  @override
  State<_MonthSwipe> createState() => _MonthSwipeState();
}

class _MonthSwipeState extends State<_MonthSwipe> {
  static const _minDistance = 48.0;
  static const _minVelocity = 300.0;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true, // Screenreader nutzen die Pfeil-Knöpfe
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_dx.abs() < _minDistance && v.abs() < _minVelocity) return;
        // Bei schnellem Wisch entscheidet die Richtung der Bewegung am Ende.
        final right = v.abs() >= _minVelocity ? v > 0 : _dx > 0;
        widget.onMove(right ? -1 : 1);
      },
      child: widget.child,
    );
  }
}
