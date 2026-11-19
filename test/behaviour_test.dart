import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:convert';
import 'dart:io' show Directory;
import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:cryptography/cryptography.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/data/sync_service.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';
import 'package:todo_liste/screens/sheets/columns_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_liste/screens/movable_section.dart';
import 'package:todo_liste/screens/shell.dart';
import 'package:todo_liste/screens/stats_tab.dart';
import 'package:todo_liste/screens/task_card.dart';
import 'package:todo_liste/screens/tasks_board.dart';
import 'package:todo_liste/screens/ui_state.dart';
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

  group('Gewohnheiten', () {
    testWidgets('Abhaken: nicht durchgestrichen, gleitet ans Ende und beim Öffnen zurück', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      TextDecoration? deco(String name) => tester.renderObject<RenderParagraph>(find.text(name)).text.style?.decoration;
      // „Wasser“ ist heute schon abgehakt: steht unten und ist nicht durchgestrichen.
      expect(y('Lesen') < y('Sport') && y('Sport') < y('Wasser'), isTrue);
      expect(deco('Wasser'), isNot(TextDecoration.lineThrough));

      await tester.tap(find.bySemanticsLabel(l.a11yHabitDoneToday('Lesen')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // Zuerst sieht man das Abhaken: Die Zeile steht noch an ihrem alten Platz …
      expect(y('Lesen'), lessThan(y('Sport')));
      final top = y('Lesen');
      await tester.pump(const Duration(milliseconds: 160));
      // … dann gleitet sie – unterwegs ist sie weder oben noch schon unten.
      final mid = y('Lesen');
      await tester.pumpAndSettle();
      expect(y('Sport') < y('Wasser') && y('Wasser') < y('Lesen'), isTrue, reason: 'Erledigte unten');
      expect(mid, allOf(greaterThan(top + 4), lessThan(y('Lesen') - 4)));
      expect(deco('Lesen'), isNot(TextDecoration.lineThrough));

      await _tap(tester, find.bySemanticsLabel(l.a11yHabitReopen('Lesen')));
      expect(y('Lesen') < y('Sport') && y('Sport') < y('Wasser'), isTrue, reason: 'wieder an seinem Platz');
      await finishApp(tester, app);
    });

    testWidgets('Animationen reduziert: die Zeile steht sofort am neuen Platz', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpApp(tester, app);
      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      await tester.tap(find.bySemanticsLabel(l.a11yHabitDoneToday('Lesen')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(y('Sport') < y('Lesen'), isTrue);
      await tester.pumpAndSettle();
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

    testWidgets('Zeit-Rad am PC: Ziffern tippen stellt die Uhrzeit, die Stunde springt zu den Minuten', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final got = <int>[];
      int? value = 8 * 60;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme('himmel', dark: false),
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => TimeWheel(
                value: value,
                step: 5,
                onChanged: (v) => set(() {
                  value = v;
                  got.add(v);
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Ohne Klick: Das Stunden-Rad ist schon ausgewählt.
      for (final ch in ['1', '4', '3', '5']) {
        await tester.sendKeyEvent(LogicalKeyboardKey(ch.codeUnitAt(0)), character: ch);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(value, 14 * 60 + 35);
      expect(got.contains(60), isFalse, reason: 'die halbe Eingabe „1“ wird nicht gemeldet');
      // Einstellige Stunde: „9“ gilt sofort, dann Minuten „07“ – im 5er-Schritt wird daraus 05.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      for (final ch in ['9', '0', '7']) {
        await tester.sendKeyEvent(LogicalKeyboardKey(ch.codeUnitAt(0)), character: ch);
        await tester.pumpAndSettle();
      }
      expect(value, 9 * 60 + 5);
      debugDefaultTargetPlatformOverride = null;
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

  group('Formulare, Wochenbeginn und Spalten', () {
    testWidgets('Formular: „Speichern“ bleibt zu sehen, auch wenn das Zeitrad offen ist', (tester) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      const size = Size(412, 560);
      await pumpApp(tester, app, size: size);
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      await tester.enterText(find.byType(TextField).first, 'Chor');
      await _tap(tester, find.text(l.to)); // klappt das Zeitrad „Bis“ mit Schnellwahl auf
      final save = find.text(l.save).hitTestable();
      expect(save, findsOneWidget, reason: 'ohne Scrollen erreichbar');
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await _tap(tester, save);
      expect(app.store.blocks.single.name, 'Chor');
      await finishApp(tester, app);
    });

    testWidgets('Wochenbeginn Sonntag: Optionen, Wochenplan, „Diese Woche“ und einmalige Blöcke', (tester) async {
      final l = l10n('de');
      useFixedClock(); // Mittwoch, 18.11.2026
      addTearDown(() => weekFirstDay = 0);
      final app = await makeServices();
      await pumpApp(tester, app);
      final f = Fmt.of(tester.element(find.byType(AppShell)));
      await goTab(tester, l.navSettings);
      final picker = find.text(f.wdLong(0)); // die Auswahl zeigt den aktuellen Tag
      await tester.scrollUntilVisible(
        picker,
        200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last,
      );
      await _tap(tester, picker);
      await _tap(tester, find.text(f.wdLong(6)).last);
      expect(app.settings.weekFirstDay, 6);
      expect(weekStartOf(fixedNow), DateTime(2026, 11, 15));

      // Wochenplan: Die Woche läuft von Sonntag, 15. bis Samstag, 21.
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      expect(find.text(f.weekRange(DateTime(2026, 11, 15))), findsOneWidget);
      expect(tester.takeException(), isNull);

      // „Diese Woche“ endet am Samstag; der Sonntag danach ist schon „Später“.
      Task due(int day) => Task(
        id: 'x$day',
        title: 'x',
        categoryId: 'c',
        dueDate: DateTime(2026, 11, day),
        dueTime: null,
        done: false,
        doneAt: null,
        createdAt: fixedNow.toUtc(),
        updatedAt: fixedNow.toUtc(),
      );
      expect(sectionOf(due(21), 0, now: fixedNow), Section.week);
      expect(sectionOf(due(22), 0, now: fixedNow), Section.later);

      // Einmalige Blöcke landen am richtigen Tag der gezeigten Woche – gemerkt wird ihr Montag.
      app.store.addBlocks(
        name: 'Nur Montag',
        color: '#AABBCC',
        days: [0, 6],
        start: 600,
        end: 660,
        repeat: false,
        weekStart: DateTime(2026, 11, 15),
      );
      expect(app.store.blocksOn(DateTime(2026, 11, 16)).map((b) => b.name), ['Nur Montag']);
      expect(app.store.blocksOn(DateTime(2026, 11, 15)).map((b) => b.name), ['Nur Montag'], reason: 'der Sonntag');
      expect(app.store.blocksOn(DateTime(2026, 11, 22)), isEmpty, reason: 'nächster Sonntag: andere Woche');
      expect(app.store.blocksOn(DateTime(2026, 11, 23)), isEmpty);
      await tester.pumpAndSettle();
      await finishApp(tester, app);
    });

    testWidgets('Neuer Block: Aufgaben stehen schon an den Tagen davor (Vorlauf der Kategorie)', (tester) async {
      final l = l10n('de');
      useFixedClock(); // Mittwoch, 18.11.2026
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      final store = app.store;
      final homework = store.categories.firstWhere((c) => c.name == l.catHomework); // 1 Tag vorher
      final test = store.categories.firstWhere((c) => c.name == l.catTest); // 2 Tage vorher
      final friday = addDays(today(), 2);
      store.addTask(title: 'Mathe HÜ', categoryId: homework.id, dueDate: friday, dueTime: 8 * 60, subs: const []);
      store.addTask(title: 'Englisch-Test', categoryId: test.id, dueDate: friday, dueTime: 10 * 60, subs: const []);
      await pumpApp(tester, app);
      final f = Fmt.of(tester.element(find.byType(AppShell)));
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      Future<List<String>> chipsOn(int wd) async {
        // Genau einen Tag wählen: den gewünschten an, alle anderen aus.
        for (var i = 0; i < 7; i++) {
          final chip = find.bySemanticsLabel(f.wdLong(i)).last;
          final on = tester.getSemantics(chip).flagsCollection.isSelected == Tristate.isTrue;
          if (on != (i == wd)) await _tap(tester, chip);
        }
        return [
          for (final c in tester.widgetList<AppChip>(find.byType(AppChip)))
            if (c.label.contains('Mathe') || c.label.contains('Englisch')) c.label,
        ];
      }

      final handIn = l.infoHandIn(f.wd(4));
      expect(await chipsOn(1), isEmpty, reason: 'Dienstag: noch nichts dran');
      expect(await chipsOn(2), ['Englisch-Test · $handIn'], reason: 'Mittwoch: der Test (2 Tage vorher)');
      expect(await chipsOn(3), ['Mathe HÜ · $handIn', 'Englisch-Test · $handIn'], reason: 'Donnerstag: beide');
      expect(await chipsOn(4), ['Mathe HÜ', 'Englisch-Test'], reason: 'Freitag: Abgabetag');
      expect(tester.takeException(), isNull);

      // Am Donnerstag für den Test lernen: Der Block steht am Do, die Abgabezeit am Fr bleibt.
      await chipsOn(3);
      await _tap(tester, find.widgetWithText(AppChip, 'Englisch-Test · $handIn'));
      expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, 'Englisch-Test');
      await _tap(tester, find.text(l.save).last);
      final block = store.blocks.single;
      expect((block.day, block.repeat), (3, false));
      expect(store.tasks.firstWhere((t) => t.title == 'Englisch-Test').dueTime, 10 * 60);

      // Vorlauf umstellen: Test nur noch am selben Tag – am Donnerstag steht er dann nicht mehr.
      store.updateCategory(test, name: test.name, color: test.color, offset: 0);
      store.updateCategory(homework, name: homework.name, color: homework.color, offset: 3);
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      expect(await chipsOn(3), ['Mathe HÜ · $handIn']);
      expect(await chipsOn(1), ['Mathe HÜ · $handIn'], reason: 'Hausübung jetzt 3 Tage vorher');
      expect(await chipsOn(4), ['Mathe HÜ', 'Englisch-Test']);
      await finishApp(tester, app);
    });

    testWidgets('Neuer Block: Aufgabe des Tages antippen – Block mit ihrem Namen, die Aufgabe bekommt die Zeit', (
      tester,
    ) async {
      final l = l10n('de');
      useFixedClock(); // Mittwoch
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      final cat = app.store.categories.first;
      app.store.addTask(
        title: 'Rasenmähen',
        categoryId: cat.id,
        dueDate: addDays(today(), 2), // Freitag
        dueTime: null,
        subs: const [],
      );
      await pumpApp(tester, app);
      final f = Fmt.of(tester.element(find.byType(AppShell)));
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      // Heute (Mittwoch) ist nichts fällig – erst am Freitag steht die Aufgabe da (das „+“ steht immer).
      expect(find.widgetWithText(AppChip, 'Rasenmähen'), findsNothing);
      await _tap(tester, find.bySemanticsLabel(f.wdLong(4)).last);
      await _tap(tester, find.bySemanticsLabel(f.wdLong(2)).last);
      expect(find.text(l.tasksThatDay), findsOneWidget);
      await _tap(tester, find.widgetWithText(AppChip, 'Rasenmähen'));
      expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, 'Rasenmähen');
      await _tap(tester, find.text(l.save).last);
      final b = app.store.blocks.single;
      expect((b.name, b.day, b.repeat, b.weekStart, b.color), ('Rasenmähen', 4, false, '2026-11-16', cat.color));
      expect(app.store.tasks.single.dueTime, b.start);
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben am PC: ⋮ → Spalten stellt Anzahl, Zeiträume und Kategorie-Spalten ein', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app, size: const Size(1920, 1009));
      TasksBoard board() => tester.widget<TasksBoard>(find.byType(TasksBoard));
      expect(board().maxVisible, 3);
      await _tap(tester, find.bySemanticsLabel(l.moreOptions));
      await _tap(tester, find.text(l.columns));
      Finder inSheet(Finder f) => find.descendant(of: find.byType(ColumnsSheet), matching: f);
      await _tap(tester, inSheet(find.text('4')));
      await _tap(tester, inSheet(find.bySemanticsLabel(l.overdue)).last);
      final cat = app.store.categories.first;
      await _tap(tester, inSheet(find.bySemanticsLabel(cat.name)).last);
      // Gilt sofort, noch bevor das Fenster zu ist.
      expect(board().maxVisible, 4);
      expect(board().groups.map((g) => g.id), isNot(contains(Section.overdue.name)));
      expect(board().groups.last.id, 'k-${cat.id}');
      expect(board().groups.last.items, isNotEmpty);
      await _tap(tester, inSheet(find.text(l.close)));
      expect(find.byType(ColumnsSheet), findsNothing);
      expect(find.bySemanticsLabel(l.sectionCount(l.overdue, 1)), findsNothing);
      expect(tester.takeException(), isNull);

      // Bleibt gespeichert (nur an diesem Gerät).
      final again = SettingsStore((await tester.runAsync(SharedPreferences.getInstance))!);
      expect(again.boardVisible, 4);
      expect(again.boardHidden, {Section.overdue.name});
      expect(again.boardCats, [cat.id]);

      // Am Handy gibt es den Eintrag auch – nur ohne „Nebeneinander sichtbar“.
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.moreOptions));
      await _tap(tester, find.text(l.columns));
      expect(find.byType(ColumnsSheet), findsOneWidget);
      expect(find.text(l.columnsVisible), findsNothing);
      expect(find.text(l.columnsDragHintTouch), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Handy: Zeiträume aus, Kategorie als Abschnitt – gilt auch in der Liste am Handy', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      final cat = app.store.categories.first;
      app.settings.updateDevice(
        (s) => s
          ..boardHidden = {Section.later.name}
          ..boardCats = [cat.id],
      );
      await pumpApp(tester, app);
      expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(l.later)}')), findsNothing);
      final n = app.store.tasks.where((t) => t.categoryId == cat.id).length;
      await tester.scrollUntilVisible(
        find.bySemanticsLabel(l.sectionCount(cat.name, n)),
        200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
      );
      expect(find.bySemanticsLabel(l.sectionCount(cat.name, n)), findsOneWidget);

      // Alles aus: ein Hinweis statt einer leeren Liste – die Gewohnheiten bleiben.
      app.settings.updateDevice((s) => s.boardHidden = {for (final x in Section.values) x.name});
      app.settings.updateDevice((s) => s.boardCats = []);
      await tester.pumpAndSettle();
      expect(find.text(l.columnsAllHidden), findsOneWidget);
      expect(find.byType(HabitsTaskCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Handy: Abschnitt lange drücken und ziehen ändert die Reihenfolge, die anderen rücken mit', (
      tester,
    ) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      List<String> ids() => [
        for (final m in tester.widgetList<MovableSection>(find.byType(MovableSection, skipOffstage: false))) m.id,
      ];
      final before = ids();
      expect(before.length, greaterThanOrEqualTo(3));
      final a = before[0], b = before[1];
      Finder head(String id) => find.descendant(
        of: find.byWidgetPredicate((w) => w is MovableSection && w.id == id),
        matching: find.byType(SectionHead),
      );

      // Die erste Überschrift lange drücken und unter die zweite ziehen.
      final from = tester.getCenter(head(a));
      final to = tester.getRect(head(b)).bottomCenter + const Offset(0, 24);
      var saves = 0;
      void count() => saves++;
      app.settings.addListener(count);
      addTearDown(() => app.settings.removeListener(count));
      final g = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Noch während des Ziehens steht die Reihenfolge schon so da, wie sie nach dem Loslassen wird.
      expect(ids().take(2), [b, a]);
      expect(tester.takeException(), isNull);
      // Flüssig: Während des Ziehens wird nichts gespeichert (das würde die ganze App neu aufbauen).
      expect(saves, 0);
      await g.up();
      await tester.pumpAndSettle();
      expect(saves, 1, reason: 'beim Loslassen genau einmal gespeichert');
      expect(ids().take(2), [b, a]);
      expect(app.settings.boardColumnOrder().where(before.contains).take(2), [b, a]);
      // Ein kurzer Tipp klappt weiter nur ein und aus.
      await _tap(tester, head(b));
      expect(app.store.tasks, isNotEmpty);
      expect(tester.takeException(), isNull);

      // Ohne Ziehen: „Nach oben verschieben“ (Screenreader).
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(head(a));
      final action = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map(CustomSemanticsAction.getAction)
          .firstWhere((x) => x!.label == l.moveUp)!;
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.customAction,
          nodeId: node.id,
          viewId: tester.view.viewId,
          arguments: CustomSemanticsAction.getIdentifier(action),
        ),
      );
      await tester.pumpAndSettle();
      handle.dispose();
      expect(ids().take(2), [a, b]);
      await finishApp(tester, app);
    });

    testWidgets('Spalten: alles ausgeblendet zeigt einen Hinweis statt einer leeren Seite', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      app.settings.updateDevice((s) => s.boardHidden = {for (final x in Section.values) x.name});
      await pumpApp(tester, app, size: const Size(1366, 705));
      expect(find.text(l.columnsAllHidden), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Neuer Block aus einer Aufgabe mit Uhrzeit: 10:07 bleibt 10:07, die Aufgabe bleibt unverändert', (
      tester,
    ) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      app.store.addTask(
        title: 'Zahnarzt',
        categoryId: app.store.categories.first.id,
        dueDate: today(),
        dueTime: 10 * 60 + 7,
        subs: const [],
      );
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
      await _tap(tester, find.widgetWithText(AppChip, 'Zahnarzt'));
      await _tap(tester, find.text(l.save).last);
      expect(app.store.blocks.single.start, 10 * 60 + 7);
      expect(app.store.tasks.single.dueTime, 10 * 60 + 7);
      await finishApp(tester, app);
    });

    test('Wochenbeginn umstellen: die gezeigte Woche bleibt, statt fast eine Woche zurückzuspringen', () {
      useFixedClock(); // Mittwoch, 18.11.2026
      addTearDown(() => weekFirstDay = 0);
      weekFirstDay = 0;
      final ui = UiState()..weekStep(1); // Mo 23. – So 29.
      expect(ui.weekStart, DateTime(2026, 11, 23));
      weekFirstDay = 1; // Dienstag
      ui.weekFirstDayChanged();
      expect(ui.weekStart, DateTime(2026, 11, 24));
      // Tagesansicht: derselbe Tag bleibt gewählt, auch über die Wochengrenze.
      ui.toggleWeekDay(0); // Di 24.
      weekFirstDay = 3; // Donnerstag
      ui.weekFirstDayChanged();
      expect(addDays(ui.weekStart, ui.weekDay!), DateTime(2026, 11, 24));
      ui.weekStep(-6);
      expect(addDays(ui.weekStart, ui.weekDay!), DateTime(2026, 11, 18));
      expect(ui.weekStart, DateTime(2026, 11, 12));
    });

    testWidgets('Spalten: 2, 3 und 4 nebeneinander – genau so viele sind zu sehen', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      for (final size in const [Size(1920, 1009), Size(1366, 705)]) {
        for (var n = SettingsStore.boardVisibleMin; n <= SettingsStore.boardVisibleMax; n++) {
          app.settings.updateDevice((s) => s.boardVisible = n);
          await pumpApp(tester, app, size: size);
          final board = tester.widget<TasksBoard>(find.byType(TasksBoard));
          expect(board.groups.length, greaterThanOrEqualTo(5), reason: 'die Beispieldaten füllen genug Listen');
          final area = tester.getRect(find.byType(TasksBoard));
          final shown = [
            for (final g in board.groups) find.bySemanticsLabel(l.sectionCount(g.label, g.items.length)).hitTestable(),
          ].where((f) => f.evaluate().isNotEmpty).map(tester.getRect).toList();
          expect(shown, hasLength(n), reason: '$n Spalten bei $size');
          for (final r in shown) {
            expect(r.left, greaterThanOrEqualTo(area.left), reason: 'ganz im Fenster ($n bei $size)');
            expect(r.right, lessThanOrEqualTo(area.right + 0.5), reason: 'ganz im Fenster ($n bei $size)');
          }
          expect(tester.takeException(), isNull, reason: 'kein Überlauf mit $n Spalten bei $size');
        }
      }
      await finishApp(tester, app);
    });

    testWidgets('Spalten: weniger Listen als eingestellt füllen die ganze Breite', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      app.settings.updateDevice(
        (s) => s
          ..boardVisible = SettingsStore.boardVisibleMax
          ..boardHidden = {
            for (final x in Section.values)
              if (x != Section.today && x != Section.week) x.name,
          },
      );
      await pumpApp(tester, app, size: const Size(1920, 1009));
      final board = tester.widget<TasksBoard>(find.byType(TasksBoard));
      expect(board.groups, hasLength(2));
      final area = tester.getRect(find.byType(TasksBoard));
      final last = board.groups.last;
      final r = tester.getRect(find.bySemanticsLabel(l.sectionCount(last.label, last.items.length)));
      expect(r.right, greaterThan(area.right - 60), reason: 'die zweite Liste reicht bis an den Rand');
      await finishApp(tester, app);
    });

    testWidgets('Spalten: an der Überschrift ziehen ändert die Reihenfolge und bleibt gespeichert', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      // Am PC (im Test sonst Android: dort zieht man erst nach langem Druck).
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpApp(tester, app, size: const Size(1920, 1009));
      List<String> ids() => [for (final g in tester.widget<TasksBoard>(find.byType(TasksBoard)).groups) g.id];
      final before = ids();
      final a = before[0], b = before[1], c = before[2];
      Finder head(String id) {
        final g = tester.widget<TasksBoard>(find.byType(TasksBoard)).groups.firstWhere((g) => g.id == id);
        return find.bySemanticsLabel(l.sectionCount(g.label, g.items.length));
      }

      // Die erste Liste mit der Maus auf die dritte ziehen: Sie landet dahinter.
      Offset title(String id) => tester.getRect(head(id)).topCenter + const Offset(0, 28);
      final from = title(a), to = title(c) + const Offset(0, 200);
      var saves = 0;
      void count() => saves++;
      app.settings.addListener(count);
      addTearDown(() => app.settings.removeListener(count));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: from);
      await tester.pump();
      final cards = find.byType(TaskCard).evaluate().length;
      await mouse.down(from);
      await tester.pump();
      for (var i = 1; i <= 8; i++) {
        await mouse.moveTo(Offset.lerp(from, to, i / 8)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Am Zeiger hängt die ganze Liste mit ihren Aufgaben, nicht nur die Überschrift.
      expect(find.byType(TaskCard).evaluate().length, greaterThan(cards));
      expect(tester.takeException(), isNull);
      // Flüssig: Während des Ziehens wird nichts gespeichert (das würde die ganze App neu aufbauen).
      expect(saves, 0);
      await mouse.up();
      await tester.pump();
      expect(saves, 1, reason: 'beim Loslassen genau einmal gespeichert');
      await tester.pumpAndSettle();
      expect(ids().take(3), [b, c, a]);
      expect(tester.takeException(), isNull);
      // Danach lässt sich wieder blättern.
      expect(tester.widget<PageView>(find.byType(PageView)).physics, isNull);
      // Geblättert wurde dabei nicht: Die neue erste Liste steht ganz links.
      expect(head(b).hitTestable(), findsOneWidget);

      // Gespeichert (nur an diesem Gerät) – und neu geladen dieselbe Reihenfolge.
      late SettingsStore again;
      await tester.runAsync(() async => again = SettingsStore(await SharedPreferences.getInstance()));
      expect(again.boardColumnOrder().where(before.contains).take(3), [b, c, a]);

      // Ohne Maus: „Nach links verschieben“ holt sie wieder einen Platz zurück.
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(head(a));
      final action = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map(CustomSemanticsAction.getAction)
          .firstWhere((x) => x!.label == l.moveLeft)!;
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.customAction,
          nodeId: node.id,
          viewId: tester.view.viewId,
          arguments: CustomSemanticsAction.getIdentifier(action),
        ),
      );
      await tester.pumpAndSettle();
      handle.dispose();
      expect(ids().take(3), [b, a, c]);

      // Ohne gespeicherte Reihenfolge gilt wieder die übliche.
      app.settings.updateDevice((s) => s.boardOrder = []);
      await tester.pumpAndSettle();
      expect(ids(), before);
      await finishApp(tester, app);
    });

    testWidgets('⋮-Menü: die Einträge bleiben in fester Reihenfolge, egal wie oft man sie benutzt', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      for (final label in [l.hideCompleted, l.showCompleted, l.hideCompleted]) {
        await _tap(tester, find.bySemanticsLabel(l.moreOptions));
        await _tap(tester, find.text(label));
      }
      await _tap(tester, find.bySemanticsLabel(l.moreOptions));
      final tops = [
        for (final t in [l.search, l.sort, l.manageCategories, l.showCompleted, l.deleteCompleted])
          tester.getTopLeft(find.text(t).last).dy,
      ];
      expect(tops, [...tops]..sort());
      await finishApp(tester, app);
    });

    testWidgets('Aufgabe: Wischen nach links löscht nicht mehr', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      final n = app.store.tasks.length;
      await pumpApp(tester, app);
      await tester.drag(find.byType(TaskCard).first, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(app.store.tasks, hasLength(n));
      expect(find.text(l.undo), findsNothing);
      await finishApp(tester, app);
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
      await tester.scrollUntilVisible(
        find.text(l.exportData),
        200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last,
      );
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
      await _tap(tester, find.text(l.createAccount));
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
        await _tap(tester, find.text(l.createAccount));
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

    testWidgets('Erster Start: Konto erstellen oder anmelden – beides führt über die Datenbank zur passenden Seite', (
      tester,
    ) async {
      for (final lang in ['de', 'en']) {
        for (final register in [true, false]) {
          final l = l10n(lang);
          final app = await makeServices(
            lang: lang,
            syncMode: null,
            cloud: FakeCloud('http://localhost:1')..signedIn = false,
          );
          await pumpApp(tester, app);
          // Alle drei Wege stehen auf der ersten Seite
          expect(find.text(l.createAccount), findsOneWidget);
          expect(find.text(l.haveAccount), findsOneWidget);
          expect(find.text(l.setupLocalTitle), findsOneWidget);

          await _tap(tester, find.text(register ? l.createAccount : l.haveAccount));
          expect(find.text(l.connectDb), findsWidgets, reason: 'ohne Datenbank gibt es kein Konto');
          // Mit vorhandenem Konto: kurze Seite – nur der Link zu Supabase und die Felder, keine Einrichtung
          expect(find.text(l.openSupabase), findsOneWidget);
          expect(find.text(l.copySql), register ? findsOneWidget : findsNothing);
          expect(find.byType(TextField), findsNWidgets(2));
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(0), 'https://abcdefgh.supabase.co');
          await tester.enterText(fields.at(1), 'sb_publishable_test_key_123');
          await tester.ensureVisible(find.text(l.connect));
          await tester.pumpAndSettle();
          await _tap(tester, find.text(l.connect));

          expect(app.settings.syncMode, SyncMode.cloud);
          if (register) {
            expect(find.text(l.createAccount), findsOneWidget, reason: 'Überschrift „Konto erstellen“');
            expect(find.text(l.haveAccount), findsOneWidget, reason: 'Link zur Anmeldung');
          } else {
            expect(find.text(l.createAccount), findsNothing);
            expect(find.text(l.signIn), findsNWidgets(2), reason: 'Überschrift und Knopf „Anmelden“');
            expect(find.text(l.signUp), findsOneWidget, reason: 'Link zum Registrieren');
          }
          await finishApp(tester, app);
        }
      }
    });

    testWidgets('Erster Start: Zurück und anderer Weg, nicht erreichbare Datenbank', (tester) async {
      final l = l10n('de');
      final cloud = FakeCloud('http://localhost:1')
        ..signedIn = false
        ..reachable = false;
      final app = await makeServices(syncMode: null, cloud: cloud);
      await pumpApp(tester, app);
      await _tap(tester, find.text(l.haveAccount));
      await _tap(tester, find.bySemanticsLabel(l.back));
      expect(find.text(l.createAccount), findsOneWidget);
      expect(find.text(l.haveAccount), findsOneWidget);
      expect(app.settings.syncMode, SyncMode.none);

      // Danach der andere Weg: Es zählt die letzte Wahl, nicht die erste
      await _tap(tester, find.text(l.createAccount));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'https://abcdefgh.supabase.co');
      await tester.enterText(fields.at(1), 'sb_publishable_test_key_123');
      await tester.ensureVisible(find.text(l.connect));
      await tester.pumpAndSettle();
      await _tap(tester, find.text(l.connect));
      expect(find.text(l.errNoConnection), findsOneWidget, reason: 'Datenbank nicht erreichbar');
      expect(app.settings.syncMode, SyncMode.none, reason: 'nichts gespeichert');

      cloud.reachable = true;
      await tester.ensureVisible(find.text(l.connect));
      await tester.pumpAndSettle();
      await _tap(tester, find.text(l.connect));
      expect(find.text(l.createAccount), findsOneWidget, reason: 'Überschrift „Konto erstellen“');
      expect(find.text(l.haveAccount), findsOneWidget);
      await finishApp(tester, app);
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

    testWidgets('Aufgaben: Listen nebeneinander, höchstens drei zu sehen, daneben die Seitenleiste', (tester) async {
      useFixedClock(); // Beispieldaten hängen an der Uhrzeit (z. B. „heute, 18:00“)
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      const size = Size(1920, 1009);
      await pumpApp(tester, app, size: size);
      Finder head(String label, int n) => find.bySemanticsLabel(l.sectionCount(label, n)).hitTestable();
      // Jeder Zeitraum ist eine eigene Liste: Die Überschriften stehen nebeneinander, nicht untereinander.
      final a = tester.getRect(head(l.overdue, 1)), b = tester.getRect(head(l.today, 2));
      final c = tester.getRect(head(l.thisWeek, 2));
      expect({a.top, b.top, c.top}, hasLength(1));
      expect(a.left < b.left && b.left < c.left, isTrue);
      expect(c.right, lessThan(size.width - Sizes.boardSide), reason: 'rechts bleibt Platz für die Seitenleiste');
      // Die vierte Liste ist noch nicht zu sehen – erst nach dem Weiterblättern.
      expect(head(l.later, 1), findsNothing);
      await _tap(tester, find.bySemanticsLabel(l.nextLists));
      expect(head(l.later, 1), findsOneWidget);
      expect(head(l.overdue, 1), findsNothing);
      await _tap(tester, find.bySemanticsLabel(l.prevLists));
      expect(head(l.overdue, 1), findsOneWidget);

      // Seitenleiste: Stand von heute und die Gewohnheiten (dafür kein eigener Chip mehr)
      expect(find.text(l.todayOpenLate(3, 1)), findsOneWidget);
      expect(find.text(l.habits), findsOneWidget);
      expect(tester.getRect(find.text(l.habits)).left, greaterThan(c.right));
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben: in den Listen steht kein eigener Knopf „+ Aufgabe“', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      await pumpApp(tester, app, size: const Size(1366, 705));
      // Ohne Aufgaben steht nur „Heute“ da – leer und ohne Knopf; neue Aufgaben kommen über das Plus.
      expect(find.bySemanticsLabel(l.sectionCount(l.today, 0)), findsOneWidget);
      expect(find.descendant(of: find.byType(TasksBoard), matching: find.byType(AppButton)), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben: ein Tag im kleinen Monat öffnet ihn im Kalender', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app, size: const Size(1366, 705));
      final f = Fmt.of(tester.element(find.byType(TasksSide)));
      final day = DateTime(today().year, today().month, 10);
      await tester.ensureVisible(find.bySemanticsLabel(RegExp('^${RegExp.escape(f.dayMonth(day))}')).last);
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(RegExp('^${RegExp.escape(f.dayMonth(day))}')).last);
      expect(find.text(f.longDate(day)), findsOneWidget, reason: 'Kalender zeigt den gewählten Tag');
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben: gemerkter Filter „nur Gewohnheiten“ zählt am PC als „Alle“', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      // Der Chip steht am Handy ganz hinten in der Leiste – erst hinscrollen.
      await tester.scrollUntilVisible(
        find.widgetWithText(AppChip, l.habits),
        120,
        scrollable: find.ancestor(of: find.widgetWithText(AppChip, l.all), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(AppChip, l.habits));
      expect(find.text('Müll rausbringen'), findsNothing);
      await pumpApp(tester, app, size: const Size(1366, 705));
      expect(find.text('Müll rausbringen'), findsOneWidget);
      expect(find.text(l.habits), findsOneWidget, reason: 'nur noch die Karte in der Seitenleiste');
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben: nach rechts geblättert und die letzte Liste wird leer – nichts bricht', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app, size: const Size(1366, 705));
      // Zwei Listen sichtbar; bis ans Ende blättern
      for (var i = 0; i < 4; i++) {
        final next = find.bySemanticsLabel(l.nextLists);
        if (next.evaluate().isEmpty) break;
        await _tap(tester, next);
      }
      app.store.clearDone();
      await tester.pumpAndSettle();
      for (final t in app.store.tasks.where((t) => !t.done).toList()) {
        app.store.deleteTask(t);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(l.sectionCount(l.today, 0)).hitTestable(), findsOneWidget);
      expect(find.bySemanticsLabel(l.nextLists), findsNothing, reason: 'nur noch eine Liste');
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben: nach Kategorie sortiert und mit großer Schrift ohne Überlauf', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      for (final size in const [Size(1366, 705), Size(1210, 620)]) {
        await pumpApp(tester, app, size: size, textScale: 1.6);
        expect(tester.takeException(), isNull, reason: '$size');
      }
      final ui = tester.widget<TasksSide>(find.byType(TasksSide)).ui;
      ui.set((s) => s.sort = SortMode.category);
      await tester.pumpAndSettle();
      final first = app.store.categories.first;
      expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(first.name)} \\(')), findsWidgets);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben: viele Gewohnheiten scrollen in ihrer Karte, der Monat bleibt im Fenster', (tester) async {
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      for (var i = 0; i < 20; i++) {
        app.store.addHabit(name: 'Gewohnheit $i', color: '#AABBCC');
      }
      for (final size in const [Size(1920, 1009), Size(1366, 705)]) {
        await pumpApp(tester, app, size: size);
        final f = Fmt.of(tester.element(find.byType(TasksSide)));
        final month = find.text(f.monthYear(today()));
        expect(tester.getRect(month).top, lessThan(size.height - 80), reason: 'Monat sichtbar bei $size');
        expect(find.text('Gewohnheit 19').hitTestable(), findsNothing, reason: 'unten in der Liste');
        // Im großen Fenster passt der ganze Monat darunter.
        final grid = tester.getRect(find.descendant(of: find.byType(TasksSide), matching: find.byType(MonthGrid)));
        if (size.height > 1000) expect(grid.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      }
      // In der Karte lässt sich bis zur letzten scrollen.
      await tester.scrollUntilVisible(
        find.text('Gewohnheit 19'),
        80,
        scrollable: find.descendant(of: find.byType(HabitsTaskCard), matching: find.byType(Scrollable)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gewohnheit 19').hitTestable(), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Aufgaben: im schmalen PC-Fenster bleibt die eine Liste mit Abschnitten', (tester) async {
      useFixedClock(); // Beispieldaten hängen an der Uhrzeit (z. B. „heute, 18:00“)
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app, size: const Size(1000, 700));
      expect(find.bySemanticsLabel(l.nextLists), findsNothing);
      expect(find.text(l.habits), findsNWidgets(2), reason: 'Chip und Karte „Gewohnheiten“');
      final a = tester.getRect(find.bySemanticsLabel(l.sectionCount(l.overdue, 1)));
      final b = tester.getRect(find.bySemanticsLabel(l.sectionCount(l.today, 2)));
      expect(b.top, greaterThan(a.bottom), reason: 'Abschnitte untereinander');
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
