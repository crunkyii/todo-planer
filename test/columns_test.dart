import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/screens/sheets/column_sheet.dart';
import 'package:todo_liste/screens/sheets/columns_sheet.dart';
import 'package:todo_liste/screens/tasks_board.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/task_logic.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'harness.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  final now = DateTime(2026, 11, 18, 12); // Mittwoch
  Task task(String id, int inDays, {String cat = 'a', bool done = false, String notes = ''}) => Task(
    id: id,
    title: id,
    notes: notes,
    categoryId: cat,
    dueDate: DateTime(2026, 11, 18 + inDays),
    dueTime: null,
    done: done,
    doneAt: done ? nowUtc() : null,
    createdAt: nowUtc(),
    updatedAt: nowUtc(),
  );
  final all = [
    task('alt', -2),
    task('heute', 0, cat: 'b'),
    task('morgen', 1, notes: 'Für MATHE lernen'),
    task('fertig', 0, done: true),
    task('fertigAlt', -5, cat: 'c', done: true),
    task('spaeter', 30, cat: 'c'),
  ];
  List<String> ids({
    List<String> cats = const [],
    List<Section> periods = const [],
    ColumnStatus status = ColumnStatus.all,
    String query = '',
  }) => [
    for (final t in columnTasks(
      BoardColumn(
        id: 'x',
        name: 'x',
        color: '#3D9BE9',
        position: 0,
        updatedAt: nowUtc(),
        categories: cats,
        periods: [for (final p in periods) p.name],
        status: status,
        query: query,
      ),
      all,
      (_) => 0,
      now: now,
    ))
      t.id,
  ];

  test('Filter: ohne alles, mehrere Kategorien, Zeiträume, Status, Text – und zusammen', () {
    expect(ids(), ['alt', 'heute', 'morgen', 'spaeter', 'fertigAlt', 'fertig']);
    expect(ids(cats: ['b', 'c']), ['heute', 'spaeter', 'fertigAlt']);
    expect(ids(periods: [Section.overdue]), ['alt']);
    expect(ids(periods: [Section.today, Section.tomorrow]), ['heute', 'morgen', 'fertig']);
    expect(ids(status: ColumnStatus.open), ['alt', 'heute', 'morgen', 'spaeter']);
    expect(ids(status: ColumnStatus.done), ['fertigAlt', 'fertig']);
    expect(ids(query: ' mathe '), ['morgen']);
    expect(ids(cats: ['a', 'b'], periods: [Section.today], status: ColumnStatus.open), ['heute']);
    expect(ids(cats: ['gibt-es-nicht']), isEmpty);
  });

  test('Alte Datenbank (Version 8) bekommt die Tabelle; Spalten bleiben gespeichert', () async {
    final db = LocalDb(
      NativeDatabase.memory(
        setup: (raw) {
          for (final t in syncTables.where((t) => t != boardColumnsTable)) {
            final cols = t.columns.entries.map((e) => '"${e.key}" ${e.value}').join(', ');
            raw.execute(
              'CREATE TABLE "${t.name}" ($cols, "dirty" INTEGER NOT NULL DEFAULT 0, '
              'PRIMARY KEY (${t.keys.map((k) => '"$k"').join(', ')}))',
            );
          }
          raw.execute(
            'CREATE TABLE "done_archive" ("id" TEXT PRIMARY KEY, "day" TEXT, "category_id" TEXT, "due_date" TEXT)',
          );
          raw.execute('PRAGMA user_version = 8');
        },
      ),
    );
    final s = Store(db);
    await s.load();
    s.saveBoardColumn(
      null,
      name: 'Schule',
      color: '#3D9BE9',
      categories: const ['1', '2'],
      periods: const ['today'],
      status: ColumnStatus.done,
      query: 'x',
    );
    await s.flush();
    final again = Store(db);
    await again.load();
    final c = again.boardColumns.single;
    expect(
      (c.name, c.categories.join(), c.periods.join(), c.status, c.query),
      ('Schule', '12', 'today', ColumnStatus.done, 'x'),
    );
    await db.close();
  });

  test('Doppelte Kategorien zusammengeführt: die Spalte zeigt auf die verbleibende', () async {
    final s = Store(LocalDb(NativeDatabase.memory()));
    await s.load();
    for (var i = 0; i < 2; i++) {
      s.addCategory(name: 'Schule', color: '#3D9BE9', offset: 0);
    }
    s.saveBoardColumn(
      null,
      name: 'x',
      color: '#3D9BE9',
      categories: [for (final c in s.categories) c.id],
      periods: const [],
      status: ColumnStatus.all,
      query: '',
    );
    s.mergeDuplicateCategories();
    expect(s.boardColumns.single.categories, [s.categories.single.id]);
    await s.refreshPending();
    await s.flush();
    await Future<void>.delayed(Duration.zero);
    await s.db.close();
  });

  test('Kategorie gelöscht: die Spalte behält die übrigen bzw. nimmt die Nachfolgerin; Rückgängig', () async {
    final s = Store(LocalDb(NativeDatabase.memory()));
    await s.load();
    for (final n in ['A', 'B', 'C']) {
      s.addCategory(name: n, color: '#3D9BE9', offset: 0);
    }
    final [a, b, c] = s.categories;
    void column(List<String> cats) => s.saveBoardColumn(
      null,
      name: 'x',
      color: '#3D9BE9',
      categories: cats,
      periods: const [],
      status: ColumnStatus.all,
      query: '',
    );
    column([c.id]);
    column([b.id, c.id]);
    List<List<String>> now() => [for (final k in s.boardColumns) k.categories];
    final r = s.deleteCategory(c)!;
    expect(now(), [
      [a.id],
      [b.id],
    ]);
    r.undo();
    expect(now(), [
      [c.id],
      [b.id, c.id],
    ]);
    await s.refreshPending();
    await s.flush();
    await Future<void>.delayed(Duration.zero);
    await s.db.close();
  });

  testWidgets('Am Handy: „Nur erledigte“ trotz ausgeblendeter; Spalte auch, wenn die Liste sonst leer ist', (
    tester,
  ) async {
    final l = l10n('de');
    useFixedClock();
    final app = await makeServices();
    app.store.addCategory(name: 'Nie', color: '#3D9BE9', offset: 0, listFrom: ListFrom.never);
    final t = app.store.addTask(
      title: 'Versteckt',
      categoryId: app.store.categories.first.id,
      dueDate: today(),
      dueTime: null,
      subs: const [],
    );
    app.store.saveBoardColumn(
      null,
      name: 'Meine',
      color: '#3D9BE9',
      categories: const [],
      periods: const [],
      status: ColumnStatus.open,
      query: '',
    );
    await pumpApp(tester, app);
    expect(find.text('Versteckt'), findsOneWidget);
    expect(find.text(l.noTasks), findsNothing);

    app.store.saveBoardColumn(
      app.store.boardColumns.single,
      name: 'Fertig',
      color: '#3D9BE9',
      categories: const [],
      periods: const [],
      status: ColumnStatus.done,
      query: '',
    );
    app.store.toggleTask(t);
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
    await _tap(tester, find.text(l.hideCompleted));
    expect(find.bySemanticsLabel(l.sectionCount('Fertig', 1)), findsOneWidget);
    await finishApp(tester, app);
  });

  for (final size in [const Size(1920, 1009), const Size(320, 700)]) {
    testWidgets('Anlegen, bearbeiten, ausblenden, löschen (${size.width.toInt()} breit)', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app, size: size);
      await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
      await _tap(tester, find.text(l.columns));
      await _tap(tester, find.text(l.addColumn));
      Finder inSheet(Finder f) => find.descendant(of: find.byType(ColumnSheet), matching: f);

      // Ohne Namen geht es nicht.
      await _tap(tester, inSheet(find.text(l.save)));
      expect(find.text(l.errName), findsOneWidget);
      await tester.enterText(inSheet(find.byType(EditableText)).first, 'Schule');
      final [c1, c2, ...] = app.store.categories;
      for (final label in [c1.name, c2.name]) {
        await _tap(tester, inSheet(find.widgetWithText(AppChip, label)));
      }
      await _tap(tester, inSheet(find.text(l.save)));
      expect(tester.takeException(), isNull);
      final c = app.store.boardColumns.single;
      expect((c.name, c.status), ('Schule', ColumnStatus.all));
      expect(
        [c.categories, c.periods],
        [
          [c1.id, c2.id],
          isEmpty,
        ],
      );

      // Gilt sofort, zusätzlich zu den anderen Listen, und lässt sich verschieben.
      expect(app.settings.boardColumnOrder().last, c.listId);
      app.settings.moveBoardColumn(c.listId, Section.overdue.name);
      await tester.pumpAndSettle();
      expect(app.settings.boardColumnOrder().first, c.listId);
      final wide = size.width > 1000;
      TaskGroup group() =>
          tester.widget<TasksBoard>(find.byType(TasksBoard)).groups.firstWhere((g) => g.id == c.listId);
      if (wide) {
        expect(group().items.map((t) => t.categoryId).toSet(), {c1.id, c2.id});
      } else {
        final n = columnTasks(c, app.store.tasksWithOlder, (t) => app.store.catOf(t.categoryId).offset).length;
        expect(find.bySemanticsLabel(l.sectionCount('Schule', n), skipOffstage: false), findsOneWidget);
      }

      Future<void> openColumns() async {
        await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
        await _tap(tester, find.text(l.columns));
      }

      // Bearbeiten: Filter dazu; „Alle“ setzt die Kategorien zurück.
      await openColumns();
      await _tap(tester, find.bySemanticsLabel(l.editNamed('Schule')));
      await _tap(tester, inSheet(find.widgetWithText(AppChip, l.all)).first);
      await _tap(tester, inSheet(find.widgetWithText(AppChip, l.today)));
      await choose(tester, inSheet(selectRow(l.columnStatus)), l.columnOnlyOpen);
      await _tap(tester, inSheet(find.text(l.save)));
      expect(c.status, ColumnStatus.open);
      expect(
        [c.categories, c.periods],
        [
          isEmpty,
          [Section.today.name],
        ],
      );
      if (wide) {
        expect(group().items, isNotEmpty);
        expect(group().items.every((t) => !t.done), isTrue);
      }

      // Ausblenden gilt nur hier, die Spalte bleibt.
      await openColumns();
      final sheetSwitch = find.byWidgetPredicate((w) => w is AppSwitch && w.label == 'Schule');
      await _tap(tester, sheetSwitch);
      expect(app.settings.boardHidden, {c.listId});
      await _tap(tester, sheetSwitch);
      await _tap(tester, find.text(l.close));

      await openColumns();
      await _tap(tester, find.bySemanticsLabel(l.editNamed('Schule')));
      await _tap(tester, inSheet(find.text(l.delete)));
      expect(app.store.boardColumns, isEmpty);
      expect(app.settings.boardColumnOrder(), isNot(contains(c.listId)));
      await _tap(tester, find.text(l.undo));
      expect(app.store.boardColumns.single.name, 'Schule');
      expect(find.byType(ColumnsSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });
  }
}
