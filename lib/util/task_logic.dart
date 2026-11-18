import '../data/models.dart';
import 'dates.dart';

/// Abschnitte der Aufgabenliste in fester Reihenfolge.
enum Section { overdue, today, tomorrow, week, later, done }

/// „Erledigen am“ = Fälligkeit minus Vorlauf der Kategorie (Hausübung: Vortag).
DateTime doDate(Task t, int offset) => addDays(sod(t.dueDate), -offset);

/// Überfällig: Erledigen-Tag vorbei oder Uhrzeit heute schon vorbei.
bool isLate(Task t, int offset, {DateTime? now}) {
  if (t.done) return false;
  final n = now ?? clock();
  return doDate(t, offset).isBefore(sod(n)) || (t.hasTime && t.due.isBefore(n));
}

Section sectionOf(Task t, int offset, {DateTime? now}) {
  if (t.done) return Section.done;
  final n = now ?? clock();
  if (isLate(t, offset, now: n)) return Section.overdue;
  final d = dayDiff(doDate(t, offset), n);
  if (d == 0) return Section.today;
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
