// Spalten in der echten App (Windows/Android):
//   flutter test integration_test/columns_test.dart -d windows
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
import 'package:todo_liste/screens/movable_section.dart';
import 'package:todo_liste/screens/sheets/columns_sheet.dart';
import 'package:todo_liste/screens/task_card.dart';
import 'package:todo_liste/screens/tasks_board.dart';

import '../test/harness.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Zieht mit Maus oder Finger von [from] nach [to], in kleinen Schritten wie ein Mensch.
Future<TestGesture> _drag(WidgetTester t, Offset from, Offset to, {bool mouse = false}) async {
  final g = mouse
      // Eigene Geräte-Nummer: Die echte Maus am Rechner darf nicht dazwischenfunken.
      ? await t.createGesture(kind: PointerDeviceKind.mouse, pointer: 7001)
      : await t.createGesture(kind: PointerDeviceKind.touch, pointer: 7002);
  if (mouse) {
    await g.addPointer(location: from);
    await t.pump();
  }
  await g.down(from);
  // Am Handy: erst lange drücken.
  if (!mouse) await t.pump(kLongPressTimeout + const Duration(milliseconds: 150));
  for (var i = 1; i <= 20; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 20)!);
    await t.pump(const Duration(milliseconds: 16));
  }
  return g;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting());

  testWidgets('PC: 2, 3 und 4 Spalten, Spalte mit der Maus verschieben', (tester) async {
    final l = l10n('de');
    final app = await makeServices();
    seedDemo(app.store, l);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final size in const [Size(1920, 1009), Size(1366, 705)]) {
      await pumpApp(tester, app, size: size);
      TasksBoard board() => tester.widget<TasksBoard>(find.byType(TasksBoard));
      Finder head(String id) {
        final g = board().groups.firstWhere((g) => g.id == id);
        return find.bySemanticsLabel(l.sectionCount(g.label, g.items.length));
      }

      // Über ⋮ → Spalten jede Anzahl wählen und nachzählen.
      for (final n in [2, 3, 4]) {
        await _tap(tester, find.bySemanticsLabel(l.moreOptions));
        await _tap(tester, find.text(l.columns));
        await _tap(tester, find.descendant(of: find.byType(ColumnsSheet), matching: find.text('$n')));
        await _tap(tester, find.text(l.close));
        final shown = [for (final g in board().groups) head(g.id).hitTestable()].where((f) => f.evaluate().isNotEmpty);
        expect(shown, hasLength(n), reason: '$n Spalten bei $size');
        expect(tester.takeException(), isNull);
      }

      // Erste Spalte auf die dritte ziehen: Schon beim Ziehen rücken die anderen zur Seite.
      final ids = [for (final g in board().groups) g.id];
      final a = ids[0], b = ids[1], c = ids[2];
      Offset title(String id) => tester.getRect(head(id)).topCenter + const Offset(0, 28);
      final g = await _drag(tester, title(a), title(c) + const Offset(0, 200), mouse: true);
      expect(find.byType(TaskCard).evaluate().length, greaterThan(0));
      await tester.pumpAndSettle();
      // Beim Ziehen sieht man die neue Reihenfolge schon – gespeichert ist sie noch nicht.
      // `.first`: die Liste an ihrem Platz, nicht die, die am Zeiger hängt.
      double left(String id) => tester.getRect(head(id).first).left;
      expect(left(b) < left(c) && left(c) < left(a), isTrue, reason: 'beim Ziehen ($size)');
      expect([for (final g in board().groups) g.id].take(3), [a, b, c], reason: 'noch nicht gespeichert ($size)');
      await g.up();
      await g.removePointer();
      await tester.pumpAndSettle();
      expect([for (final g in board().groups) g.id].take(3), [b, c, a], reason: 'nach dem Loslassen ($size)');
      // Danach blättert die Maus wieder.
      expect(tester.widget<PageView>(find.byType(PageView)).physics, isNull);
      expect(tester.takeException(), isNull);
      // Zurück auf die Ausgangsreihenfolge für die nächste Größe.
      app.settings.updateDevice((s) => s.boardOrder = []);
      await tester.pumpAndSettle();
    }
    await finishApp(tester, app);
  });

  testWidgets('Handy: Spalten einstellen und Abschnitt mit langem Druck verschieben', (tester) async {
    final l = l10n('de');
    final app = await makeServices();
    seedDemo(app.store, l);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpApp(tester, app, size: const Size(412, 915));

    // ⋮ → Spalten: „Später“ aus, eine Kategorie als eigener Abschnitt.
    final cat = app.store.categories.first;
    await _tap(tester, find.bySemanticsLabel(l.moreOptions));
    await _tap(tester, find.text(l.columns));
    expect(find.text(l.columnsVisible), findsNothing);
    Finder inSheet(Finder f) => find.descendant(of: find.byType(ColumnsSheet), matching: f);
    await _tap(tester, inSheet(find.bySemanticsLabel(l.later)).last);
    final catSwitch = inSheet(find.bySemanticsLabel(cat.name)).last;
    await tester.ensureVisible(catSwitch);
    await tester.pumpAndSettle();
    await _tap(tester, catSwitch);
    await _tap(tester, find.text(l.close));
    expect(app.settings.boardHidden, {'later'});
    expect(app.settings.boardCats, [cat.id]);
    List<String> ids() => [
      for (final m in tester.widgetList<MovableSection>(find.byType(MovableSection, skipOffstage: false))) m.id,
    ];
    expect(ids(), isNot(contains('later')));
    expect(ids(), contains('k-${cat.id}'));

    // Erste Überschrift lange drücken und unter die zweite ziehen.
    final before = ids();
    final a = before[0], b = before[1];
    Finder head(String id) => find.descendant(
      of: find.byWidgetPredicate((w) => w is MovableSection && w.id == id),
      matching: find.byType(SectionHead),
    );
    final g = await _drag(
      tester,
      tester.getCenter(head(a)),
      tester.getRect(head(b)).bottomCenter + const Offset(0, 24),
    );
    expect(ids().take(2), [b, a], reason: 'schon beim Ziehen');
    await g.up();
    await tester.pumpAndSettle();
    expect(ids().take(2), [b, a]);
    expect(tester.takeException(), isNull);

    // Ein kurzer Tipp klappt weiterhin nur ein und aus, die Liste scrollt normal.
    await _tap(tester, head(b));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(ids().take(2), [b, a], reason: 'Scrollen verschiebt nichts');
    await finishApp(tester, app);
  });
}
