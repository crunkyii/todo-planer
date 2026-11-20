import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'dates.dart';

/// Datums- und Zahlenformate in der gewählten Sprache (intl).
/// Deutsch nutzt österreichische Monatsnamen („Jänner“) wie im Prototyp. Englisch schreibt
/// den Monat vor den Tag („Nov 18“), Spanisch, Französisch und Italienisch den Tag ohne Punkt
/// davor („18 nov.“).
class Fmt {
  Fmt(this.l) : en = l.localeName == 'en', de = l.localeName == 'de', _loc = _locale(l.localeName);

  final AppLocalizations l;
  final bool en;
  final bool de;
  final String _loc;

  static String _locale(String lang) => lang == 'de' ? 'de_AT' : lang;

  /// Erster Buchstabe groß („lunes“ → „Lunes“, „noviembre de 2026“ → „Noviembre de 2026“).
  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static Fmt of(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Fmt(l);
  }

  static final _monday = DateTime(2024, 1, 1);

  /// Einmal gebaute Formate je Muster und Sprache – ein DateFormat anzulegen kostet viel mehr
  /// als damit zu formatieren, und Listen formatieren bei jedem Neuaufbau Dutzende Daten.
  static final _formats = <String, DateFormat>{};
  DateFormat _df(String key, DateFormat Function() make) => _formats.putIfAbsent('$key|$_loc', make);

  /// „Mo“, „Di“ … bzw. „Mo“, „Tu“ … (zwei Buchstaben wie im Prototyp).
  String wd(int i) {
    final s = _df('E', () => DateFormat.E(_loc)).format(addDays(_monday, i)).replaceAll('.', '');
    return _cap(s.length > 2 ? s.substring(0, 2) : s);
  }

  String wdLong(int i) => _cap(_df('EEEE', () => DateFormat.EEEE(_loc)).format(addDays(_monday, i)));
  String monthYear(DateTime d) => _cap(_df('yMMMM', () => DateFormat.yMMMM(_loc)).format(d));

  /// „Dezember“ – der Monat allein (Vorschau beim Wischen im Kalender).
  String month(DateTime d) => _cap(_df('LLLL', () => DateFormat.LLLL(_loc)).format(d));

  /// „Nov.“, „Juli“, „Jän.“ / „Nov“ – dieselbe Form wie in [dayMon]. Ein einzelnes `MMM`
  /// liefert in intl die alleinstehende Form ohne Punkt („Nov“, „Jul“), der Prototyp zeigt die mit Punkt.
  String monShort(DateTime d) => _df('', () => DateFormat(null, _loc)).dateSymbols.SHORTMONTHS[d.month - 1];

  /// „18. November“ / „November 18“
  String dayMonth(DateTime d) => _df(
    'dayMonth',
    () => DateFormat(en ? 'MMMM d' : (de ? 'd. MMMM' : DateFormat.MMMMd(_loc).pattern), _loc),
  ).format(d);

  /// „18. Nov.“ / „Nov 18“
  String dayMon(DateTime d) =>
      _df('dayMon', () => DateFormat(en ? 'MMM d' : (de ? 'd. MMM' : 'd MMM'), _loc)).format(d);

  /// „18.11.2026“ / „11/18/2026“ – das ganze Datum mit Jahr (Export).
  String fullDate(DateTime d) => en
      ? _df('yMd', () => DateFormat.yMd(_loc)).format(d)
      : '${pad2(d.day)}${de ? '.' : '/'}${pad2(d.month)}${de ? '.' : '/'}${d.year}';

  /// „Fr 27. Nov.“ / „Fr Nov 27“ – Ende des Zeitraums im Widget „Demnächst“ (wie in Kotlin).
  String wdDayMon(DateTime d) => '${wd(wdIndex(d))} ${dayMon(d)}';

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
    final date = en ? '${d.month}/${d.day}' : (de ? '${d.day}.${d.month}.' : '${d.day}/${d.month}');
    return l.weekdayShortWithDate(wd(wdIndex(d)), date);
  }

  /// Ein Tag mitten im Satz („Abgabe Morgen“, „Entrega mañana“): Spanisch, Französisch und
  /// Italienisch schreiben dort klein, Deutsch und Englisch bleiben wie gewohnt.
  String inText(String s) => en || de || s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

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
    if (en) return '${monShort(we)} ${ws.day}–${we.day}';
    return de ? '${ws.day}.–${we.day}. ${monShort(we)}' : '${ws.day}–${we.day} ${monShort(we)}';
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
  String dayNum(DateTime d) => de ? '${d.day}.' : '${d.day}';

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
