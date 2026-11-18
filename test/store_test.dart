import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/util/dates.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Store store;

  setUp(() async {
    store = Store(LocalDb(NativeDatabase.memory()));
    await store.load();
    store.ensureDefaultCategories([
      (name: 'Hausübung', color: '#3D9BE9', offset: 1),
      (name: 'Aufgabe', color: '#34C38F', offset: 0),
    ]);
  });

  tearDown(() async {
    await store.refreshPending();
    await store.db.close();
  });

  Task add(String title, {List<({String title, bool done})> subs = const []}) =>
      store.addTask(title: title, categoryId: store.categories.first.id, dueDate: today(), dueTime: null, subs: subs);

  test('Standard-Kategorien nur einmal', () {
    store.ensureDefaultCategories([(name: 'X', color: '#000000', offset: 0)]);
    expect(store.categories.map((c) => c.name), ['Hausübung', 'Aufgabe']);
  });

  test('Aufgabe anlegen, abhaken und wieder laden', () async {
    final t = add('Mathe', subs: [(title: 'Seite 12', done: false)]);
    store.toggleTask(t);
    await store.refreshPending();
    expect(store.pending, greaterThan(0));

    final again = Store(store.db);
    await again.load();
    final loaded = again.taskById(t.id)!;
    expect(loaded.title, 'Mathe');
    expect(loaded.done, isTrue);
    expect(loaded.subs.single.title, 'Seite 12');
  });

  test('Unteraufgaben bearbeiten verwendet vorhandene wieder', () {
    final t = add('Referat', subs: [(title: 'A', done: false), (title: 'B', done: true)]);
    final firstId = t.subs.first.id;
    store.updateTask(t, title: 'Referat', categoryId: t.categoryId, dueDate: t.dueDate, dueTime: 9 * 60, subs: [(title: 'A2', done: false)]);
    expect(t.subs.single.id, firstId);
    expect(t.subs.single.title, 'A2');
    expect(t.dueTime, 540);
  });

  test('Löschen mit Rückgängig, auch für Unteraufgaben', () {
    final t = add('Weg damit', subs: [(title: 'x', done: false)]);
    final undo = store.deleteTask(t);
    expect(store.tasks, isEmpty);
    undo();
    expect(store.tasks.single.subs.single.title, 'x');
  });

  test('Erledigte löschen behält die Statistik', () {
    final a = add('a');
    add('b');
    store.toggleTask(a);
    final r = store.clearDone()!;
    expect(r.count, 1);
    expect(store.tasks.map((t) => t.title), ['b']);
    expect(store.doneEntries(), hasLength(1));
    r.undo();
    expect(store.tasks, hasLength(2));
    expect(store.clearDone(), isNotNull);
    expect(store.clearDone(), isNull);
  });

  test('Kategorie löschen verschiebt Aufgaben, letzte bleibt', () {
    final cats = store.categories;
    final t = store.addTask(title: 't', categoryId: cats.last.id, dueDate: today(), dueTime: null, subs: const []);
    final r = store.deleteCategory(cats.last)!;
    expect(r.moved, 1);
    expect(t.categoryId, cats.first.id);
    expect(store.deleteCategory(store.categories.single), isNull);
    r.undo();
    expect(t.categoryId, cats.last.id);
  });

  test('Gleichnamige Kategorien werden zusammengeführt', () {
    // Wie nach dem ersten Abgleich zweier Geräte: „Hausübung“ gibt es doppelt.
    store.addCategory(name: 'hausübung ', color: '#000000', offset: 0);
    final dup = store.categories.firstWhere((c) => c.name == 'hausübung ');
    final t = store.addTask(title: 't', categoryId: dup.id, dueDate: today(), dueTime: null, subs: const []);
    final keep = [dup, store.categories.first]..sort((a, b) => a.id.compareTo(b.id));

    store.mergeDuplicateCategories();
    expect(store.categories, hasLength(2));
    expect(store.categories.where((c) => c.id == keep.first.id), hasLength(1));
    expect(t.categoryId, keep.first.id);
  });

  test('Gewohnheiten: alle abhaken und Serie', () {
    store.addHabit(name: 'Wasser', color: '#3D9BE9');
    store.addHabit(name: 'Lesen', color: '#F5B83D');
    expect(store.toggleAllHabitsToday(), isTrue);
    final k = isoDate(today());
    expect(store.habits.every((h) => store.habitDone(h.id, k)), isTrue);
    expect(store.habitStreak(store.habits.first.id), 1);
    expect(store.toggleAllHabitsToday(), isFalse);
    expect(store.habitDone(store.habits.first.id, k), isFalse);
  });

  test('Wochenblöcke: wiederholt oder nur diese Woche', () {
    final ws = monday(DateTime.now());
    store.addBlocks(name: 'Schule', color: '#3D9BE9', days: [0, 1], start: 480, end: 780, repeat: true, weekStart: ws);
    store.addBlocks(name: 'Ausflug', color: '#F07A5F', days: [0], start: 900, end: 960, repeat: false, weekStart: ws);
    expect(store.blocksFor(0, ws).map((b) => b.name), ['Schule', 'Ausflug']);
    expect(store.blocksFor(0, addDays(ws, 7)).map((b) => b.name), ['Schule']);
  });

  test('Server-Änderung: neuerer Stand gewinnt', () async {
    final t = add('lokal');
    await store.refreshPending();
    final older = {...t.toJson(), 'title': 'alt', 'updated_at': t.updatedAt.subtract(const Duration(minutes: 1)).toIso8601String()};
    await store.applyRemote(tasksTable, [older]);
    expect(store.taskById(t.id)!.title, 'lokal');
    final newer = {...t.toJson(), 'title': 'vom Handy', 'updated_at': t.updatedAt.add(const Duration(minutes: 1)).toIso8601String()};
    await store.applyRemote(tasksTable, [newer]);
    expect(store.taskById(t.id)!.title, 'vom Handy');
  });

  test('Warteschlange: markClean nur bei unverändertem Stand', () async {
    final t = add('sync');
    await store.refreshPending();
    final rows = await store.db.dirtyRows(tasksTable);
    expect(rows.map((r) => r['id']), contains(t.id));
    await store.db.markClean(tasksTable, rows.firstWhere((r) => r['id'] == t.id));
    expect((await store.db.dirtyRows(tasksTable)).where((r) => r['id'] == t.id), isEmpty);
  });
}
