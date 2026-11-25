@Tags(['golden'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';

import 'harness.dart';

/// Ein Screen der App: wie man ihn erreicht und woran man ihn erkennt.
class Screen {
  const Screen(this.name, this.open, {this.syncMode = 'local', this.cloudConfig = false, this.seed = true});
  final String name;
  final Future<void> Function(WidgetTester t, AppLocalizations l) open;
  final String? syncMode;
  final bool cloudConfig;
  final bool seed;
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

final screens = <Screen>[
  Screen('willkommen', (t, l) async => expect(find.text(l.welcome), findsOneWidget), syncMode: null, seed: false),
  Screen(
    'einrichtung',
    (t, l) async {
      await _tap(t, find.text(l.createAccount));
      expect(find.text(l.connectDb), findsWidgets);
    },
    syncMode: null,
    seed: false,
  ),
  Screen(
    'verbinden-konto',
    (t, l) async {
      await _tap(t, find.text(l.haveAccount));
      expect(find.text(l.connectDb), findsWidgets);
    },
    syncMode: null,
    seed: false,
  ),
  Screen(
    'anmeldung',
    (t, l) async => expect(find.text(l.password), findsWidgets),
    syncMode: 'cloud',
    cloudConfig: true,
    seed: false,
  ),
  Screen('aufgaben', (t, l) async => expect(find.text(l.habits), findsWidgets)),
  Screen('aufgaben-leer', (t, l) async => expect(find.text(l.noTasks), findsOneWidget), seed: false),
  Screen('aufgabe-neu', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.newTask).last);
    expect(find.bySemanticsLabel(l.add), findsOneWidget);
  }),
  Screen('spalte-neu', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.moreOptions).first);
    await _tap(t, find.text(l.columns));
    await t.ensureVisible(find.text(l.addColumn));
    await _tap(t, find.text(l.addColumn));
    expect(find.text(l.newColumn), findsOneWidget);
  }),
  Screen('menue', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.moreOptions).first);
    expect(find.text(l.search), findsOneWidget);
    expect(find.text(l.sort), findsOneWidget);
  }),
  Screen('kalender', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.navCalendar));
    expect(find.bySemanticsLabel(l.nextMonth), findsOneWidget);
  }),
  Screen('woche', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.weeklyPlan));
    expect(find.text(l.weekNumber(47)), findsOneWidget);
    expect(find.text('Schule'), findsWidgets);
  }),
  Screen('woche-tag', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.weeklyPlan));
    await _tap(t, find.text('18').first);
    expect(find.bySemanticsLabel(l.backToWeek), findsWidgets);
  }),
  Screen('block-neu', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.weeklyPlan));
    await _tap(t, find.bySemanticsLabel(l.newBlock).last);
    expect(find.text(l.everyWeek), findsOneWidget);
  }),
  Screen('block-ansicht', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.weeklyPlan));
    // In der Tagesansicht: In der schmalen Woche liegen „Training“ und „Lernen“ übereinander.
    await _tap(t, find.text('18').first);
    // Am kleinen Handy liegt 17:30 unterhalb des Bildes.
    await t.ensureVisible(find.text('Lernen').first);
    await t.pumpAndSettle();
    await _tap(t, find.text('Lernen').first);
    expect(find.text('Referat Geschichte'), findsWidgets);
  }),
  Screen('statistik', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.statistics));
    expect(find.text(l.activity), findsOneWidget);
  }),
  Screen('optionen', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.settings));
    expect(find.text(l.appearance), findsOneWidget);
  }),
  Screen('sprache', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.settings));
    await _tap(t, find.text(l.language).last);
    expect(find.text(l.langSameAsDevice), findsOneWidget);
  }),
  Screen('kategorien', (t, l) async {
    await _tap(t, find.bySemanticsLabel(l.settings));
    await _tap(t, find.text(l.categories).last);
    expect(find.text(l.catHomework), findsOneWidget);
  }),
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  // Jeder Screen in Deutsch/Englisch, hell/dunkel und in zwei Größen; Spanisch, Französisch und
  // Italienisch (oft längere Wörter) am kleinen Handy in hell. Ein Überlauf (gelb-schwarze
  // Streifen) oder eine Exception lässt den Test scheitern.
  final variants = [
    for (final lang in ['de', 'en'])
      for (final mode in ['light', 'dark'])
        for (final size in const [Size(412, 915), Size(320, 640)]) (lang, mode, size),
    for (final lang in ['es', 'fr', 'it']) (lang, 'light', const Size(320, 640)),
  ];
  for (final s in screens) {
    for (final (lang, mode, size) in variants) {
      final id = '${s.name}_${size.width.toInt()}_${mode}_$lang';
      testWidgets('Screen $id', (tester) async {
        useFixedClock();
        final l = l10n(lang);
        final app = await makeServices(lang: lang, mode: mode, syncMode: s.syncMode, cloudConfig: s.cloudConfig);
        if (s.seed) seedDemo(app.store, l);
        await pumpApp(tester, app, size: size);
        await s.open(tester, l);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$id.png'));
        await finishApp(tester, app);
      });
    }
  }
}
