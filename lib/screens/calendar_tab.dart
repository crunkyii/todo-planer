import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/holidays.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/pickers.dart';
import '../widgets/swipe.dart';
import '../widgets/layout.dart';
import '../widgets/ui.dart';
import 'older_done.dart';
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
        final tasks = store.tasksWithOlder;
        final selHoliday = holidayOn(sel);
        final selTasks = tasks.where((t) => sameDay(t.dueDate, sel)).toList()..sort((a, b) => a.due.compareTo(b.due));

        final catsByDay = openCategoriesByDay(tasks);

        Widget dots(DateTime d, bool selected) => DayDots(
          selected: selected,
          colors: [for (final id in catsByDay[isoDate(d)] ?? const <String>{}) tok.item(store.catOf(id).color).c],
        );

        void move(int dir) => ui.set((s) => s.calMonth = DateTime(m.year, m.month + dir));
        String peek(int dir) => f.month(DateTime(m.year, m.month + dir));

        return LayoutBuilder(
          builder: (context, box) {
            final wide = ShellLayout.wideOf(context) && box.maxWidth >= Sizes.calTwoPane;
            final month = [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRect(
                        child: Semantics(
                          header: true,
                          liveRegion: true,
                          child: PageTitle(
                            page: m,
                            // Am schmalen Handy wird ein langer Monat („September 2026“) kleiner statt
                            // abgeschnitten – daneben stehen Pfeile und „Heute“.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                f.monthYear(m),
                                maxLines: 1,
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: tok.text),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconBtn(Ic.left, label: l.prevMonth, onTap: () => move(-1)),
                    AppButton(
                      label: l.today,
                      kind: BtnKind.text,
                      padding: MediaQuery.sizeOf(context).width <= Sizes.narrowWidth ? 8 : 16,
                      onTap: () => ui.set((s) {
                        s.calMonth = DateTime(clock().year, clock().month);
                        s.calSel = today();
                      }),
                    ),
                    IconBtn(Ic.right, label: l.nextMonth, onTap: () => move(1)),
                  ],
                ),
              ),
              // Links/rechts wischen blättert den Monat (wie die Pfeile oben).
              SwipePager(
                page: m,
                onMove: move,
                peek: peek,
                child: MonthGrid(
                  month: m,
                  cell: (d, other) {
                    final isSel = sameDay(d, sel);
                    final holiday = holidayOn(d);
                    return DayCell(
                      day: d,
                      other: other,
                      selected: isSel,
                      holiday: holiday != null,
                      semanticLabel: holiday == null ? f.dayMonth(d) : '${f.dayMonth(d)}, ${holidayName(l, holiday)}',
                      below: dots(d, isSel),
                      onTap: () => ui.set((s) {
                        s.calSel = d;
                        if (d.month != m.month || d.year != m.year) s.calMonth = DateTime(d.year, d.month);
                      }),
                    );
                  },
                ),
              ),
            ];
            final day = [
              Container(
                margin: EdgeInsets.only(top: wide ? 0 : 12),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                decoration: BoxDecoration(
                  // Schmal trennt die Linie Monat und Tag; breit stehen sie nebeneinander.
                  border: wide ? null : Border(top: BorderSide(color: tok.lineSoft)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        f.longDate(sel),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tok.text),
                      ),
                    ),
                    if (selHoliday != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l.holidayLine(holidayName(l, selHoliday)),
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: tok.err),
                        ),
                      ),
                  ],
                ),
              ),
              if (selTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text(l.nothingDue, style: TextStyle(fontSize: 14, color: tok.sub)),
                )
              else
                for (final t in selTasks) TaskCard(key: ValueKey(t.id), task: t, ui: ui, highlightable: false),
              OlderDoneHint(dueDay: isoDate(sel)),
            ];
            final bottom = EdgeInsets.only(bottom: ShellLayout.bottomOf(context));
            if (!wide) return ListView(padding: bottom, children: [...month, ...day]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(padding: bottom, children: month),
                ),
                SizedBox(
                  width: Sizes.calSide,
                  child: ListView(padding: bottom, children: day),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
