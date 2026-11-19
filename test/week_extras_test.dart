import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/screens/sheets/block_view_sheet.dart';
import 'package:todo_liste/theme/tokens.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';
import 'package:todo_liste/util/week_layout.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'harness.dart';

WeekBlock _block(int start, int end) => WeekBlock(
  id: 'b',
  name: 'Lernen',
  color: '#AABBCC',
  day: 2,
  start: start,
  end: end,
  repeat: true,
  weekStart: null,
  updatedAt: fixedNow.toUtc(),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  group('„+“ bei Aufgaben an diesem Tag', () {
    testWidgets('Seite mit späteren Aufgaben: nach Datum, Filter nach Kategorie, gewählte werden Chips', (
      tester,
    ) async {
      final l = l10n('de');
      useFixedClock(); // Mittwoch, 18.11.2026
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      final store = app.store;
      final test = store.categories.firstWhere((c) => c.name == l.catTest);
      final homework = store.categories.firstWhere((c) => c.name == l.catHomework);
      store.addTask(
        title: 'Buch Referat',
        categoryId: test.id,
        dueDate: addDays(today(), 9),
        dueTime: 8 * 60,
        subs: [],
      );
      store.addTask(title: 'Mathe HÜ', categoryId: homework.id, dueDate: addDays(today(), 5), dueTime: null, subs: []);
      store.addTask(title: 'Gestern', categoryId: homework.id, dueDate: addDays(today(), -1), dueTime: null, subs: []);
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.weeklyPlan));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l.newBlock).last);
      await tester.pumpAndSettle();
      // Heute ist nichts dran – die Zeile steht trotzdem da, mit dem „+“.
      expect(find.text(l.tasksThatDay), findsOneWidget);
      expect(find.byType(AppChip), findsNothing);
      await tester.tap(find.bySemanticsLabel(l.addTasksToDay));
      await tester.pumpAndSettle();

      // Nach Datum sortiert, Vergangenes fehlt.
      expect(find.text(l.pickTasksTitle), findsOneWidget);
      final y1 = tester.getTopLeft(find.text('Mathe HÜ')).dy, y2 = tester.getTopLeft(find.text('Buch Referat')).dy;
      expect(y1, lessThan(y2));
      expect(find.text('Gestern'), findsNothing);
      // Filter nach Kategorie.
      await tester.tap(find.widgetWithText(AppChip, test.name));
      await tester.pumpAndSettle();
      expect(find.text('Mathe HÜ'), findsNothing);
      await tester.tap(find.text('Buch Referat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.applyCount(1)));
      await tester.pumpAndSettle();

      // Zurück im Blatt: als Chip dabei und gleich ausgewählt.
      final chip = find.widgetWithText(
        AppChip,
        'Buch Referat · ${l.infoHandIn(Fmt.of(tester.element(find.byType(AppChip))).wd(4))}',
      );
      expect(chip, findsOneWidget);
      expect(tester.widget<AppChip>(chip).selected, isTrue);
      await tester.tap(find.text(l.save).last);
      await tester.pumpAndSettle();
      final b = store.blocks.single;
      expect((b.name, b.repeat, b.color), ('Buch Referat', false, test.color));
      // Die Aufgabe selbst bleibt, wie sie war (nicht am Abgabetag).
      expect(store.tasks.firstWhere((t) => t.title == 'Buch Referat').dueTime, 8 * 60);
      await finishApp(tester, app);
    });
  });

  group('Block ziehen', () {
    test('dragTarget: ganze Raster-Schritte, auf das Raster gelegt, im sichtbaren Tag', () {
      final b = _block(600, 660); // 10:00–11:00
      expect(dragTarget(b, 5, 15, 6, 22), 600, reason: 'weniger als ein halber Schritt: bleibt');
      expect(dragTarget(b, 10, 15, 6, 22), 615);
      expect(dragTarget(b, -65, 15, 6, 22), 540);
      expect(dragTarget(b, 50, 30, 6, 22), 660, reason: 'Raster 30: 10:00 → 11:00');
      expect(dragTarget(b, -1000, 15, 6, 22), 360, reason: 'nicht vor „Tag beginnt“');
      expect(dragTarget(b, 1000, 15, 6, 22), 21 * 60, reason: 'Ende höchstens bei „Tag endet“');
      // Ein 10:15-Block landet bei Raster 30 auf dem Raster.
      expect(dragTarget(_block(615, 675), 30, 30, 6, 22), 660);
    });

    testWidgets('Lange drücken und nach unten ziehen: anderer Beginn, gleiche Dauer, Rückgängig geht', (tester) async {
      final l = l10n('de');
      useFixedClock(); // Mittwoch, 18.11.2026, 10:30
      final app = await makeServices();
      app.store.addBlocks(
        name: 'Lernen',
        color: '#AABBCC',
        days: [2],
        start: 9 * 60,
        end: 10 * 60,
        repeat: true,
        weekStart: monday(today()),
      );
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.weeklyPlan));
      await tester.pumpAndSettle();
      final block = find.text('Lernen').first;
      final g = await tester.startGesture(tester.getCenter(block), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 700));
      // Raster 15 Minuten: 1,5 Stunden nach unten.
      for (var i = 0; i < 6; i++) {
        await g.moveBy(Offset(0, Sizes.hour / 4));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      final b = app.store.blocks.single;
      expect((b.start, b.end, b.repeat), (10 * 60 + 30, 11 * 60 + 30, true));
      expect(find.text(l.blockMoved('10:30')), findsOneWidget);
      await tester.tap(find.text(l.undo).last);
      await tester.pumpAndSettle();
      expect((app.store.blocks.single.start, app.store.blocks.single.end), (9 * 60, 10 * 60));

      // Kurz antippen öffnet weiter den Block – erst die Ansicht.
      await tester.tap(find.text('Lernen').first);
      await tester.pumpAndSettle();
      expect(find.byType(BlockViewSheet), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('Ansicht eines Blocks', () {
    testWidgets('zeigt Zeit und die Aufgabe dazu; ⋮ → Bearbeiten und Löschen', (tester) async {
      final l = l10n('de');
      useFixedClock(); // Mittwoch, 18.11.2026
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      final t = app.store.addTask(
        title: 'Referat Max Mustermann',
        notes: 'Folien mitnehmen',
        categoryId: app.store.categories.first.id,
        dueDate: addDays(today(), 2),
        dueTime: null,
        subs: [(title: 'Gliederung', done: true), (title: 'Folien', done: false)],
      );
      app.store.addBlocks(
        name: 'Referat lernen',
        color: '#AABBCC',
        days: [2],
        start: 13 * 60 + 10,
        end: 14 * 60 + 50,
        repeat: true,
        weekStart: monday(today()),
        taskId: t.id,
      );
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.weeklyPlan));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Referat lernen').first);
      await tester.pumpAndSettle();

      // Nicht gleich bearbeiten: kein Formular, keine Tastatur.
      expect(find.byType(BlockViewSheet), findsOneWidget);
      expect(find.text(l.editBlock), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      final f = Fmt(l);
      Finder inView(Finder x) => find.descendant(of: find.byType(BlockViewSheet), matching: x);
      expect(inView(find.text(f.wdLong(2))), findsOneWidget);
      expect(inView(find.textContaining('13:10')), findsOneWidget);
      expect(inView(find.text(l.everyWeek)), findsOneWidget);
      // Die Aufgabe mit Unteraufgaben und Notiz, ohne sie heraussuchen zu müssen.
      expect(inView(find.text('Referat Max Mustermann')), findsOneWidget);
      expect(inView(find.text('Folien')), findsOneWidget);
      expect(inView(find.text('Folien mitnehmen')), findsOneWidget);

      // ⋮ → Bearbeiten öffnet das Formular.
      await tester.tap(inView(find.bySemanticsLabel(l.moreOptions)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.edit));
      await tester.pumpAndSettle();
      expect(find.byType(BlockViewSheet), findsNothing);
      expect(find.text(l.editBlock), findsOneWidget);
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();

      // ⋮ → Löschen, mit Rückgängig.
      await tester.tap(find.text('Referat lernen').first);
      await tester.pumpAndSettle();
      await tester.tap(inView(find.bySemanticsLabel(l.moreOptions)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.delete));
      await tester.pumpAndSettle();
      expect(app.store.blocks, isEmpty);
      expect(app.store.taskById(t.id), isNotNull, reason: 'die Aufgabe bleibt');
      await tester.tap(find.text(l.undo).last);
      await tester.pumpAndSettle();
      expect(app.store.blocks.single.taskId, t.id);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Aufgabe gelöscht: die Ansicht sagt es', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      final t = app.store.addTask(
        title: 'Weg',
        categoryId: app.store.categories.first.id,
        dueDate: today(),
        dueTime: null,
        subs: [],
      );
      app.store.addBlocks(
        name: 'Block',
        color: '#AABBCC',
        days: [2],
        start: 600,
        end: 660,
        repeat: true,
        weekStart: monday(today()),
        taskId: t.id,
      );
      app.store.deleteTask(t);
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.weeklyPlan));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block').first);
      await tester.pumpAndSettle();
      expect(find.text(l.blockTaskGone), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('Hinweis „ausgeblendet“', () {
    testWidgets('kommt nur beim ersten Mal und lässt sich schließen', (tester) async {
      final l = l10n('de');
      var app = await makeServices();
      app.store.addCategory(name: 'Geburtstag', color: '#AABBCC', offset: 0, listFrom: ListFrom.week);
      final c = app.store.categories.last;
      app.store.addTask(
        title: 'Max Mustermanns Geburtstag',
        categoryId: c.id,
        dueDate: addDays(today(), 20),
        dueTime: null,
        subs: const [],
      );
      await pumpApp(tester, app);
      expect(find.text(l.hiddenByCategory(1)), findsOneWidget);
      expect(app.settings.hiddenHintSeen, isTrue, reason: 'gleich gemerkt');
      // Bleibt in diesem App-Start stehen, bis man ihn schließt.
      await tester.tap(find.text(c.name).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.all).first);
      await tester.pumpAndSettle();
      expect(find.text(l.hiddenByCategory(1)), findsOneWidget);
      await tester.ensureVisible(find.byWidgetPredicate((w) => w is IconBtn && w.label == l.closeHint));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is IconBtn && w.label == l.closeHint));
      await tester.pumpAndSettle();
      expect(find.text(l.hiddenByCategory(1)), findsNothing);
      final db = app.store.db;
      await finishApp(tester, app, closeDb: false);

      // Nach einem Neustart kommt er nicht wieder.
      app = await makeServices(keepPrefs: true, db: db);
      await pumpApp(tester, app);
      expect(find.text('Max Mustermanns Geburtstag'), findsNothing);
      expect(find.text(l.hiddenByCategory(1)), findsNothing);
      await finishApp(tester, app);
    });
  });
}
