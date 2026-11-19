// Wochenplan in der echten App (Windows/Android):
//   flutter test integration_test/week_test.dart -d windows
//
// Datenbank und Einstellungen liegen im Speicher, die Aufgaben sind Beispieldaten –
// echte Daten werden nie berührt.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/theme/tokens.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/widgets/ui.dart';

import '../test/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting());

  for (final mouse in [true, false]) {
    testWidgets('Block lange drücken und ziehen (${mouse ? 'Maus' : 'Finger'}), „+“-Seite übernimmt Aufgaben', (
      tester,
    ) async {
      final l = l10n('de');
      useFixedClock();
      final app = await makeServices();
      app.ensureCategoriesNow(l);
      final cat = app.store.categories.first;
      app.store.addTask(
        title: 'Buch Referat',
        categoryId: cat.id,
        dueDate: addDays(today(), 8),
        dueTime: null,
        subs: [],
      );
      app.store.addBlocks(
        name: 'Lernen',
        color: cat.color,
        days: [wdIndex(today())],
        start: 9 * 60,
        end: 10 * 60,
        repeat: false,
        weekStart: monday(today()),
      );
      if (mouse) {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
      }
      await pumpApp(tester, app, size: mouse ? const Size(1366, 705) : const Size(412, 915));
      await tester.tap(find.bySemanticsLabel(l.weeklyPlan).first);
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.text('Lernen').first);
      final g = await tester.createGesture(
        kind: mouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
        pointer: mouse ? 7101 : 7102,
      );
      if (mouse) {
        await g.addPointer(location: from);
        await tester.pump();
      }
      await g.down(from);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 150));
      // Eine Stunde nach unten, in kleinen Schritten.
      for (var i = 1; i <= 20; i++) {
        await g.moveTo(from + Offset(0, Sizes.hour * i / 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      if (mouse) await g.removePointer();
      await tester.pumpAndSettle();
      final b = app.store.blocks.single;
      expect((b.start, b.end), (10 * 60, 11 * 60));
      expect(tester.takeException(), isNull);

      // Die Meldung „Block verschoben“ verschwindet von selbst (am Handy liegt sie über dem „+“).
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      // Neuer Block → „+“ → Aufgabe wählen → Chip ist ausgewählt.
      await tester.tap(find.bySemanticsLabel(l.newBlock).last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l.addTasksToDay));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buch Referat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.applyCount(1)));
      await tester.pumpAndSettle();
      final chip = find.ancestor(of: find.textContaining('Buch Referat'), matching: find.byType(AppChip));
      expect(tester.widget<AppChip>(chip).selected, isTrue);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });
  }
}
