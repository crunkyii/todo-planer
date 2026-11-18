// Zeichnet jeden Tab in typischen PC-Fenstergrößen nach `build/shots/` – zum Durchsehen, wie die App
// am Computer aussieht (erfundene Beispiel-Daten, ohne Gerät und ohne Datenbank):
//
//   flutter test tool/screenshots/desktop_check_test.dart --update-goldens
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';

import '../../test/harness.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

typedef _Shot = ({String file, Future<void> Function(WidgetTester, AppLocalizations) open});

final _shots = <_Shot>[
  (file: 'aufgaben', open: (t, l) async {}),
  (file: 'aufgabe-neu', open: (t, l) => _tap(t, find.bySemanticsLabel(l.newTask).last)),
  (file: 'kalender', open: (t, l) => _tap(t, find.bySemanticsLabel(l.navCalendar))),
  (file: 'woche', open: (t, l) => _tap(t, find.bySemanticsLabel(l.weeklyPlan))),
  (file: 'statistik', open: (t, l) => _tap(t, find.bySemanticsLabel(l.statistics))),
  (file: 'optionen', open: (t, l) => _tap(t, find.bySemanticsLabel(l.settings))),
];

/// Maximiertes Fenster auf Full HD, kleiner Laptop, halber Bildschirm.
const _sizes = {'1920': Size(1920, 1009), '1366': Size(1366, 705), '960': Size(960, 1009)};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  for (final size in _sizes.entries) {
    for (final s in _shots) {
      testWidgets('PC ${size.key} ${s.file}', (tester) async {
        useFixedClock();
        final l = l10n('de');
        final app = await makeServices();
        seedDemo(app.store, l);
        await pumpApp(tester, app, size: size.value);
        await s.open(tester, l);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/${size.key}-${s.file}.png'));
        await finishApp(tester, app);
      });
    }
  }
}
