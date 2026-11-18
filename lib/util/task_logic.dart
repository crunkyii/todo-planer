import '../data/models.dart';
import 'dates.dart';

/// Abschnitte der Aufgabenliste in fester Reihenfolge.
enum Section { overdue, today, tomorrow, week, later, done }

/// „Erledigen am“ = Fälligkeit minus Vorlauf der Kategorie (Hausübung: Vortag).
DateTime doDate(Task t, int offset) => addDays(sod(t.dueDate), -offset);

/// Überfällig erst, wenn die Abgabe vorbei ist: nach der Uhrzeit – ohne Uhrzeit gilt der
/// ganze Abgabetag (bis 23:59). Der Vorlauf der Kategorie macht eine Aufgabe nie überfällig,
/// er holt sie nur früher in die Liste.
bool isLate(Task t, int offset, {DateTime? now}) {
  if (t.done) return false;
  final n = now ?? clock();
  final deadline = t.hasTime ? t.due : addDays(sod(t.dueDate), 1);
  return t.hasTime ? deadline.isBefore(n) : !deadline.isAfter(n);
}

Section sectionOf(Task t, int offset, {DateTime? now}) {
  if (t.done) return Section.done;
  final n = now ?? clock();
  if (isLate(t, offset, now: n)) return Section.overdue;
  final d = dayDiff(doDate(t, offset), n);
  // Erledigen-Tag heute oder schon vorbei, Abgabe aber noch offen: gehört zu „Heute“.
  if (d <= 0) return Section.today;
  if (d == 1) return Section.tomorrow;
  if (d <= 6 - wdIndex(n)) return Section.week;
  return Section.later;
}

/// Sortierung nach Erledigen-Tag, dann nach Fälligkeit.
int byDo(Task a, Task b, int Function(Task) offsetOf) {
  final c = doDate(a, offsetOf(a)).compareTo(doDate(b, offsetOf(b)));
  return c != 0 ? c : a.due.compareTo(b.due);
}

/// Offene vor erledigten; `null` = beide gleich (dann weiter sortieren).
int? doneLast(Task a, Task b) => a.done == b.done ? null : (a.done ? 1 : -1);

/// Filter aus dem Prototyp: Kategorie, „Erledigte ausblenden“ und Suchtext (auch in Unteraufgaben).
List<Task> filterTasks(Iterable<Task> tasks, {required String filter, required bool hideDone, String? search}) {
  final q = (search ?? '').trim().toLowerCase();
  return [
    for (final t in tasks)
      if ((filter == 'alle' || t.categoryId == filter) &&
          !(hideDone && t.done) &&
          (q.isEmpty || '${t.title} ${t.subs.map((s) => s.title).join(' ')}'.toLowerCase().contains(q)))
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
