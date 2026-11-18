import '../data/models.dart';
import 'dates.dart';

/// Wörter, bei denen sich eine Aufgabe jedes Jahr wiederholt (Deutsch und Englisch).
const yearlyWords = [
  'geburtstag',
  'jahrestag',
  'hochzeitstag',
  'namenstag',
  'todestag',
  'jubiläum',
  'jubilaeum',
  'birthday',
  'bday',
  'anniversary',
];

// Das ganze Wort samt Vorsilbe („Kindergeburtstag“), aber nicht mitten in einem längeren
// („Geburtstagsgeschenk kaufen“ ist kein Geburtstag).
final _yearlyRe = RegExp('\\p{L}*(?:${yearlyWords.join('|')})(?!\\p{L})', caseSensitive: false, unicode: true);

/// Wo im Titel das Wort steht, das die Aufgabe jährlich macht – `null`, wenn keines vorkommt.
({int start, int end})? yearlyMatch(String title) {
  final m = _yearlyRe.firstMatch(title);
  return m == null ? null : (start: m.start, end: m.end);
}

/// „Peters Geburtstag“, „Hochzeitstag“ … wiederholen sich jedes Jahr.
bool isYearly(String title) => _yearlyRe.hasMatch(title);

/// Der nächste Jahrestag von [due], der nicht vor [from] liegt – auch wenn man erst Jahre
/// später abhakt, ist die neue Aufgabe nie schon überfällig.
DateTime nextYearly(DateTime due, DateTime from) {
  var d = nextYear(due);
  while (d.isBefore(sod(from))) {
    d = nextYear(d);
  }
  return d;
}

/// Derselbe Tag im nächsten Jahr (29. Februar → 28. Februar, danach bleibt es der 28.).
DateTime nextYear(DateTime d) =>
    d.month == 2 && d.day == 29 ? DateTime(d.year + 1, 2, 28) : DateTime(d.year + 1, d.month, d.day);

/// Abschnitte der Aufgabenliste in fester Reihenfolge.
enum Section { overdue, today, tomorrow, week, later, done }

/// „Erledigen am“ = Fälligkeit minus Vorlauf der Kategorie (Hausübung: Vortag).
DateTime doDate(Task t, int offset) => addDays(sod(t.dueDate), -offset);

/// Wann sich die Liste das nächste Mal von selbst ändert: um Mitternacht (neuer Tag) oder
/// vorher, sobald die Uhrzeit einer offenen Aufgabe vorbei ist (ab dann ist sie überfällig).
///
/// Dieselbe Rechnung macht das Android-Widget für sich: `WidgetData.nextChangeMillis` (Kotlin).
DateTime nextListChange(Iterable<Task> tasks, DateTime now) {
  var next = addDays(sod(now), 1);
  for (final t in tasks) {
    if (!t.done && t.hasTime && t.due.isAfter(now) && t.due.isBefore(next)) next = t.due;
  }
  return next;
}

/// Überfällig erst, wenn die Abgabe vorbei ist: nach der Uhrzeit – ohne Uhrzeit gilt der
/// ganze Abgabetag (bis 23:59). Der Vorlauf der Kategorie macht eine Aufgabe nie überfällig,
/// er holt sie nur früher in die Liste.
///
/// Dieselbe Regel steht für die Android-Widgets in `WidgetData.isLate` (Kotlin) – beide
/// Stellen gemeinsam ändern.
bool isLate(Task t, {DateTime? now}) {
  if (t.done) return false;
  final n = now ?? clock();
  final deadline = t.hasTime ? t.due : addDays(sod(t.dueDate), 1);
  return t.hasTime ? deadline.isBefore(n) : !deadline.isAfter(n);
}

/// In welchem Abschnitt der Liste die Aufgabe steht. [offset] = Vorlauf ihrer Kategorie in Tagen.
Section sectionOf(Task t, int offset, {DateTime? now}) {
  if (t.done) return Section.done;
  final n = now ?? clock();
  if (isLate(t, now: n)) return Section.overdue;
  final d = dayDiff(doDate(t, offset), n);
  // Erledigen-Tag heute oder schon vorbei, Abgabe aber noch offen: gehört zu „Heute“.
  if (d <= 0) return Section.today;
  if (d == 1) return Section.tomorrow;
  if (d <= 6 - wdIndex(n)) return Section.week;
  return Section.later;
}

/// Ob eine Aufgabe in diesem Abschnitt in der Liste steht – laut „In Aufgaben zeigen“ ihrer
/// Kategorie. Überfällige und erledigte zählen wie „Heute“: Die sieht man, außer bei „Nie“.
bool shownInList(ListFrom from, Section s) {
  if (from == ListFrom.never) return false;
  final last = switch (from) {
    ListFrom.always || ListFrom.never => Section.later,
    ListFrom.week => Section.week,
    ListFrom.tomorrow => Section.tomorrow,
    ListFrom.today => Section.today,
  };
  return s == Section.done || s.index <= last.index;
}

/// Sortierung nach Erledigen-Tag, dann nach Fälligkeit.
int byDo(Task a, Task b, int Function(Task) offsetOf) {
  final c = doDate(a, offsetOf(a)).compareTo(doDate(b, offsetOf(b)));
  return c != 0 ? c : a.due.compareTo(b.due);
}

/// Offene vor erledigten; `null` = beide gleich (dann weiter sortieren).
int? doneLast(Task a, Task b) => a.done == b.done ? null : (a.done ? 1 : -1);

/// Filter der Aufgabenliste: alle Kategorien …
const filterAll = 'alle';

/// … oder nur die Gewohnheiten (alles andere ist die ID einer Kategorie).
const filterHabits = 'habits';

/// Filtert nach Kategorie ([filterAll] oder eine ID), „Erledigte ausblenden“ und Suchtext
/// (auch in Notiz und Unteraufgaben).
List<Task> filterTasks(Iterable<Task> tasks, {required String filter, required bool hideDone, String? search}) {
  final q = (search ?? '').trim().toLowerCase();
  return [
    for (final t in tasks)
      if ((filter == filterAll || t.categoryId == filter) &&
          !(hideDone && t.done) &&
          (q.isEmpty || '${t.title} ${t.notes} ${t.subs.map((s) => s.title).join(' ')}'.toLowerCase().contains(q)))
        t,
  ];
}

/// Vorschlag für die Kategorie einer neuen Aufgabe: die, die zuletzt am häufigsten benutzt
/// wurde. Gezählt werden die [recent] zuletzt angelegten Aufgaben – so passt sich der
/// Vorschlag an, wenn sich die Gewohnheit ändert. Bei Gleichstand gewinnt die zuletzt
/// benutzte; ohne Aufgaben die erste Kategorie.
String? suggestCategory(Iterable<Task> tasks, List<String> categoryIds, {int recent = 20}) {
  if (categoryIds.isEmpty) return null;
  final latest = tasks.where((t) => categoryIds.contains(t.categoryId)).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final count = <String, int>{};
  for (final t in latest.take(recent)) {
    count[t.categoryId] = (count[t.categoryId] ?? 0) + 1;
  }
  // Die Map merkt sich die Reihenfolge des Einfügens: zuerst steht die zuletzt benutzte.
  var best = categoryIds.first;
  var bestCount = 0;
  count.forEach((id, n) {
    if (n > bestCount) {
      best = id;
      bestCount = n;
    }
  });
  return best;
}
