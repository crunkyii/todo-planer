import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/screens/task_card.dart';
import 'package:todo_liste/theme/tokens.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/widgets/pickers.dart';
import 'package:todo_liste/widgets/splash.dart';
import 'package:todo_liste/widgets/swipe.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'harness.dart';

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Langsames Ziehen um [dx] und Loslassen ohne Schwung – so zählt nur die Strecke.
Future<TestGesture> _slowDrag(WidgetTester tester, Finder on, double dx, {bool release = true}) async {
  final g = await tester.startGesture(tester.getCenter(on));
  const steps = 15;
  for (var i = 0; i < steps; i++) {
    await g.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 200)); // stillhalten: kein Schwung
  if (release) await g.up();
  return g;
}

final _splash = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SplashPainter);
final _sparks = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SparkPainter);

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  group('Splash-Varianten', () {
    test('wie variant(nr) im Entwurf: gleiche Nummer, gleicher Splash', () {
      // Werte aus dem JavaScript des Entwurfs (node).
      final v0 = SplashVariant.of(0);
      expect(
        [for (final d in v0.drops) (d.w, d.angle, d.dist, d.delay)],
        [(13, 55, 15, 38), (6, 143, 13, 34), (10, 205, 14, 10), (9, 296, 14, 24), (10, 365, 15, 30)],
      );
      expect([for (final d in v0.dots) (d.s, d.angle, d.dist, d.delay)], [(4, 23, 15, 83), (3, 153, 18, 66)]);
      final v7 = SplashVariant.of(7);
      expect(v7.drops.length, 6);
      expect([for (final d in v7.dots) (d.s, d.angle, d.dist, d.delay)], [(5, 96, 16, 87)]);
      expect(SplashVariant.of(49).drops.first.w, 11);
    });

    test('alle 50: 3–6 Tropfen, einer groß, 0–3 Spritzer, knapp am Kreis', () {
      final seen = <String>{};
      for (var nr = 0; nr < SplashVariant.count; nr++) {
        final v = SplashVariant.of(nr);
        expect(v.drops.length, inInclusiveRange(3, 6));
        expect(v.dots.length, inInclusiveRange(0, 3));
        expect(v.drops.first.w, inInclusiveRange(11, 15), reason: 'immer ein großer Tropfen');
        for (final d in v.drops.skip(1)) {
          expect(d.w, inInclusiveRange(4, 12), reason: 'die anderen klein bis mittel');
        }
        for (final d in v.drops) {
          expect(d.dist, inInclusiveRange(10, 18));
        }
        seen.add('${[for (final d in v.drops) d.angle]}');
      }
      expect(seen.length, SplashVariant.count, reason: '50 verschiedene Splashes');
    });

    test('Kreis springt 0,6 → 1,2 → 1', () {
      expect(CheckMark.scaleAt(0), Motion.checkFrom);
      expect(CheckMark.scaleAt(230), closeTo(Motion.checkPeak, 0.001));
      expect(CheckMark.scaleAt(600), 1);
    });

    test('Blättern: hinaus in Wischrichtung, herein von der anderen Seite', () {
      final start = pageFrame(ms: 0, dir: 1, distance: 400, from: -100);
      expect(start.x, -100);
      expect(start.old, isTrue);
      final out = pageFrame(ms: 180, dir: 1, distance: 400);
      expect(out.x, -400);
      expect(out.opacity, closeTo(Motion.pageDim, 0.001));
      final enter = pageFrame(ms: 220, dir: 1, distance: 400);
      expect(enter.old, isFalse);
      expect(enter.x, 400, reason: 'der nächste Monat kommt von rechts');
      expect(pageFrame(ms: 540, dir: 1, distance: 400).x, 0);
      expect(pageFrame(ms: 220, dir: -1, distance: 400).x, -400, reason: 'der vorige kommt von links');
      expect(pageFrame(ms: 150, dir: 1, distance: 30, title: true).opacity, 0, reason: 'Titel blendet ganz aus');
    });
  });

  group('Wischen', () {
    testWidgets('Kalender: Inhalt folgt dem Finger, dahinter der nächste Monat, dann gleitet er', (tester) async {
      useFixedClock(); // November 2026
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      final grid = find.byType(MonthGrid);
      final rest = tester.getTopLeft(grid).dx;

      final g = await _slowDrag(tester, grid, -150, release: false);
      expect(tester.getTopLeft(grid).dx, lessThan(rest - 100), reason: 'folgt dem Finger');
      expect(find.text('Dezember'), findsOneWidget);
      await g.up();
      await tester.pump(); // blättert weiter, die Bewegung startet
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('November 2026'), findsOneWidget, reason: 'der alte Titel gleitet erst hinaus');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Dezember 2026'), findsOneWidget);
      expect(tester.getTopLeft(grid).dx, greaterThan(rest), reason: 'der neue kommt von rechts herein');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(grid).dx, rest);
      expect(find.text('Dezember'), findsNothing);

      await _slowDrag(tester, grid, 150); // nach rechts = voriger Monat
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Kalender: zu kurz gezogen federt zurück', (tester) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      final grid = find.byType(MonthGrid);
      final rest = tester.getTopLeft(grid).dx;
      await _slowDrag(tester, grid, 70);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(grid).dx, greaterThan(rest), reason: 'federt noch zurück');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(grid).dx, rest);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Oktober'), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('Kalender: Pfeile und „Heute“ blättern mit derselben Bewegung', (tester) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      final grid = find.byType(MonthGrid);
      final rest = tester.getTopLeft(grid).dx;
      await tester.tap(find.bySemanticsLabel(l.prevMonth));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(grid).dx, greaterThan(rest), reason: 'voriger Monat: der alte geht nach rechts');
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(l.prevMonth));
      expect(find.text('September 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(l.today));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(grid).dx, lessThan(rest), reason: 'zu heute (später): der alte geht nach links');
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(tester.getTopLeft(grid).dx, rest);
      await finishApp(tester, app);
    });

    testWidgets('Zweimal schnell weiter: der alte Monat gleitet weiter hinaus, kein Sprung', (tester) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      final grid = find.byType(MonthGrid);
      final rest = tester.getTopLeft(grid).dx;
      await tester.tap(find.bySemanticsLabel(l.nextMonth));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final x1 = tester.getTopLeft(grid).dx;
      expect(x1, lessThan(rest));
      await tester.tap(find.bySemanticsLabel(l.nextMonth));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(grid).dx, lessThanOrEqualTo(x1), reason: 'springt nicht zurück in die Mitte');
      expect(find.text('Dezember 2026'), findsNothing, reason: 'der übersprungene Monat kommt nie herein');
      await tester.pumpAndSettle();
      expect(find.text('Dezember 2026'), findsNothing);
      expect(tester.getTopLeft(grid).dx, rest);
      await finishApp(tester, app);
    });

    testWidgets('Wochenplan: Wischen zeigt die nächste Woche und blättert', (tester) async {
      useFixedClock(); // KW 47
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
      final g = await _slowDrag(tester, find.text('Schule').first, -150, release: false);
      expect(find.text(l.weekNumber(48)), findsOneWidget, reason: 'dahinter die nächste Woche');
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text(l.weekNumber(48)), findsOneWidget);
      await _slowDrag(tester, find.text('Schule').first, 60);
      await tester.pumpAndSettle();
      expect(find.text(l.weekNumber(48)), findsOneWidget, reason: 'zu kurz: bleibt');
      await finishApp(tester, app);
    });

    testWidgets('„Animationen reduzieren“: kein Mitziehen, nur Überblenden', (tester) async {
      useFixedClock();
      _reduceMotion(tester);
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      final grid = find.byType(MonthGrid);
      final rest = tester.getTopLeft(grid).dx;
      final g = await _slowDrag(tester, grid, -150, release: false);
      expect(tester.getTopLeft(grid).dx, rest);
      expect(find.text('Dezember'), findsNothing);
      await g.up();
      await tester.pump();
      expect(find.text('Dezember 2026'), findsOneWidget, reason: 'sofort der neue Monat');
      expect(tester.getTopLeft(grid).dx, rest);
      await tester.pumpAndSettle();
      await finishApp(tester, app);
    });
  });

  group('Abhaken', () {
    testWidgets('Aufgabe: Splash erscheint über den Zeilen und verschwindet, Titel wird durchgestrichen', (
      tester,
    ) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      await _tap(tester, find.bySemanticsLabel(l.navCalendar));
      expect(_splash, findsNothing, reason: 'nicht beim Öffnen');
      await tester.tap(find.bySemanticsLabel(l.a11yDone('Müll rausbringen')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_splash, findsOneWidget);
      expect(
        find.ancestor(of: _splash, matching: find.byType(Overlay)),
        findsWidgets,
        reason: 'im Overlay, also über den Nachbarzeilen',
      );
      final strike = find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null);
      expect(find.descendant(of: find.byType(StrikeText), matching: strike), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16)); // die Uhr des Splashs läuft ab hier
      await tester.pump(const Duration(milliseconds: 700));
      expect(_splash, findsNothing, reason: 'nach gut einer halben Sekunde weg');
      await tester.pumpAndSettle();
      expect(app.store.tasks.firstWhere((t) => t.title == 'Müll rausbringen').done, isTrue);

      // Wieder öffnen spritzt nicht.
      await tester.tap(find.bySemanticsLabel(l.a11yReopen('Müll rausbringen')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_splash, findsNothing);
      await tester.pumpAndSettle();
      await finishApp(tester, app);
    });

    testWidgets('Gewohnheiten: Splash, Serie zählt hoch, alle erledigt → Funken und Meldung', (tester) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      expect(_splash, findsNothing);
      final k = isoDate(today());
      final open = app.store.habits.where((h) => !app.store.habitDone(h.id, k)).toList();
      expect(open.length, 2);

      await tester.tap(find.bySemanticsLabel(l.a11yHabitDoneToday(open[0].name)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_splash, findsOneWidget);
      expect(_sparks, findsNothing, reason: 'noch nicht alle erledigt');
      await tester.pumpAndSettle();
      expect(_splash, findsNothing);
      expect(find.text('3'), findsWidgets, reason: 'Serie „Lesen“ 2 → 3');

      await tester.tap(find.bySemanticsLabel(l.a11yHabitDoneToday(open[1].name)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sparks, findsOneWidget);
      expect(find.text(l.allHabitsDone), findsOneWidget);
      await tester.pumpAndSettle();
      expect(_sparks, findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('Ohne Gewohnheiten: „alle abhaken“ spritzt nicht und meldet nichts', (tester) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.habitsCheckAll));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_splash, findsNothing);
      expect(_sparks, findsNothing);
      expect(find.text(l.allHabitsDone), findsNothing);
      await tester.pumpAndSettle();
      await finishApp(tester, app);
    });

    testWidgets('„Animationen reduzieren“: kein Splash, keine Funken, Abhaken geht', (tester) async {
      useFixedClock();
      _reduceMotion(tester);
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      await tester.tap(find.bySemanticsLabel(l.a11yDone('Müll rausbringen')));
      await tester.pump();
      expect(_splash, findsNothing);
      await tester.tap(find.bySemanticsLabel(l.habitsCheckAll));
      await tester.pump();
      expect(_splash, findsNothing);
      expect(_sparks, findsNothing);
      expect(find.text(l.allHabitsDone), findsOneWidget, reason: 'die Meldung kommt trotzdem');
      await tester.pumpAndSettle();
      expect(app.store.tasks.firstWhere((t) => t.title == 'Müll rausbringen').done, isTrue);
      await finishApp(tester, app);
    });
  });
}
