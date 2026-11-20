import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'dates.dart';

/// Datums- und Zahlenformate in der gewählten Sprache (intl).
/// Deutsch nutzt österreichische Monatsnamen („Jänner“) wie im Prototyp.
class Fmt {
  Fmt(this.l) : en = l.localeName == 'en', _loc = l.localeName == 'en' ? 'en' : 'de_AT';

  final AppLocalizations l;
  final bool en;
  final String _loc;

  static Fmt of(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Fmt(l);
  }

  static final _monday = DateTime(2024, 1, 1);

  /// „Mo“, „Di“ … bzw. „Mo“, „Tu“ … (zwei Buchstaben wie im Prototyp).
  String wd(int i) {
    final s = DateFormat.E(_loc).format(addDays(_monday, i)).replaceAll('.', '');
    return s.length > 2 ? s.substring(0, 2) : s;
  }

  String wdLong(int i) => DateFormat.EEEE(_loc).format(addDays(_monday, i));
  String monthYear(DateTime d) => DateFormat.yMMMM(_loc).format(d);

  /// „Dezember“ – der Monat allein (Vorschau beim Wischen im Kalender).
  String month(DateTime d) => DateFormat.LLLL(_loc).format(d);

  /// „Nov.“, „Juli“, „Jän.“ / „Nov“ – dieselbe Form wie in [dayMon]. Ein einzelnes `MMM`
  /// liefert in intl die alleinstehende Form ohne Punkt („Nov“, „Jul“), der Prototyp zeigt die mit Punkt.
  String monShort(DateTime d) => DateFormat(null, _loc).dateSymbols.SHORTMONTHS[d.month - 1];

  /// „18. November“ / „November 18“
  String dayMonth(DateTime d) => en ? DateFormat('MMMM d', _loc).format(d) : DateFormat('d. MMMM', _loc).format(d);

  /// „18. Nov.“ / „Nov 18“
  String dayMon(DateTime d) => en ? DateFormat('MMM d', _loc).format(d) : DateFormat('d. MMM', _loc).format(d);

  /// „18.11.2026“ / „11/18/2026“ – das ganze Datum mit Jahr (Export).
  String fullDate(DateTime d) => en ? DateFormat.yMd(_loc).format(d) : '${pad2(d.day)}.${pad2(d.month)}.${d.year}';

  /// „18. NOV.“ / „NOV 18“ – das Datum neben „Heute“ im Startbildschirm-Widget.
  String widgetDate(DateTime d) => dayMon(d).toUpperCase();

  /// „Dienstag, 18. November“
  String longDate(DateTime d) => l.weekdayWithDate(wdLong(wdIndex(d)), dayMonth(d));

  /// Heute / Morgen / Gestern, sonst „Mo 24.11.“ bzw. „Mo 11/24“.
  String day(DateTime d) {
    final diff = dayDiff(d, clock());
    if (diff == 0) return l.today;
    if (diff == 1) return l.tomorrow;
    if (diff == -1) return l.yesterday;
    final date = en ? '${d.month}/${d.day}' : '${d.day}.${d.month}.';
    return l.weekdayShortWithDate(wd(wdIndex(d)), date);
  }

  /// „Heute“ bzw. „Heute, 16:00“, wenn eine Uhrzeit gesetzt ist.
  String dayTime(DateTime d, int? minutes) => minutes == null ? day(d) : l.dayWithTime(day(d), time(minutes));

  /// Beschriftung im Datums-Knopf des Sheets.
  String dateLabel(DateTime d) {
    final diff = dayDiff(d, clock());
    if (diff >= -1 && diff <= 1) return day(d);
    return l.weekdayWithDate(wd(wdIndex(d)), dayMon(d));
  }

  /// [d] = erster Tag der gezeigten Woche. Beginnt sie nicht am Montag, zählt die
  /// Kalenderwoche, in der die meisten ihrer Tage liegen.
  String weekLabel(DateTime d) => l.weekNumber(isoWeek(addDays(d, 3)));

  /// „17.–23. Nov.“ / „Nov 17–23“ / „29. Dez. – 4. Jän.“
  String weekRange(DateTime ws) {
    final we = addDays(ws, 6);
    if (ws.month != we.month) return l.rangeDash(dayMon(ws), dayMon(we));
    return en ? '${monShort(we)} ${ws.day}–${we.day}' : '${ws.day}.–${we.day}. ${monShort(we)}';
  }

  String time(int minutes) => hmString(minutes);

  /// Dauer im Block-Sheet: „1 Std. 30 Min.“
  String duration(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    if (h > 0 && m > 0) return l.durHoursMin(h, m);
    if (h > 0) return l.durHours(h);
    return l.durMin(m);
  }

  String oneDecimal(double v) => NumberFormat('0.0', _loc).format(v);

  /// Tag im Balkendiagramm (30 Tage): „18.“ / „18“
  String dayNum(DateTime d) => en ? '${d.day}' : '${d.day}.';

  /// „Am selben Tag“ / „2 Tage vorher“ / „1 Woche vorher“ (für Kategorien).
  String offsetLabel(int o) => o == 0 ? l.offsetSameDay : (o == 7 ? l.offsetWeekBefore : l.offsetDaysBefore(o));

  String categoryInfo(int offset, int open, [ListFrom from = ListFrom.always]) {
    final s = offset == 0
        ? l.catDoSameDay(open)
        : offset == 7
        ? l.catDoWeekBefore(open)
        : l.catDoDaysBefore(offset, open);
    return from == ListFrom.always ? s : '$s · ${listFromLabel(from)}';
  }

  String listFromLabel(ListFrom f) => switch (f) {
    ListFrom.always => l.listFromAlways,
    ListFrom.week => l.listFromWeek,
    ListFrom.tomorrow => l.listFromTomorrow,
    ListFrom.today => l.listFromToday,
    ListFrom.never => l.listFromNever,
  };
}
