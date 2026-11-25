import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';
import 'package:todo_liste/screens/sheets/block_view_sheet.dart';
import 'package:todo_liste/screens/sheets/remind_field.dart';
import 'package:todo_liste/services/reminders.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';
import 'package:todo_liste/widgets/select.dart';

import 'harness.dart';

Task _task(DateTime due, {int? time, int remind = 0, bool done = false, String id = 't'}) => Task(
  id: id,
  title: id,
  categoryId: 'c',
  dueDate: due,
  dueTime: time,
  remind: remind,
  done: done,
  doneAt: done ? nowUtc() : null,
  createdAt: nowUtc(),
  updatedAt: nowUtc(),
);

WeekBlock _block({int day = 2, int start = 600, int remind = 15, bool repeat = true, String? taskId, String? week}) =>
    WeekBlock(
      id: 'b',
      name: 'Schule',
      color: '#3D9BE9',
      day: day,
      start: start,
      end: start + 60,
      repeat: repeat,
      weekStart: week,
      taskId: taskId,
      remind: remind,
      updatedAt: nowUtc(),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  // Mittwoch, 18.11.2026, 9:00
  final now = DateTime(2026, 11, 18, 9);
  List<Reminder> tasks(List<Task> list) => upcomingReminders(list, (t) => '', now: now);
  List<Reminder> blocks(WeekBlock b, {bool Function(String)? done, DateTime? at}) => upcomingBlockReminders(
    (d) => wdIndex(d) == b.day && (b.repeat || b.weekStart == isoDate(monday(d))) ? [b] : const [],
    (b, day) => isoDate(day),
    taskDone: done,
    now: at ?? now,
  );

  group('Planung', () {
    test('Aufgabe: Vorlauf abgezogen, „Keine“ und schon vorbeigegangene fallen weg', () {
      final day = DateTime(2026, 11, 18);
      expect(tasks([_task(day, time: 600)]).single.at, DateTime(2026, 11, 18, 10));
      expect(tasks([_task(day, time: 600, remind: 30)]).single.at, DateTime(2026, 11, 18, 9, 30));
      expect(tasks([_task(day, time: 600, remind: 60)]), isEmpty, reason: '9:00 ist nicht mehr in der Zukunft');
      expect(tasks([_task(day, time: 600, remind: remindNone)]), isEmpty);
      expect(tasks([_task(day, remind: 30)]), isEmpty, reason: 'ohne Uhrzeit');
      expect(tasks([_task(day, time: 600, done: true)]), isEmpty);
    });

    test('Sortiert nach der Benachrichtigung, nicht nach der Fälligkeit', () {
      final day = DateTime(2026, 11, 20);
      final list = tasks([_task(day, time: 600, id: 'spät'), _task(day, time: 660, remind: 24 * 60, id: 'früh')]);
      expect([for (final r in list) r.title], ['früh', 'spät']);
    });

    test('„1 Tag vorher“ bleibt über die Zeitumstellung dieselbe Uhrzeit', () {
      final list = upcomingReminders(
        [_task(DateTime(2026, 10, 25), time: 600, remind: 24 * 60)],
        (t) => '',
        now: DateTime(2026, 10, 20),
      );
      expect(list.single.at, DateTime(2026, 10, 24, 10));
    });

    test('Wöchentlicher Block: die nächsten zwei Wochen, je mit eigener Nummer', () {
      final list = blocks(_block());
      expect([for (final r in list) r.at], [DateTime(2026, 11, 18, 9, 45), DateTime(2026, 11, 25, 9, 45)]);
      expect({for (final r in list) r.id}, hasLength(2));
      expect(blocks(_block(remind: remindNone)), isEmpty);
      // Heute schon vorbei: erst nächste Woche.
      expect(blocks(_block(), at: DateTime(2026, 11, 18, 9, 50)).first.at, DateTime(2026, 11, 25, 9, 45));
    });

    test('Einmaliger Block nur in seiner Woche; Block um Mitternacht meldet sich am Vortag', () {
      expect(blocks(_block(repeat: false, week: '2026-11-16')), hasLength(1));
      expect(blocks(_block(repeat: false, week: '2026-11-09')), isEmpty);
      final list = blocks(_block(day: 3, start: 0));
      expect((list.first.at, list.first.body), (DateTime(2026, 11, 18, 23, 45), '2026-11-19'));
    });

    test('Eine Woche Vorlauf: auch Blöcke, die selbst noch weiter weg sind', () {
      final list = blocks(_block(remind: remindMax));
      expect([for (final r in list) r.body], ['2026-11-25', '2026-12-02']);
    });

    test('Block mit erledigter Aufgabe schweigt; gleichzeitig mit der Aufgabe kommt nur eine', () {
      final b = _block(taskId: 't');
      expect(blocks(b, done: (_) => true), isEmpty);
      final own = tasks([_task(DateTime(2026, 11, 18), time: 600, remind: 15)]);
      expect(
        mergeReminders(own, blocks(b)),
        hasLength(2),
        reason: 'heute nur die der Aufgabe, nächste Woche der Block',
      );
      expect(mergeReminders(own, blocks(_block(remind: 5, taskId: 't'))), hasLength(3));
    });
  });

  group('Speichern', () {
    late Store store;
    setUp(() async {
      store = Store(LocalDb(NativeDatabase.memory()));
      await store.load();
      store.addCategory(name: 'HÜ', color: '#AABBCC', offset: 0);
    });
    tearDown(() async {
      await store.refreshPending(); // erst alles schreiben
      await store.db.close();
    });

    test('Aufgabe und Block behalten den Vorlauf nach dem Neuladen', () async {
      final t = store.addTask(
        title: 'A',
        categoryId: store.categories.single.id,
        dueDate: today(),
        dueTime: 600,
        remind: 25,
        subs: const [],
      );
      store.addBlocks(
        name: 'B',
        color: '#AABBCC',
        days: [0],
        start: 480,
        end: 540,
        repeat: true,
        weekStart: today(),
        remind: 10,
      );
      await store.refreshPending();
      final again = Store(store.db);
      await again.load();
      expect((again.taskById(t.id)!.remind, again.blocks.single.remind), (25, 10));
      // Verschieben lässt die Benachrichtigung, wie sie ist.
      final b = store.blocks.single;
      store.updateBlock(b, name: 'B', color: b.color, day: 0, start: 500, end: 560, repeat: true, weekStart: today());
      expect(b.remind, 10);
    });

    test('Ohne Angabe wie bisher: Aufgaben zum Zeitpunkt, Blöcke gar nicht', () {
      final t = _task(today()).toJson()..remove('remind_min');
      final b = _block().toJson()..remove('remind_min');
      expect((Task.fromJson(t).remind, WeekBlock.fromJson(b).remind), (0, remindNone));
      expect(Task.fromJson({...t, 'remind_min': 999999}).remind, remindMax);
      expect(Task.fromJson({...t, 'remind_min': -99}).remind, remindNone);
    });

    test('Geburtstag im nächsten Jahr: derselbe Vorlauf', () {
      final t = store.addTask(
        title: 'Geburtstag Max Mustermann',
        categoryId: store.categories.single.id,
        dueDate: today(),
        dueTime: 600,
        remind: 60,
        subs: const [],
      );
      store.toggleTask(t);
      expect(store.tasks.singleWhere((x) => x.id != t.id).remind, 60);
    });

    test('Datenbank von Version 7: Werte wie bisher', () async {
      final old = LocalDb(
        NativeDatabase.memory(
          setup: (db) {
            for (final t in syncTables) {
              final cols = t.columns.entries
                  .where((e) => e.key != 'remind_min')
                  .map((e) => '"${e.key}" ${e.value}')
                  .join(', ');
              db.execute(
                'CREATE TABLE "${t.name}" ($cols, "dirty" INTEGER NOT NULL DEFAULT 0, '
                'PRIMARY KEY (${t.keys.map((k) => '"$k"').join(', ')}))',
              );
            }
            db.execute(
              'CREATE TABLE "done_archive" ("id" TEXT NOT NULL PRIMARY KEY, "day" TEXT NOT NULL, '
              '"category_id" TEXT NOT NULL, "due_date" TEXT)',
            );
            db.execute(
              'INSERT INTO tasks (id, title, notes, category_id, due_date, done, created_at, updated_at, deleted, dirty) '
              "VALUES ('t1', 'Alt', '', 'c1', '2026-11-18', 0, '2026-11-01T00:00:00Z', '2026-11-01T00:00:00Z', 0, 1)",
            );
            db.execute(
              'INSERT INTO week_blocks (id, name, color, day, start_min, end_min, repeat, updated_at, deleted, dirty) '
              "VALUES ('b1', 'Alt', '#AABBCC', 0, 480, 540, 1, '2026-11-01T00:00:00Z', 0, 1)",
            );
            db.execute('PRAGMA user_version = 7');
          },
        ),
      );
      final s = Store(old);
      await s.load();
      expect((s.taskById('t1')!.remind, s.blocks.single.remind), (0, remindNone));
      expect((await old.dirtyRows(tasksTable)).single['remind_min'], 0, reason: 'geht mit Wert hoch');
      expect((await old.dirtyRows(blocksTable)).single['remind_min'], remindNone);
      await old.close();
    });
  });

  group('Formulare', () {
    Finder row(AppLocalizations l) => find.bySemanticsLabel(RegExp('^${l.notification}'));

    testWidgets('Neue Aufgabe: fertige Zeit wählen', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.newTask).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'Arzt');
      await tester.tap(find.bySemanticsLabel(l.dateAndTime));
      await tester.pumpAndSettle();
      expect(find.text(l.remindNeedsTime), findsOneWidget, reason: 'noch keine Uhrzeit');
      await choose(tester, row(l), Fmt(l).remindLabel(15));
      await tester.tap(find.bySemanticsLabel(l.add));
      await tester.pumpAndSettle();
      expect(app.store.tasks.singleWhere((t) => t.title == 'Arzt').remind, 15);
      await finishApp(tester, app);
    });

    testWidgets('Aufgabe: eigene Minuten; ungültige Zahl wird nicht gespeichert', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(412, 1400));
      await tester.tap(find.bySemanticsLabel(l.newTask).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'Zug');
      await tester.tap(find.bySemanticsLabel(l.dateAndTime));
      await tester.pumpAndSettle();
      await choose(tester, row(l), l.remindCustom);
      final field = find.descendant(of: find.byType(RemindField), matching: find.byType(EditableText));
      for (final bad in ['', '0', '10081', 'zwei']) {
        await tester.enterText(field, bad);
        await tester.tap(find.bySemanticsLabel(l.add));
        await tester.pumpAndSettle();
        expect(find.text(l.errRemindMinutes), findsOneWidget, reason: '„$bad“');
        expect(app.store.tasks.where((t) => t.title == 'Zug'), isEmpty);
      }
      await tester.enterText(field, '42');
      await tester.tap(find.bySemanticsLabel(l.add));
      await tester.pumpAndSettle();
      expect(app.store.tasks.singleWhere((t) => t.title == 'Zug').remind, 42);
      await finishApp(tester, app);
    });

    testWidgets('Block: Benachrichtigung steht in der Ansicht und lässt sich auf „Keine“ stellen', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      app.store.addBlocks(
        name: 'Turnen',
        color: '#AABBCC',
        days: [2],
        start: 600,
        end: 660,
        repeat: true,
        weekStart: monday(today()),
        remind: 25,
      );
      await pumpApp(tester, app, size: const Size(412, 1400));
      await tester.tap(find.bySemanticsLabel(l.weeklyPlan));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turnen').first);
      await tester.pumpAndSettle();
      final view = find.byType(BlockViewSheet);
      expect(find.descendant(of: view, matching: find.textContaining(Fmt(l).remindLabel(25))), findsOneWidget);
      await tester.tap(find.descendant(of: view, matching: find.bySemanticsLabel(l.moreOptions)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.edit));
      await tester.pumpAndSettle();
      // Der eigene Wert (25) ist als Möglichkeit dabei.
      expect(tester.widget<SelectRow<int>>(find.byType(SelectRow<int>)).value, 25);
      await choose(tester, row(l), l.remindNone);
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(app.store.blocks.singleWhere((b) => b.name == 'Turnen').remind, remindNone);
      await finishApp(tester, app);
    });

    testWidgets('Sind Erinnerungen in den Optionen aus, steht es dabei', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      app.settings.update((s) => s.remind = false);
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.newTask).last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l.dateAndTime));
      await tester.pumpAndSettle();
      expect(find.text(l.remindOff), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  test('Texte: Minuten, Stunden, Tage in allen Sprachen', () {
    final de = Fmt(l10n('de'));
    expect(
      [
        for (final m in [remindNone, 0, 15, 90, 24 * 60, remindMax]) de.remindLabel(m),
      ],
      ['Keine', 'Zum Zeitpunkt', '15 Min. vorher', '1 Std. 30 Min. vorher', '1 Tag vorher', '1 Woche vorher'],
    );
    expect(Fmt(l10n('en')).remindLabel(15), '15 min before');
    expect(Fmt(l10n('es')).remindLabel(15), '15 min antes');
    expect(Fmt(l10n('fr')).remindLabel(15), '15 min avant');
    expect(Fmt(l10n('it')).remindLabel(15), '15 min prima');
  });
}
