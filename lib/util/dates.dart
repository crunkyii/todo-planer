// Datums-Hilfen aus dem Prototyp (sod, addDays, monday, iso …). Alles in lokaler Zeit.

String pad2(int n) => n.toString().padLeft(2, '0');

/// Tagesbeginn (Mitternacht) von [d].
DateTime sod(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => sod(DateTime.now());

/// Addiert Kalendertage (sommerzeit-sicher, weil über Jahr/Monat/Tag gerechnet).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

/// Wochentag 0 = Montag … 6 = Sonntag.
int wdIndex(DateTime d) => d.weekday - 1;

DateTime monday(DateTime d) => addDays(sod(d), -wdIndex(d));

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Ganze Tage zwischen [a] und [b] (a − b).
int dayDiff(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

String isoDate(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

DateTime parseIsoDate(String s) {
  final p = s.substring(0, 10).split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String hmString(int minutes) => '${pad2(minutes ~/ 60)}:${pad2(minutes % 60)}';

/// `HH:MM` (auch `HH:MM:SS`) → Minuten seit Mitternacht.
int parseHm(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// ISO-Kalenderwoche.
int isoWeek(DateTime d) {
  final t = addDays(sod(d), 3 - wdIndex(d));
  final w1 = DateTime(t.year, 1, 4);
  return 1 + ((dayDiff(t, w1) - 3 + wdIndex(w1)) / 7).round();
}

/// Serie: wie viele Tage in Folge [isDone] gilt – heute zählt mit, wenn erledigt,
/// sonst beginnt die Zählung gestern (wie `streak()` im Prototyp).
int streak(bool Function(DateTime) isDone, {DateTime? from}) {
  final t = from ?? today();
  var n = 0;
  var d = isDone(t) ? 0 : 1;
  while (isDone(addDays(t, -d))) {
    n++;
    d++;
  }
  return n;
}
