import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:convert';
import 'dart:io' show Directory;
import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:cryptography/cryptography.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/data/sync_service.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';
import 'package:todo_liste/screens/shell.dart';
import 'package:todo_liste/screens/stats_tab.dart';
import 'package:todo_liste/services/export.dart';
import 'package:todo_liste/services/update_manifest.dart';
import 'package:todo_liste/services/update_platform.dart';
import 'package:todo_liste/services/updater.dart';
import 'package:todo_liste/screens/week_tab.dart';
import 'package:todo_liste/theme/app_theme.dart';
import 'package:todo_liste/theme/color_math.dart';
import 'package:todo_liste/theme/tokens.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';
import 'package:todo_liste/util/task_logic.dart';
import 'package:todo_liste/widgets/app_icon.dart';
import 'package:todo_liste/widgets/overlays.dart';
import 'package:todo_liste/widgets/pickers.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'fake_supabase.dart';
import 'harness.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  group('Aufgaben', () {
    testWidgets('In Aufgaben zeigen: späte Aufgaben der Kategorie sind ausgeblendet, Suche und Chip zeigen sie', (
      tester,
    ) async {
      final l = l10n('de');
      final app = await makeServices();
      final store = app.store;
      store.addCategory(name: 'Geburtstag', color: '#AABBCC', offset: 0, listFrom: ListFrom.week);
      final c = store.categories.last;
      for (final (title, days) in [('Bald', 0), ('Max Mustermanns Geburtstag', 20)]) {
        store.addTask(title: title, categoryId: c.id, dueDate: addDays(today(), days), dueTime: null, subs: const []);
      }
      await pumpApp(tester, app);
      expect(find.text('Bald'), findsOneWidget);
      expect(find.text('Max Mustermanns Geburtstag'), findsNothing);
      expect(find.text(l.hiddenByCategory(1)), findsOneWidget);

      // Der Chip der Kategorie zeigt alles.
      await _tap(tester, find.text(c.name).first);
      expect(find.text('Max Mustermanns Geburtstag'), findsOneWidget);
      expect(find.text(l.hiddenByCategory(1)), findsNothing);
      await _tap(tester, find.text(l.all).first);

      await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
      await _tap(tester, find.text(l.search));
      await tester.enterText(find.byType(TextField).first, 'geburtstag');
      await tester.pumpAndSettle();
      expect(find.text('Max Mustermanns Geburtstag'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Kategorie bearbeiten: Löschen, Abbrechen und Speichern passen auf ein schmales Handy', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      app.store
        ..addCategory(name: 'Termin', color: '#AABBCC', offset: 0)
        ..addCategory(name: 'Test', color: '#AABBCC', offset: 0);
      await pumpApp(tester, app, size: const Size(340, 760));
      await _tap(tester, find.bySemanticsLabel(l.settings).last);
      await _tap(tester, find.textContaining(l.categories).first);
      await _tap(tester, find.text('Termin').first);
      expect(find.text(l.save), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Kategorien: Pfeil bleibt rechts neben dem Text, auch wenn der Untertitel umbricht', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      app.store.addCategory(name: 'Geburtstage', color: '#AABBCC', offset: 0, listFrom: ListFrom.week);
      await pumpApp(tester, app, size: const Size(340, 760));
      await _tap(tester, find.bySemanticsLabel(l.settings).last);
      await _tap(tester, find.textContaining(l.categories).first);
      final title = tester.getRect(find.text('Geburtstage'));
      final subtitle = tester.getRect(find.textContaining(l.listFromWeek));
      final arrow = tester.getRect(
        find.descendant(of: find.bySemanticsLabel(RegExp('^Geburtstage, ')), matching: find.byType(AppIcon)),
      );
      expect(subtitle.height, greaterThan(20), reason: 'Untertitel soll hier umbrechen');
      expect(arrow.left, greaterThan(subtitle.right));
      expect(arrow.top, lessThan(subtitle.bottom));
      expect(arrow.top, greaterThan(title.top - 1));
      await finishApp(tester, app);
    });

    testWidgets('Notiz: Symbol öffnet das Feld, die Karte zeigt den Anfang, die Suche findet sie', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await tester.enterText(find.byType(TextField).first, 'Referat');
      await _tap(tester, find.bySemanticsLabel(l.notes));
      await tester.enterText(find.byType(TextField).last, 'Thema: Römer\nFolien bis Freitag');
      await _tap(tester, find.bySemanticsLabel(l.add));

      final t = app.store.tasks.single;
      expect(t.notes, 'Thema: Römer\nFolien bis Freitag');
      expect(find.text('Thema: Römer\nFolien bis Freitag'), findsOneWidget);
      // Der Screenreader liest die Notiz mit vor.
      expect(
        find.bySemanticsLabel(RegExp('^Referat, .*, ${l.notes}: Thema: Römer\nFolien bis Freitag\$')),
        findsOneWidget,
      );

      // Beim Bearbeiten ist das Feld gleich offen und enthält die Notiz.
      await _tap(tester, find.text('Referat'));
      expect(find.widgetWithText(TextField, 'Thema: Römer\nFolien bis Freitag'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '');
      await _tap(tester, find.bySemanticsLabel(l.save));
      expect(app.store.tasks.single.notes, '');

      app.store.updateTask(
        app.store.tasks.single,
        title: 'Referat',
        categoryId: t.categoryId,
        dueDate: t.dueDate,
        dueTime: null,
        subs: [],
        notes: 'Römer',
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
      await _tap(tester, find.text(l.search));
      await tester.enterText(find.byType(TextField).first, 'römer');
      await tester.pumpAndSettle();
      expect(find.text('Referat'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Nur Leerzeichen ist kein Titel; Sonderzeichen und Emoji bleiben erhalten', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await tester.enterText(find.byType(TextField).first, '    ');
      await _tap(tester, find.bySemanticsLabel(l.add));
      expect(find.text(l.errTaskTitle), findsOneWidget);
      expect(app.store.tasks, isEmpty);

      const title = '<b>Ü & "x"</b> \'ß\' 🎉👨‍👩‍👧';
      await tester.enterText(find.byType(TextField).first, '  $title  ');
      await _tap(tester, find.bySemanticsLabel(l.add));
      expect(app.store.tasks.single.title, title);
      expect(find.text(title), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Sehr langer Titel und 250 Aufgaben: kein Überlauf, Liste scrollt', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      final c = app.store.categories.first.id;
      for (var i = 0; i < 250; i++) {
        app.store.addTask(
          title: 'Aufgabe $i ${'lang ' * (i % 40)}',
          categoryId: c,
          dueDate: addDays(today(), i % 20),
          dueTime: null,
          subs: const [],
        );
      }
      await pumpApp(tester, app, size: const Size(320, 640));
      await tester.fling(find.byType(Scrollable).first, const Offset(0, -3000), 5000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(Scrollable).first, const Offset(0, -3000), 5000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Menü: Suchen, Erledigte ausblenden, Erledigte löschen und Rückgängig', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      final before = app.store.tasks.length;
      final done = app.store.tasks.where((t) => t.done).length;
      expect(done, greaterThan(0));

      await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
      await _tap(tester, find.text(l.search));
      await tester.enterText(find.byType(TextField).first, 'zahn');
      await tester.pumpAndSettle();
      expect(find.text('Zahnarzt'), findsOneWidget);
      expect(find.text('Müll rausbringen'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'gibtsnicht');
      await tester.pumpAndSettle();
      expect(find.text(l.nothingFound), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel(l.closeSearch));
      expect(find.text('Müll rausbringen'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
      await _tap(tester, find.text(l.deleteCompleted));
      expect(app.store.tasks.length, before - done);
      expect(find.text(l.completedDeleted(done)), findsOneWidget);
      await _tap(tester, find.text(l.undo));
      expect(app.store.tasks.length, before);
      await finishApp(tester, app);
    });

    testWidgets('Sortieren nach Name und nach Kategorie', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      for (final mode in [l.sortByName, l.sortByCategory, l.sortByDate]) {
        await _tap(tester, find.bySemanticsLabel(l.moreOptions).first);
        await _tap(tester, find.text(l.sort));
        await _tap(tester, find.text(mode).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: mode);
        await tester.scrollUntilVisible(find.text('Englisch-Test'), 200, scrollable: find.byType(Scrollable).last);
        expect(find.text('Englisch-Test'), findsOneWidget, reason: mode);
      }
      await finishApp(tester, app);
    });

    testWidgets('Filter-Chip zeigt nur die Kategorie; Gewohnheiten-Filter zeigt nur Gewohnheiten', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);

      await _tap(tester, find.text(l.catHomework).first);
      expect(find.text('Mathe S. 42 Nr. 3–7'), findsOneWidget);
      expect(find.text('Müll rausbringen'), findsNothing);

      await _tap(tester, find.text(l.all).first);
      expect(find.text('Müll rausbringen'), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('Kategorien', () {
    testWidgets('Kategorie mit Aufgaben löschen verschiebt sie; Rückgängig stellt alles wieder her', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      final cat = app.store.categories.firstWhere((c) => c.name == l.catTest);
      final n = app.store.tasks.where((t) => t.categoryId == cat.id).length;
      expect(n, greaterThan(0));

      await _tap(tester, find.bySemanticsLabel(l.settings));
      await _tap(tester, find.text(l.categories).last);
      await _tap(tester, find.text(l.catTest));
      await _tap(tester, find.text(l.delete));
      expect(app.store.categories.any((c) => c.id == cat.id), isFalse);
      expect(app.store.tasks.where((t) => t.categoryId == cat.id), isEmpty);
      await _tap(tester, find.text(l.undo));
      expect(app.store.tasks.where((t) => t.categoryId == cat.id), hasLength(n));
      await finishApp(tester, app);
    });

    testWidgets('Doppelter Name wird abgelehnt', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.settings));
      await _tap(tester, find.text(l.categories).last);
      await _tap(tester, find.bySemanticsLabel(l.newCategory).last);
      await tester.enterText(find.byType(TextField).first, ' ${l.catTest.toUpperCase()} ');
      await _tap(tester, find.text(l.save).last);
      expect(find.text(l.errCategoryExists), findsOneWidget);
      expect(app.store.categories, hasLength(4));
      await finishApp(tester, app);
    });
  });

  group('Formular offen, während der Abgleich Daten ändert', () {
    // Dieselbe Zeile, wie sie ein anderes Gerät eine Minute später hochgeladen hätte.
    Map<String, Object?> newer(Map<String, Object?> json, Map<String, Object?> change) => {
      ...json,
      ...change,
      'updated_at': DateTime.parse(json['updated_at'] as String).add(const Duration(minutes: 1)).toIso8601String(),
    };

    testWidgets('Am anderen Gerät abgehakt: Speichern behält Haken und erledigte Unteraufgabe', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      final t = app.store.tasks.firstWhere((t) => t.title == 'Referat Geschichte');
      final open = t.subs.firstWhere((s) => !s.done);
      await _tap(tester, find.text('Referat Geschichte'));
      expect(find.bySemanticsLabel(l.save), findsOneWidget);

      await tester.runAsync(() async {
        await app.store.applyRemote(tasksTable, [
          newer(t.toJson(), {'done': true, 'done_at': nowUtc().toIso8601String()}),
        ]);
        await app.store.applyRemote(subtasksTable, [
          newer(open.toJson(), {'done': true}),
        ]);
      });
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Referat neu');
      await _tap(tester, find.bySemanticsLabel(l.save));
      final saved = app.store.taskById(t.id)!;
      expect(saved.title, 'Referat neu');
      expect(saved.done, isTrue);
      expect(saved.subs, hasLength(2));
      expect(saved.subs.every((s) => s.done), isTrue);
      await finishApp(tester, app);
    });

    testWidgets('Am anderen Gerät kommt eine Unteraufgabe dazu: Speichern behält sie', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      final t = app.store.tasks.firstWhere((t) => t.title == 'Referat Geschichte');
      await _tap(tester, find.text('Referat Geschichte'));

      final added = Subtask(
        id: 'vom-anderen-geraet',
        taskId: t.id,
        title: 'Handout drucken',
        done: true,
        position: 2,
        updatedAt: nowUtc(),
      );
      await tester.runAsync(() => app.store.applyRemote(subtasksTable, [added.toJson()]));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Referat neu');
      await _tap(tester, find.bySemanticsLabel(l.save));
      final saved = app.store.taskById(t.id)!;
      expect(saved.subs.map((s) => s.title), ['Quellen suchen', 'Folien bauen', 'Handout drucken']);
      expect(saved.subs.last.done, isTrue);
      await finishApp(tester, app);
    });

    testWidgets('Gewohnheit am anderen Gerät gelöscht: Speichern legt sie nicht wieder an', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      final h = app.store.habits.firstWhere((h) => h.name == 'Lesen');
      await _tap(tester, find.text('Lesen').first);
      expect(find.text(l.editHabit), findsWidgets);

      await tester.runAsync(
        () => app.store.applyRemote(habitsTable, [
          newer(h.toJson(), {'deleted': true}),
        ]),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.text(l.save).last);
      expect(find.text(l.itemGone), findsOneWidget);
      expect(app.store.habitById(h.id), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Am anderen Gerät gelöscht: Speichern legt die Aufgabe nicht wieder an', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      final t = app.store.tasks.firstWhere((t) => t.title == 'Zahnarzt');
      await _tap(tester, find.text('Zahnarzt'));

      await tester.runAsync(
        () => app.store.applyRemote(tasksTable, [
          newer(t.toJson(), {'deleted': true}),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Zahnarzt neu');
      await _tap(tester, find.bySemanticsLabel(l.save));
      expect(find.text(l.itemGone), findsOneWidget);
      expect(app.store.taskById(t.id), isNull);
      expect(app.store.tasks.any((x) => x.title == 'Zahnarzt neu'), isFalse);
      await finishApp(tester, app);
    });

    testWidgets('Filter auf eine Kategorie, die am anderen Gerät gelöscht wurde: Liste zeigt wieder alles', (
      tester,
    ) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      final cat = app.store.categories.firstWhere((c) => c.name == l.catHomework);
      await _tap(tester, find.text(l.catHomework).first);
      expect(find.text('Müll rausbringen'), findsNothing);

      await tester.runAsync(
        () => app.store.applyRemote(categoriesTable, [
          newer(cat.toJson(), {'deleted': true}),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Müll rausbringen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });
  });

  group('Kalender und Woche', () {
    testWidgets('Zeit-Rad rundet auf die ganze Uhrzeit: 10:50 im 30-Minuten-Raster zeigt 11:00', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme('himmel', dark: false),
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: Scaffold(
            body: TimeWheel(value: 10 * 60 + 50, step: 30, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final wheels = tester.widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView)).toList();
      int item(int i) => (wheels[i].controller! as FixedExtentScrollController).selectedItem;
      expect((item(0), item(1) * 30), (11, 0));
    });

    testWidgets('Mehr als 4 Kategorien an einem Tag: Kalender zeigt die Anzahl', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l);
      app.store.addCategory(name: 'Fünfte', color: '#E9A23D', offset: 0);
      final day = addDays(today(), 7);
      for (final c in app.store.categories) {
        app.store.addTask(title: 'T ${c.name}', categoryId: c.id, dueDate: day, dueTime: null, subs: const []);
      }
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      expect(find.text('5'), findsWidgets);
      await _tap(tester, find.text('${day.day}').first);
      expect(find.text('T Fünfte'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Wischen über dem Kalender blättert den Monat', (tester) async {
      useFixedClock(); // November 2026
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      expect(find.text('November 2026'), findsOneWidget);
      final grid = find.byType(MonthGrid);
      await tester.drag(grid, const Offset(-150, 0)); // nach links = nächster Monat
      await tester.pumpAndSettle();
      expect(find.text('Dezember 2026'), findsOneWidget);
      await tester.drag(grid, const Offset(150, 0));
      await tester.pumpAndSettle();
      await tester.drag(grid, const Offset(150, 0)); // nach rechts = voriger Monat
      await tester.pumpAndSettle();
      expect(find.text('Oktober 2026'), findsOneWidget);
      await tester.drag(grid, const Offset(-20, 0)); // zu kurz: nichts passiert
      await tester.pumpAndSettle();
      expect(find.text('Oktober 2026'), findsOneWidget);
      await tester.fling(grid, const Offset(-60, 0), 2000); // kurz, aber schnell
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      // Senkrecht scrollen und Tag antippen gehen weiter
      await tester.drag(grid, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Wischen über dem Wochenplan blättert die Woche, in der Tagesansicht den Tag', (tester) async {
      useFixedClock(); // Mittwoch 18.11.2026, KW 47
      final l = l10n('de');
      final f = Fmt(l);
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      expect(find.text(l.weekNumber(47)), findsOneWidget);
      final plan = find.byType(WeekTab);
      Future<void> swipe(Offset by) async {
        await tester.dragFrom(tester.getCenter(plan), by);
        await tester.pumpAndSettle();
      }

      await swipe(const Offset(-150, 0)); // nach links = nächste Woche
      expect(find.text(l.weekNumber(48)), findsOneWidget);
      await swipe(const Offset(150, 0));
      await swipe(const Offset(150, 0)); // nach rechts = vorige Woche
      expect(find.text(l.weekNumber(46)), findsOneWidget);
      await swipe(const Offset(-20, 0)); // zu kurz: nichts passiert
      expect(find.text(l.weekNumber(46)), findsOneWidget);
      await swipe(const Offset(0, -120)); // senkrecht scrollt nur das Raster
      expect(find.text(l.weekNumber(46)), findsOneWidget);
      expect(find.text(l.newBlock), findsNothing, reason: 'Wischen legt keinen Block an');
      await swipe(const Offset(-150, 0));
      expect(find.text(l.weekNumber(47)), findsOneWidget);

      // Tagesansicht: Wischen wechselt den Tag, auch über die Wochengrenze
      await _tap(tester, find.bySemanticsLabel(l.showDay(f.wdLong(6)))); // Sonntag
      expect(find.text(f.day(DateTime(2026, 11, 22))), findsOneWidget);
      await swipe(const Offset(-150, 0));
      expect(find.text(f.day(DateTime(2026, 11, 23))), findsOneWidget);
      expect(find.textContaining(l.weekNumber(48)), findsOneWidget);
      await swipe(const Offset(150, 0));
      expect(find.text(f.day(DateTime(2026, 11, 22))), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Monatswechsel über den Jahreswechsel', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      expect(find.text('November 2026'), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel(l.nextMonth));
      await _tap(tester, find.bySemanticsLabel(l.nextMonth));
      expect(find.text('Jänner 2027').evaluate().isNotEmpty || find.text('Januar 2027').evaluate().isNotEmpty, isTrue);
      for (var i = 0; i < 4; i++) {
        await _tap(tester, find.bySemanticsLabel(l.prevMonth));
      }
      expect(find.text('September 2026'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Block: „Bis“ vor „Von“ wird abgelehnt; gültiger Block erscheint', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      await tester.enterText(find.byType(TextField).first, 'Chor');
      await _tap(tester, find.text(l.save).last);
      expect(app.store.blocks.single.name, 'Chor');
      expect(app.store.blocks.single.end, greaterThan(app.store.blocks.single.start));
      await finishApp(tester, app);
    });

    testWidgets('Mausrad dreht das Zeitrad', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      await tester.enterText(find.byType(TextField).first, 'Früh');
      await _tap(tester, find.text(l.from)); // klappt das Zeitrad „Von“ auf
      final hours = find.descendant(of: find.byKey(const ValueKey('von')), matching: find.byType(ListWheelScrollView));
      int hour() =>
          (tester.widget<ListWheelScrollView>(hours.first).controller! as FixedExtentScrollController).selectedItem;
      final before = hour();
      final mouse = TestPointer(1, PointerDeviceKind.mouse)..hover(tester.getCenter(hours.first));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
      await tester.pumpAndSettle();
      expect(hour(), lessThan(before), reason: 'Rad nach oben gedreht = frühere Stunde');
      final picked = hour();
      await _tap(tester, find.text(l.save).last);
      expect(app.store.blocks.single.start ~/ 60, picked, reason: 'die gedrehte Stunde wird gespeichert');
      await finishApp(tester, app);
    });

    testWidgets('Darstellung „System“ folgt dem Gerät', (tester) async {
      final app = await makeServices(mode: 'system');
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, app);
      expect(Theme.of(tester.element(find.byType(AppShell))).brightness, Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(AppShell))).brightness, Brightness.light);
      await finishApp(tester, app);
    });

    testWidgets('Woche über zwei Monate und alle Raster', (tester) async {
      final l = l10n('de');
      useFixedClock(DateTime(2026, 11, 30, 9));
      for (final raster in [5, 15, 30]) {
        final app = await makeServices();
        app.settings.update((s) => s.raster = raster);
        seedDemo(app.store, l);
        await pumpApp(tester, app, size: const Size(320, 640));
        await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
        expect(find.text(l.weekNumber(49)), findsOneWidget);
        expect(find.textContaining('Dez'), findsWidgets);
        await _tap(tester, find.bySemanticsLabel(l.nextWeek));
        await _tap(tester, find.bySemanticsLabel(l.prevWeek));
        expect(tester.takeException(), isNull);
        await finishApp(tester, app);
      }
    });
  });

  group('Statistik', () {
    testWidgets('Balken sind sichtbar und Zeitraum lässt sich umschalten', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.statistics));
      final bars = find.byKey(const ValueKey('bar-segment'));
      expect(bars, findsWidgets);
      for (final e in bars.evaluate()) {
        final size = (e.renderObject! as RenderBox).size;
        expect(size.width, greaterThan(8), reason: 'Balken müssen eine Breite haben');
        expect(size.height, greaterThan(1));
      }
      await _tap(tester, find.text(l.daysRange(30)));
      expect(find.byKey(const ValueKey('bar-segment')), findsWidgets);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('0 und 12 Gewohnheiten', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(320, 640));
      await _tap(tester, find.bySemanticsLabel(l.statistics));
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 12; i++) {
        app.store.addHabit(name: 'Gewohnheit Nummer $i mit langem Namen', color: '#3D9BE9');
      }
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(l.navTasks));
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });
  });

  group('Optionen', () {
    testWidgets('Sprachwechsel wirkt sofort; eigene Einträge bleiben unverändert', (tester) async {
      final de = l10n('de'), en = l10n('en');
      final app = await makeServices();
      seedDemo(app.store, de);
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(de.settings));
      await _tap(tester, find.text(de.langEn));
      expect(find.text(en.appearance), findsOneWidget);
      expect(find.text(de.appearance), findsNothing);
      expect(find.text(en.navTasks), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel(en.navTasks));
      expect(find.text(en.habits), findsWidgets);
      expect(find.text(de.habits), findsNothing);
      expect(
        find.text(en.overdue.toUpperCase(), findRichText: true).evaluate().isNotEmpty ||
            find.textContaining(en.overdue.toUpperCase()).evaluate().isNotEmpty,
        isTrue,
      );
      // Die Kategorie wurde auf Deutsch angelegt und ist jetzt ein eigener Eintrag.
      expect(find.text(de.catHomework), findsWidgets);
      await finishApp(tester, app);
    });

    testWidgets('Alle 10 Themes in hell und dunkel, jeder Tab', (tester) async {
      final l = l10n('de');
      useFixedClock();
      for (final theme in appThemes.map((t) => t.id)) {
        for (final mode in ['light', 'dark']) {
          final app = await makeServices(theme: theme, mode: mode);
          seedDemo(app.store, l);
          await pumpApp(tester, app);
          for (final tab in [l.navCalendar, l.weeklyPlan, l.statistics, l.settings]) {
            await _tap(tester, find.bySemanticsLabel(tab));
            expect(tester.takeException(), isNull, reason: '$theme/$mode/$tab');
          }
          await finishApp(tester, app);
        }
      }
    });

    testWidgets('Auswahl-Menü: passt auf den Bildschirm, scrollt innen; Wischen daneben scrollt die Seite', (
      tester,
    ) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(412, 600));
      await _tap(tester, find.bySemanticsLabel(l.settings));
      final pageList = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text(l.dayEnds), 100, scrollable: pageList);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('22:00'));
      expect(tester.takeException(), isNull);

      // Menü bleibt im Bild, auch wenn nicht alle neun Zeiten Platz haben
      final menu = find.ancestor(of: find.text('16:00'), matching: find.byType(Glass)).first;
      final box = tester.getRect(menu);
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(600));

      // Im Menü scrollen und die letzte Zeit wählen
      final inner = find.descendant(of: menu, matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(find.text('24:00'), 60, scrollable: inner.first);
      await _tap(tester, find.text('24:00'));
      expect(app.settings.dayEnd, 24);

      // Neben dem Menü wischen: Menü geht zu, die Seite dahinter bewegt sich mit
      final page = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      page.jumpTo(page.maxScrollExtent);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('24:00'));
      expect(find.text('16:00'), findsOneWidget);
      final before = page.pixels;
      await tester.dragFrom(const Offset(40, 150), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(find.text('16:00'), findsNothing);
      expect(page.pixels, lessThan(before));

      // Tippen daneben schließt nur
      await tester.scrollUntilVisible(find.text(l.dayEnds), 100, scrollable: pageList);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('24:00'));
      await tester.tapAt(const Offset(30, 30));
      await tester.pumpAndSettle();
      expect(find.text('16:00'), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('Der Balken in der Leiste gleitet auch zu den Optionen und zurück', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      double left() => tester.getTopLeft(find.byType(AnimatedPositioned)).dx;
      final start = left();
      for (final label in [l.settings, l.navTasks]) {
        final from = left();
        await tester.tap(find.bySemanticsLabel(label).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        // Kurz nach dem Tippen ist er unterwegs – weder am alten noch schon am neuen Platz.
        final moving = left();
        await tester.pumpAndSettle();
        expect(moving, isNot(closeTo(from, 1)), reason: label);
        expect(moving, isNot(closeTo(left(), 1)), reason: label);
      }
      expect(left(), closeTo(start, 0.5));
      await finishApp(tester, app);
    });

    testWidgets('Raster, Tag beginnt/endet und Erinnerungen werden gespeichert', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.settings));
      await _tap(tester, find.byType(AppSwitch).first);
      expect(app.settings.remind, isFalse);
      await tester.scrollUntilVisible(find.text(l.grid), 200, scrollable: find.byType(Scrollable).first);
      await _tap(tester, find.text('30').first);
      expect(app.settings.raster, 30);
      await finishApp(tester, app);
    });

    testWidgets('Updates: neue Version wird gemeldet und nach „Installieren“ gestartet', (tester) async {
      final l = l10n('de');
      final installer = utf8.encode('Installer');
      final launched = <String>[];
      final updater = (await tester.runAsync(() async {
        final key = await Ed25519().newKeyPair();
        final hash = await Sha256().hash(installer);
        final sig = await Ed25519().sign(signedMessage('1.1.0', hash.bytes), keyPair: key);
        final manifest = jsonEncode({
          'version': '1.1.0',
          'url': '${releaseDownloadBase}v1.1.0/todo-planer-1.1.0-setup.exe',
          'signature': base64Encode(sig.bytes),
        });
        return Updater(
          currentVersion: '1.0.0',
          supported: true,
          publicKey: base64Encode((await key.extractPublicKey()).bytes),
          client: MockClient(
            (req) async =>
                req.url == latestManifestUrl ? http.Response(manifest, 200) : http.Response.bytes(installer, 200),
          ),
          platform: WindowsUpdate(launch: (path) async => launched.add(path)),
        );
      }))!;
      final app = await makeServices(updater: updater);
      await tester.runAsync(updater.check);
      await pumpApp(tester, app);
      // Die Meldung kommt einmal beim Start …
      expect(find.text(l.updateAvailable('1.1.0')), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel(l.settings));
      await tester.scrollUntilVisible(find.text(l.updates), 300, scrollable: find.byType(Scrollable).first);
      // … und in den Optionen steht sie mit dem Knopf zum Installieren.
      expect(find.text(l.updateInstall), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text(l.updateInstall));
        while (updater.busy && launched.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      expect(launched.single, endsWith('todo-planer-1.1.0-setup.exe'));
      expect(find.text(l.updateInstalling), findsOneWidget);
      expect(find.text(l.updateInstall), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('Updates: Zeile zeigt die Version und fehlt, wo sich die App nicht selbst aktualisiert', (
      tester,
    ) async {
      final l = l10n('de');
      for (final supported in [true, false]) {
        final updater = Updater(
          currentVersion: '1.0.0',
          supported: supported,
          client: MockClient((_) async => http.Response('', 404)),
        );
        final app = await makeServices(updater: updater);
        await pumpApp(tester, app);
        await _tap(tester, find.bySemanticsLabel(l.settings));
        await tester.scrollUntilVisible(find.text(l.exportData), 300, scrollable: find.byType(Scrollable).first);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.text(l.updates), supported ? findsOneWidget : findsNothing);
        if (supported) {
          expect(find.text(l.updateVersion('1.0.0')), findsOneWidget);
          // Antippen sucht; ohne Netz steht danach der Hinweis zum Wiederholen da.
          await tester.runAsync(() async {
            await tester.tap(find.text(l.updates));
            while (updater.state != UpdateState.failed) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          });
          await tester.pump();
          expect(find.text(l.updateFailed), findsOneWidget);
        }
        await finishApp(tester, app);
      }
    });

    testWidgets('Updates am Handy: Zeile nur in der veröffentlichten App, nicht in der Test-Kopie', (tester) async {
      final l = l10n('de');
      const channel = MethodChannel('todo_liste/update');
      final messenger = tester.binding.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      for (final package in [releaseAppId, '$releaseAppId.debug']) {
        final release = package == releaseAppId;
        final dir = Directory.systemTemp.createTempSync('updater-ui-');
        addTearDown(() => dir.deleteSync(recursive: true));
        var installerOpened = 0;
        // Steht für AppUpdate.kt; im Installer bricht der Nutzer ab.
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'install') installerOpened++;
          return switch (call.method) {
            'info' => {'package': package, 'cert': releaseCertSha256},
            'dir' => dir.path,
            'canInstall' => true,
            _ => false,
          };
        });
        final apk = utf8.encode('APK');
        final updater = (await tester.runAsync(() async {
          final key = await Ed25519().newKeyPair();
          Future<String> sign(List<int> bytes, {bool android = false}) async {
            final message = signedMessage('1.1.0', (await Sha256().hash(bytes)).bytes, android: android);
            return base64Encode((await Ed25519().sign(message, keyPair: key)).bytes);
          }

          final manifest = jsonEncode({
            'version': '1.1.0',
            'url': '${releaseDownloadBase}v1.1.0/todo-planer-1.1.0-setup.exe',
            'signature': await sign(utf8.encode('Installer')),
            'android': {
              'url': '${releaseDownloadBase}v1.1.0/todo-planer-1.1.0.apk',
              'signature': await sign(apk, android: true),
            },
          });
          final device = await Updater.forAndroid('1.0.0', const AndroidUpdate());
          return Updater(
            currentVersion: device.currentVersion,
            supported: device.supported,
            platform: const AndroidUpdate(),
            publicKey: base64Encode((await key.extractPublicKey()).bytes),
            client: MockClient(
              (req) async =>
                  req.url == latestManifestUrl ? http.Response(manifest, 200) : http.Response.bytes(apk, 200),
            ),
          );
        }))!;
        final app = await makeServices(updater: updater);
        await tester.runAsync(updater.check);
        await pumpApp(tester, app);
        expect(find.text(l.updateAvailable('1.1.0')), release ? findsOneWidget : findsNothing);
        await _tap(tester, find.bySemanticsLabel(l.settings));
        await tester.scrollUntilVisible(find.text(l.exportData), 300, scrollable: find.byType(Scrollable).first);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.text(l.updates), release ? findsOneWidget : findsNothing);
        expect(find.text(l.updateInstall), release ? findsOneWidget : findsNothing);
        if (release) {
          await tester.runAsync(() async {
            await tester.tap(find.text(l.updateInstall));
            while (installerOpened == 0 || updater.busy) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          });
          await tester.pump();
          // Abgebrochen: keine Fehlermeldung, der Knopf ist wieder da.
          expect(find.text(l.updateFailed), findsNothing);
          expect(find.text(l.updateInstall), findsOneWidget);
        }
        await finishApp(tester, app);
      }
    });
  });

  group('Darstellung und Barrierefreiheit', () {
    for (final scale in [1.3, 2.0]) {
      for (final size in const [Size(320, 640), Size(412, 915), Size(915, 412), Size(800, 1280), Size(1600, 900)]) {
        testWidgets('Schrift ${scale}x bei ${size.width.toInt()}×${size.height.toInt()}: kein Überlauf', (
          tester,
        ) async {
          useFixedClock();
          for (final lang in ['de', 'en']) {
            final l = l10n(lang);
            final app = await makeServices(lang: lang);
            seedDemo(app.store, l);
            await pumpApp(tester, app, size: size, textScale: scale);
            for (final tab in [l.navCalendar, l.weeklyPlan, l.statistics, l.settings, l.navTasks]) {
              await _tap(tester, find.bySemanticsLabel(tab));
              expect(tester.takeException(), isNull, reason: '$lang/$tab');
            }
            await _tap(tester, find.bySemanticsLabel(l.newTask).last);
            expect(tester.takeException(), isNull, reason: '$lang/Sheet');
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            await finishApp(tester, app);
          }
        });
      }
    }

    testWidgets('Tastatur-Fokus wird dem Screenreader gemeldet', (tester) async {
      final handle = tester.ensureSemantics();
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l10n('de'));
      await pumpApp(tester, app);
      bool anyFocused() => tester.semantics.simulatedAccessibilityTraversal().any(
        (n) => n.flagsCollection.isButton && n.flagsCollection.isFocused == Tristate.isTrue,
      );
      expect(anyFocused(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(anyFocused(), isTrue, reason: 'der fokussierte Knopf muss „fokussiert“ melden');
      handle.dispose();
      await finishApp(tester, app);
    });

    testWidgets('Alle Tippflächen sind beschriftet', (tester) async {
      final handle = tester.ensureSemantics();
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      for (final tab in [null, l.navCalendar, l.weeklyPlan, l.statistics, l.settings]) {
        if (tab != null) await _tap(tester, find.bySemanticsLabel(tab));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: tab);
      }
      handle.dispose();
      await finishApp(tester, app);
    });

    test('Textkontrast ist in jedem Theme lesbar (WCAG AA, gerechnet)', () {
      for (final th in appThemes) {
        for (final dark in [false, true]) {
          final t = AppTokens.build(th, dark: dark);
          final pairs = {
            'Text auf Hintergrund': (t.text, t.bg),
            'Text auf Karte': (t.text, t.card),
            'Nebentext auf Hintergrund': (t.sub, t.bg),
            'Nebentext auf Karte': (t.sub, t.card),
            'Schrift auf Primärfarbe': (t.onP, t.p),
            'Schrift auf Primär-Container': (t.onPc, t.pc),
            'Primärfarbe auf Hintergrund': (t.p, t.bg),
          };
          pairs.forEach((name, c) {
            expect(
              contrast(c.$1, c.$2),
              greaterThanOrEqualTo(4.5),
              reason: '${th.id}/${dark ? 'dunkel' : 'hell'}: $name',
            );
          });
          for (final preset in ColorPreset.values) {
            final ic = t.item(preset.hex);
            expect(
              contrast(ic.ci, ic.ct),
              greaterThanOrEqualTo(4.5),
              reason: '${th.id}: ${preset.name} Text auf Tönung',
            );
            expect(
              contrast(ic.cs, ic.c),
              // Wie im Prototyp: Weiße Symbole auf hellen Farben liegen bei 2,7–3:1 (bekannter Punkt).
              greaterThanOrEqualTo(2.7),
              reason: '${th.id}: ${preset.name} Schrift auf Farbe',
            );
          }
        }
      }
    });

    testWidgets('„Animationen reduzieren“: App funktioniert ohne Bewegung', (tester) async {
      final l = l10n('de');
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      for (final tab in [l.navCalendar, l.weeklyPlan, l.statistics, l.settings, l.navTasks]) {
        await _tap(tester, find.bySemanticsLabel(tab));
        expect(tester.takeException(), isNull);
      }
      await finishApp(tester, app);
    });

    testWidgets('Textfelder erlauben Wortvorschläge der Tastatur; Passwort, E-Mail und Schlüssel nicht', (
      tester,
    ) async {
      final l = l10n('de');
      useFixedClock();
      var app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      final title = tester.widget<TextField>(find.byType(TextField).first);
      expect(title.autocorrect, isTrue);
      expect(title.enableSuggestions, isTrue);
      expect(title.textCapitalization, TextCapitalization.sentences);
      expect(title.keyboardType, TextInputType.text);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await finishApp(tester, app);

      app = await makeServices(syncMode: 'cloud', cloudConfig: true);
      await pumpApp(tester, app);
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].textCapitalization, TextCapitalization.none, reason: 'E-Mail');
      expect(fields[1].obscureText, isTrue);
      expect(fields[1].enableSuggestions, isFalse, reason: 'Passwort');
      expect(fields[1].autocorrect, isFalse);
      await finishApp(tester, app);
    });

    testWidgets('Neue Aufgabe schlägt die meistbenutzte Kategorie vor', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l);
      final termin = app.store.categories.firstWhere((c) => c.name == l.catAppointment);
      for (var i = 0; i < 12; i++) {
        app.store.addTask(title: 'Termin $i', categoryId: termin.id, dueDate: today(), dueTime: null, subs: const []);
      }
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      expect(find.bySemanticsLabel(l.categoryLabel(termin.name)), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await finishApp(tester, app);
    });

    testWidgets('Geburtstag: Hinweis beim Tippen, „Jährlich“ auf der Karte, Abhaken legt nächstes Jahr an', (
      tester,
    ) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await tester.enterText(find.byType(TextField).first, 'Einkaufen');
      await tester.pump();
      expect(find.text(l.yearlyHint), findsNothing);
      await tester.enterText(find.byType(TextField).first, "Max Mustermann's Geburtstag");
      await tester.pump();
      expect(find.text(l.yearlyHint), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(l.yearly), findsOneWidget);
      final t = app.store.tasks.single;
      await _tap(tester, find.bySemanticsLabel(l.a11yDone(t.title)));
      expect(find.text(l.doneYearly), findsOneWidget);
      expect(app.store.tasks, hasLength(2));
      expect(app.store.tasks.firstWhere((x) => !x.done).dueDate, nextYear(t.dueDate));
      await finishApp(tester, app);
    });

    testWidgets('Kalender zeigt den Feiertag des gewählten Tags', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      await pumpApp(tester, app);
      await goTab(tester, l.navCalendar);
      expect(find.textContaining(l.hAllSaints), findsNothing);
      await _tap(tester, find.bySemanticsLabel(RegExp(l.hAllSaints)));
      expect(find.text(l.holidayLine(l.hAllSaints)), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Export: Auswahl in den Einstellungen speichert die Datei im gewählten Format', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l);
      final saved = <(String, int, String)>[];
      final real = saveExportFile;
      saveExportFile = (name, bytes, mime) async {
        saved.add((name, bytes.length, mime));
        return true;
      };
      addTearDown(() => saveExportFile = real);
      await pumpApp(tester, app);
      await goTab(tester, l.navSettings);
      await tester.scrollUntilVisible(find.text(l.exportData), 200, scrollable: find.byType(Scrollable).last);
      await _tap(tester, find.text(l.exportData));
      expect(find.text(l.exportCsvSub), findsOneWidget);
      await _tap(tester, find.text('CSV'));
      expect(saved.single.$1, 'todo-liste-2026-11-18.csv');
      expect(saved.single.$2, greaterThan(100));
      expect(saved.single.$3, 'text/csv');
      expect(find.text(l.exportSaved), findsOneWidget);
      expect(find.text(l.exportCsvSub), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('Tippen neben ein Textfeld nimmt Fokus und Tastatur weg – in jedem Formular', (tester) async {
      final l = l10n('de');
      useFixedClock();
      bool editing() =>
          tester.binding.focusManager.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>() != null;
      Future<void> type(String text, {int field = 0}) async {
        await tester.tap(find.byType(TextField).at(field));
        await tester.enterText(find.byType(TextField).at(field), text);
        await tester.pumpAndSettle();
        expect(editing(), isTrue, reason: 'Feld ist beim Tippen ausgewählt');
      }

      Future<void> closeSheet() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }

      var app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);

      // Block (der gemeldete Fall): Name eingeben, dann „Bis“ antippen
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      await type('Schule');
      await _tap(tester, find.text(l.to));
      expect(editing(), isFalse, reason: 'Block: „Bis“ angetippt');
      expect(find.byKey(const ValueKey('bis')), findsOneWidget, reason: 'das Zeitrad geht trotzdem auf');
      await closeSheet();

      // Aufgabe: Titel, dann eine Kategorie antippen
      await _tap(tester, find.bySemanticsLabel(l.navTasks));
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await type('Titel');
      await _tap(tester, find.bySemanticsLabel(l.dateAndTime)); // Kalender-Knopf im Sheet
      expect(editing(), isFalse, reason: 'Aufgabe: Datum & Uhrzeit angetippt');
      await _tap(tester, find.bySemanticsLabel(l.dateAndTime)); // wieder zuklappen

      // Unteraufgaben: „+ Unteraufgabe“ gehört zum Tippen – das neue Feld ist gleich ausgewählt
      await _tap(tester, find.bySemanticsLabel(l.subtasks));
      await type('Eins', field: 1);
      await tester.ensureVisible(find.text(l.subtask).last);
      await _tap(tester, find.text(l.subtask).last);
      expect(editing(), isTrue, reason: 'nach „+ Unteraufgabe“ wird weitergetippt');
      expect(find.byType(TextField), findsNWidgets(3));
      await closeSheet();

      // Gewohnheit
      await _tap(tester, find.text(l.habit));
      await type('Lesen');
      await _tap(tester, find.text(l.color));
      expect(editing(), isFalse, reason: 'Gewohnheit: daneben getippt');
      await closeSheet();

      // Suche: Treffer antippen bzw. Liste anfassen
      await _tap(tester, find.bySemanticsLabel(l.moreOptions));
      await _tap(tester, find.text(l.search));
      await type('Müll');
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();
      expect(editing(), isFalse, reason: 'Suche: daneben getippt');
      await closeSheet();
      await _tap(tester, find.bySemanticsLabel(l.closeSearch));

      // Kategorie
      await _tap(tester, find.bySemanticsLabel(l.settings));
      await _tap(tester, find.text(l.categories).last);
      await _tap(tester, find.bySemanticsLabel(l.newCategory).last);
      await type('Referat');
      await _tap(tester, find.text(l.color));
      expect(editing(), isFalse, reason: 'Kategorie: daneben getippt');
      await finishApp(tester, app);

      // Anmeldung
      app = await makeServices(syncMode: 'cloud', cloudConfig: true);
      await pumpApp(tester, app);
      await type('ich@beispiel.at');
      await _tap(tester, find.text(l.signIn).first); // Überschrift
      expect(editing(), isFalse, reason: 'Anmeldung: daneben getippt');
      await finishApp(tester, app);

      // Einrichtung
      app = await makeServices(syncMode: null);
      await pumpApp(tester, app);
      await _tap(tester, find.text(l.setupCloudTitle));
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await type('https://abcdefgh.supabase.co');
      await _tap(tester, find.text(l.publishableKey).first); // Beschriftung des anderen Felds
      expect(editing(), isFalse, reason: 'Einrichtung: daneben getippt');
      await finishApp(tester, app);
    });

    testWidgets('Tastatur: Esc schließt das Sheet, Enter speichert', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      expect(find.bySemanticsLabel(l.add), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(l.add), findsNothing);

      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await tester.enterText(find.byType(TextField).first, 'Per Enter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.store.tasks.single.title, 'Per Enter');
      await finishApp(tester, app);
    });

    testWidgets('Tastatur verdeckt das Eingabefeld nicht', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(320, 640));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      final field = tester.getRect(find.byType(TextField).first);
      expect(field.bottom, lessThanOrEqualTo(640 - 300), reason: 'Feld muss über der Tastatur liegen');
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Android-Zurück schließt erst das Sheet', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(l.add), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('Anmeldung und Einrichtung', () {
    testWidgets('Anmeldung prüft E-Mail und Passwort', (tester) async {
      for (final lang in ['de', 'en']) {
        final l = l10n(lang);
        final app = await makeServices(lang: lang, syncMode: 'cloud', cloudConfig: true);
        await pumpApp(tester, app);
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'keine-mail');
        await _tap(tester, find.text(l.signIn).last);
        expect(find.text(l.errEmail), findsOneWidget);
        await tester.enterText(fields.at(0), 'ich@beispiel.at');
        await _tap(tester, find.text(l.signIn).last);
        expect(find.text(l.errPassword), findsOneWidget);
        // Zu langes Passwort: nur beim Registrieren gemeldet (höchstens 72 Zeichen), nicht beim Anmelden
        await tester.enterText(fields.at(1), 'a' * 73);
        await _tap(tester, find.text(l.signIn).last);
        expect(find.text(l.errPasswordLong), findsNothing);
        await _tap(tester, find.text(l.signUp));
        await tester.enterText(fields.at(0), 'ich@beispiel.at');
        await tester.enterText(fields.at(1), 'a' * 73);
        await _tap(tester, find.text(l.signUp));
        expect(find.text(l.errPasswordLong), findsOneWidget);
        expect(l.errPasswordLong, contains('72'));
        await tester.enterText(fields.at(1), 'ä' * 37); // 74 Bytes
        await _tap(tester, find.text(l.signUp));
        expect(find.text(l.errPasswordLong), findsOneWidget);
        await finishApp(tester, app);
      }
    });

    testWidgets('Meldung am Anmelde-Bildschirm hat normale Schrift (nicht gelb unterstrichen)', (tester) async {
      final l = l10n('de');
      final app = await makeServices(syncMode: 'cloud', cloudConfig: true);
      await pumpApp(tester, app);
      app.snack.show(l.confirmEmailHint);
      await tester.pumpAndSettle();
      final style = DefaultTextStyle.of(tester.element(find.text(l.confirmEmailHint))).style;
      expect(style.decoration, isNot(TextDecoration.underline));
      expect(style.fontFamily, isNot('monospace'));
      await finishApp(tester, app);
    });

    testWidgets('Einrichtung lehnt falsche URL, falschen Key und den Secret Key ab', (tester) async {
      for (final lang in ['de', 'en']) {
        final l = l10n(lang);
        final app = await makeServices(lang: lang, syncMode: null);
        await pumpApp(tester, app);
        await _tap(tester, find.text(l.setupCloudTitle));
        final fields = find.byType(TextField);
        Future<void> submit(String url, String key) async {
          await tester.ensureVisible(fields.at(0));
          await tester.enterText(fields.at(0), url);
          await tester.enterText(fields.at(1), key);
          await tester.ensureVisible(find.text(l.connect).last);
          await _tap(tester, find.text(l.connect).last);
        }

        await submit('http://abc.supabase.co', 'sb_publishable_abcdefghijkl');
        expect(find.text(l.errUrl), findsOneWidget);
        await submit('https://abcdefgh.supabase.co', 'irgendwas');
        expect(find.text(l.errKeyFormat), findsOneWidget);
        await submit('https://abcdefgh.supabase.co', 'sb_secret_abcdefghijklmnop');
        expect(find.text(l.errSecretKey), findsOneWidget);
        expect(app.settings.cloud, isNull, reason: 'nichts davon darf gespeichert werden');
        await finishApp(tester, app);
      }
    });
  });

  group('Breites Fenster (PC)', () {
    for (final size in const [Size(1920, 1009), Size(1366, 705), Size(900, 700)]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}: Navigation links, alle Tabs ohne Überlauf', (
        tester,
      ) async {
        final l = l10n('de');
        final app = await makeServices();
        seedDemo(app.store, l);
        await pumpApp(tester, app, size: size);
        // Die Navigation steht links neben dem Inhalt, nicht mehr unten.
        final nav = tester.getRect(find.bySemanticsLabel(l.navCalendar));
        expect(nav.right, lessThan(Sizes.sideNavW + 2 * Sizes.navGap));
        expect(nav.top, lessThan(size.height / 2));
        for (final tab in [l.navCalendar, l.weeklyPlan, l.statistics, l.settings, l.navTasks]) {
          await _tap(tester, find.bySemanticsLabel(tab));
          expect(tester.takeException(), isNull, reason: tab);
        }
        await finishApp(tester, app);
      });
    }

    testWidgets('„Neue Aufgabe“ links öffnet das Formular in der Mitte und speichert', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      const size = Size(1366, 705);
      await pumpApp(tester, app, size: size);
      await _tap(tester, find.bySemanticsLabel(l.newTask));
      final field = find.byType(EditableText).first;
      // Als Fenster in der Mitte – nicht am unteren Rand wie am Handy.
      expect(tester.getRect(field).center.dx, closeTo(size.width / 2, 40));
      expect(tester.getRect(field).bottom, lessThan(size.height * 0.75));
      await tester.enterText(field, 'Am PC angelegt');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.store.tasks.map((t) => t.title), contains('Am PC angelegt'));
      expect(find.text('Am PC angelegt'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Kalender: Monat links, Aufgaben des Tages rechts daneben', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      app.store.addTask(
        title: 'Heute fällig',
        categoryId: app.store.categories.first.id,
        dueDate: today(),
        dueTime: null,
        subs: const [],
      );
      await pumpApp(tester, app, size: const Size(1366, 705));
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      final grid = tester.getRect(find.byType(MonthGrid));
      final task = tester.getRect(find.text('Heute fällig'));
      expect(task.left, greaterThan(grid.right - 1));
      expect(task.top, lessThan(grid.bottom));
      // Knapp über der Umschalt-Breite wäre der Monat zu eng: Dann steht der Tag wieder darunter.
      tester.view.physicalSize = const Size(920, 705);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Heute fällig')).top, greaterThan(tester.getRect(find.byType(MonthGrid)).bottom));
      await finishApp(tester, app);
    });

    testWidgets('Klick auf einen Tab links: die Schrift bleibt an ihrem Platz', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(1366, 705));
      final label = find.text(l.statistics).first;
      final before = tester.getCenter(label);
      final press = await tester.startGesture(before, kind: PointerDeviceKind.mouse);
      // Während Schimmer und Feder laufen, darf sie höchstens leicht mitfedern – nicht springen.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect((tester.getCenter(label) - before).distance, lessThan(1.5), reason: 'gedrückt, Bild $i');
      }
      await press.up();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect((tester.getCenter(label) - before).distance, lessThan(1.5), reason: 'losgelassen, Bild $i');
      }
      await tester.pumpAndSettle();
      await finishApp(tester, app);
    });

    testWidgets('Handy im Querformat bleibt beim Handy-Layout', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(915, 412));
      expect(tester.getRect(find.bySemanticsLabel(l.navCalendar).last).top, greaterThan(412 / 2));
      await finishApp(tester, app);
    });

    testWidgets('In den Optionen fehlt der „Neu“-Knopf, die Tabs bleiben an ihrem Platz', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(1366, 705));
      final before = tester.getRect(find.bySemanticsLabel(l.navCalendar));
      await _tap(tester, find.bySemanticsLabel(l.settings));
      expect(find.bySemanticsLabel(l.newTask), findsNothing);
      expect(tester.getRect(find.bySemanticsLabel(l.navCalendar)), before);
      await finishApp(tester, app);
    });

    testWidgets('Fenster schmaler ziehen: Navigation wandert nach unten, der Tab bleibt', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app, size: const Size(1366, 705));
      await _tap(tester, find.bySemanticsLabel(l.statistics));
      tester.view.physicalSize = const Size(600, 705);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.bySemanticsLabel(l.navCalendar)).top, greaterThan(705 / 2));
      expect(find.byType(StatsTab), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('Offline', () {
    testWidgets('Toast beim Offline-Gehen, „Am Gerät gespeichert“, Toast bei wieder online', (tester) async {
      final l = l10n('de');
      final conn = FakeConnectivity();
      final cloud = FakeCloud('http://localhost:1');
      final app = await makeServices(
        syncMode: 'cloud',
        cloudConfig: true,
        cloud: cloud,
        sync: (store, settings, c) => SyncService(store: store, settings: settings, cloud: c, connectivity: conn),
      );
      await app.sync.start();
      app.sync.active = true;
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      expect(find.byType(AppShell), findsOneWidget);

      conn.set(false);
      await tester.pumpAndSettle();
      expect(find.text(l.offlineToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await tester.enterText(find.byType(TextField).first, 'Offline angelegt');
      await _tap(tester, find.bySemanticsLabel(l.add));
      expect(find.textContaining(l.savedOnDevice), findsOneWidget);
      expect(find.text('Offline angelegt'), findsOneWidget);
      expect(find.byTooltip(l.pendingSyncHint), findsWidgets);

      await tester.pump(const Duration(seconds: 6));
      conn.set(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('online'), findsOneWidget);
      await finishApp(tester, app);
    });
    testWidgets('Ältere erledigte Aufgaben: online ein Knopf zum Nachladen, offline ein Hinweis', (tester) async {
      final l = l10n('de');
      final conn = FakeConnectivity();
      final app = await makeServices(
        syncMode: 'cloud',
        cloudConfig: true,
        cloud: FakeCloud('http://localhost:1'),
        sync: (store, settings, c) => SyncService(store: store, settings: settings, cloud: c, connectivity: conn),
      );
      await app.sync.start();
      seedDemo(app.store, l);
      // Wie beim Abruf vom Server: eine vor zehn Tagen abgehakte Aufgabe, die nicht am Gerät liegt.
      final at = nowUtc().subtract(const Duration(days: 10));
      final old = Task(
        id: newId(),
        title: 'Lange her',
        categoryId: app.store.categories.first.id,
        dueDate: today(),
        dueTime: null,
        done: true,
        doneAt: at,
        createdAt: at,
        updatedAt: at,
      );
      await tester.runAsync(() => app.store.applyRemote(tasksTable, [old.toJson()]));
      await pumpApp(tester, app);

      expect(find.text('Lange her'), findsNothing);
      // „Erledigt“ ist zugeklappt: Der Knopf steht erst da, wenn man den Abschnitt aufmacht.
      expect(find.text(l.olderDoneLoad(1)), findsNothing);
      final head = find.bySemanticsLabel(l.sectionCount(l.done, app.store.tasks.where((t) => t.done).length));
      await tester.scrollUntilVisible(head, 300, scrollable: find.byType(Scrollable).last);
      await _tap(tester, head);
      await tester.scrollUntilVisible(find.text(l.olderDoneLoad(1)), 300, scrollable: find.byType(Scrollable).last);
      expect(find.bySemanticsLabel(l.olderDoneLoad(1)), findsOneWidget);

      conn.set(false);
      await tester.pumpAndSettle();
      expect(find.text(l.olderDoneOffline(1)), findsOneWidget);
      expect(find.text(l.olderDoneLoad(1)), findsNothing);

      // Im Kalender steht der Hinweis beim Abgabetag.
      await tester.pump(const Duration(seconds: 6));
      await goTab(tester, l.navCalendar);
      await tester.scrollUntilVisible(find.text(l.olderDoneOffline(1)), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text(l.olderDoneOffline(1)), findsOneWidget);
      await finishApp(tester, app);
    });
  });
}
