import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/holidays.dart';
import 'package:todo_liste/util/task_logic.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('jährliche Aufgaben erkennen', () {
    test('Geburtstag, Jahrestag & Co. – auch groß/klein und mit Vorsilbe', () {
      for (final t in [
        "Max Mustermann's Geburtstag",
        'geburtstag oma',
        'Kindergeburtstag',
        'Hochzeitstag',
        'Omas 80. GEBURTSTAG!',
        'Firmenjubiläum',
        "Anna's birthday",
        'Wedding Anniversary',
      ]) {
        expect(isYearly(t), isTrue, reason: t);
        expect(isYearly(t.toUpperCase()), isTrue, reason: t);
      }
    });

    test('andere Titel und längere Wörter nicht', () {
      for (final t in ['Einkaufen', 'Geburtstagsgeschenk kaufen', 'Mathe Hausübung', '']) {
        expect(isYearly(t), isFalse, reason: t);
      }
    });

    test('Stelle des Worts für die Hervorhebung', () {
      const title = "Max Mustermann's Geburtstag feiern";
      final m = yearlyMatch(title)!;
      expect(title.substring(m.start, m.end), 'Geburtstag');
      expect(yearlyMatch('Einkaufen'), isNull);
    });

    test('nächstes Jahr, 29. Februar wird 28. Februar', () {
      expect(nextYear(DateTime(2026, 11, 18)), DateTime(2027, 11, 18));
      expect(nextYear(DateTime(2028, 2, 29)), DateTime(2029, 2, 28));
    });
  });

  group('Abhaken legt die Aufgabe fürs nächste Jahr an', () {
    late Store store;

    setUp(() async {
      clock = () => DateTime(2026, 11, 18, 10, 30);
      store = Store(LocalDb(NativeDatabase.memory()));
      await store.load();
      store.ensureDefaultCategories([(name: 'Termin', color: '#3D9BE9', offset: 0)]);
    });

    tearDown(() async {
      clock = DateTime.now;
      await store.refreshPending();
      await store.db.close();
    });

    test('Geburtstag: erledigt → neue Aufgabe in einem Jahr, wieder offen → weg', () {
      final day = DateTime(2026, 11, 18);
      final t = store.addTask(
        title: "Max Mustermann's Geburtstag",
        categoryId: store.categories.first.id,
        dueDate: day,
        dueTime: 8 * 60,
        subs: [(title: 'Geschenk', done: true)],
      );
      store.toggleTask(t);
      expect(store.tasks, hasLength(2));
      final next = store.tasks.firstWhere((x) => x.id != t.id);
      expect(next.title, t.title);
      expect(next.dueDate, DateTime(2027, 11, 18));
      expect(next.dueTime, 8 * 60);
      expect(next.done, isFalse);
      expect(next.subs.map((s) => (s.title, s.done)), [('Geschenk', false)]);

      // noch einmal an/aus: kein zweites Exemplar
      store.toggleTask(t);
      expect(store.tasks, hasLength(1));
      store.toggleTask(t);
      expect(store.tasks, hasLength(2));
    });

    test('selbst angelegte oder bearbeitete Aufgabe fürs nächste Jahr bleibt beim Wieder-Öffnen', () {
      final cat = store.categories.first.id;
      final a = store.addTask(title: 'Hochzeitstag', categoryId: cat, dueDate: today(), dueTime: null, subs: const []);
      final own = store.addTask(
        title: 'Hochzeitstag',
        categoryId: cat,
        dueDate: nextYear(today()),
        dueTime: null,
        subs: const [],
      );
      store.toggleTask(a); // es gibt sie schon: nichts Neues
      expect(store.tasks, hasLength(2));
      store.toggleTask(a); // wieder offen: die eigene bleibt
      expect(store.tasks.map((t) => t.id), contains(own.id));

      final b = store.addTask(title: 'Namenstag Eva', categoryId: cat, dueDate: today(), dueTime: null, subs: const []);
      store.toggleTask(b);
      final copy = store.tasks.firstWhere((t) => t.title == b.title && t.id != b.id);
      store.updateTask(copy, title: copy.title, categoryId: cat, dueDate: copy.dueDate, dueTime: 600, subs: const []);
      store.toggleTask(b);
      expect(store.tasks.map((t) => t.id), contains(copy.id));
    });

    test('spät abgehakt: die neue Aufgabe liegt nicht in der Vergangenheit', () {
      final t = store.addTask(
        title: 'Omas Geburtstag',
        categoryId: store.categories.first.id,
        dueDate: DateTime(2024, 11, 15),
        dueTime: null,
        subs: const [],
      );
      store.toggleTask(t);
      final next = store.tasks.firstWhere((x) => x.id != t.id);
      expect(next.dueDate, DateTime(2027, 11, 15));
      // „Erledigte löschen“ lässt die neue stehen
      expect(store.clearDone()!.count, 1);
      expect(store.tasks.single.id, next.id);
    });

    test('normale Aufgabe: nichts Neues', () {
      final t = store.addTask(
        title: 'Einkaufen',
        categoryId: store.categories.first.id,
        dueDate: today(),
        dueTime: null,
        subs: const [],
      );
      store.toggleTask(t);
      expect(store.tasks, hasLength(1));
    });
  });

  group('Feiertage in Österreich', () {
    test('Ostersonntag', () {
      expect(easterSunday(2024), DateTime(2024, 3, 31));
      expect(easterSunday(2025), DateTime(2025, 4, 20));
      expect(easterSunday(2026), DateTime(2026, 4, 5));
      expect(easterSunday(2027), DateTime(2027, 3, 28));
    });

    test('13 Feiertage, feste und bewegliche', () {
      expect(holidaysOf(2026), hasLength(13));
      expect(holidayOn(DateTime(2026, 1, 1)), Holiday.newYear);
      expect(holidayOn(DateTime(2026, 4, 6)), Holiday.easterMonday);
      expect(holidayOn(DateTime(2026, 5, 14)), Holiday.ascension);
      expect(holidayOn(DateTime(2026, 5, 25)), Holiday.whitMonday);
      expect(holidayOn(DateTime(2026, 6, 4)), Holiday.corpusChristi);
      expect(holidayOn(DateTime(2026, 10, 26)), Holiday.nationalDay);
      expect(holidayOn(DateTime(2026, 12, 8)), Holiday.immaculate);
      expect(holidayOn(DateTime(2026, 12, 26)), Holiday.stStephen);
      expect(holidayOn(DateTime(2026, 11, 18)), isNull);
      expect(holidayOn(DateTime(2025, 6, 19)), Holiday.corpusChristi);
      expect(holidayOn(DateTime(2027, 5, 6)), Holiday.ascension);
    });
  });
}
