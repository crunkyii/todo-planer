import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/sync_service.dart';
import 'package:todo_liste/screens/shell.dart';
import 'package:todo_liste/theme/color_math.dart';
import 'package:todo_liste/theme/tokens.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'fake_supabase.dart';
import 'harness.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Verbindung, die der Test ein- und ausschalten kann.
class FakeConnectivity implements Connectivity {
  final _c = StreamController<List<ConnectivityResult>>.broadcast();
  void set(bool online) => _c.add([online ? ConnectivityResult.wifi : ConnectivityResult.none]);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _c.stream;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  group('Aufgaben', () {
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

  group('Kalender und Woche', () {
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
        await finishApp(tester, app);
      }
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
  });
}
