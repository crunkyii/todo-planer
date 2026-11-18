// Erzeugt die Bilder im Ordner `screenshots/` fürs README – mit erfundenen Beispiel-Daten,
// ohne Gerät und ohne Datenbank:
//
//   flutter test tool/screenshots/make_screenshots_test.dart --update-goldens
//
// Ohne `--update-goldens` prüft der Lauf nur, ob die Bilder noch zum aktuellen Aussehen passen.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';

import '../../test/harness.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Die Beispiel-Daten der Tests, ohne die Zeile, die nur den Zeilenumbruch prüft – dafür mit
/// einer Notiz, damit man sie auf der Karte sieht.
void _seed(Store store, AppLocalizations l) {
  seedDemo(store, l);
  store.deleteTask(store.tasks.firstWhere((t) => t.title.startsWith('Ein sehr langer Titel')));
  final talk = store.tasks.firstWhere((t) => t.title == 'Referat Geschichte');
  store.updateTask(
    talk,
    title: talk.title,
    categoryId: talk.categoryId,
    dueDate: talk.dueDate,
    dueTime: talk.dueTime,
    subs: [for (final s in talk.subs) (id: s.id, title: s.title)],
    notes: 'Thema: Römisches Reich\n10 Minuten, Handout für alle',
  );
}

typedef _Shot = ({String file, String mode, Future<void> Function(WidgetTester, AppLocalizations) open});

final _shots = <_Shot>[
  (file: 'aufgaben', mode: 'light', open: (t, l) async {}),
  (file: 'aufgaben-dunkel', mode: 'dark', open: (t, l) async {}),
  (file: 'aufgabe-neu', mode: 'light', open: (t, l) => _tap(t, find.bySemanticsLabel(l.newTask).last)),
  (file: 'kalender', mode: 'light', open: (t, l) => _tap(t, find.bySemanticsLabel(l.navCalendar))),
  (file: 'woche', mode: 'light', open: (t, l) => _tap(t, find.bySemanticsLabel(l.weeklyPlan))),
  (file: 'statistik', mode: 'light', open: (t, l) => _tap(t, find.bySemanticsLabel(l.statistics))),
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  for (final s in _shots) {
    testWidgets('Screenshot ${s.file}', (tester) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices(mode: s.mode);
      _seed(app.store, l);
      await pumpApp(tester, app);
      await s.open(tester, l);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../screenshots/${s.file}.png'));
      await finishApp(tester, app);
    });
  }
}
