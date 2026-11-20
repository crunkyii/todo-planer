import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/theme/app_theme.dart';
import 'package:todo_liste/widgets/app_icon.dart';
import 'package:todo_liste/widgets/select.dart';

import 'harness.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  Finder row(String title) => find.widgetWithText(SelectRow<AppMode>, title);
  Finder option(String label) => find.widgetWithText(SelectOption, label);
  AnimatedRotation arrow(WidgetTester t, String title) =>
      t.widget(find.descendant(of: row(title), matching: find.byType(AnimatedRotation)));

  testWidgets('Auswahl-Zeile: zeigt den Wert, öffnet das Menü mit Haken und übernimmt die Wahl', (tester) async {
    final app = await makeServices();
    await pumpApp(tester, app);
    final l = l10n('de');
    await goTab(tester, l.navSettings);

    // Statt Balken: eine Zeile mit Titel und gewähltem Wert; die anderen Werte sind versteckt.
    expect(find.descendant(of: row(l.appearance), matching: find.text(l.light)), findsOneWidget);
    expect(find.text(l.dark), findsNothing);
    expect(arrow(tester, l.appearance).turns, 0);

    await tester.tap(row(l.appearance));
    await tester.pumpAndSettle();
    expect(option(l.light), findsOneWidget);
    expect(option(l.dark), findsOneWidget);
    expect(option(l.system), findsOneWidget);
    // Haken nur beim gewählten Wert, der Pfeil zeigt nach oben.
    expect(find.descendant(of: option(l.light), matching: find.byType(AppIcon)), findsOneWidget);
    expect(find.descendant(of: option(l.dark), matching: find.byType(AppIcon)), findsNothing);
    expect(arrow(tester, l.appearance).turns, 0.5);

    await tester.tap(option(l.dark));
    await tester.pumpAndSettle();
    expect(app.settings.mode, AppMode.dark);
    expect(find.byType(SelectOption), findsNothing);
    expect(find.descendant(of: row(l.appearance), matching: find.text(l.dark)), findsOneWidget);
    expect(arrow(tester, l.appearance).turns, 0);
    await finishApp(tester, app);
  });

  testWidgets('Auswahl-Zeile: Esc schließt das Menü ohne Änderung; Screenreader hört Titel und Wert', (tester) async {
    final app = await makeServices();
    await pumpApp(tester, app);
    final l = l10n('de');
    await goTab(tester, l.navSettings);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('${l.appearance}: ${l.light}'), findsOneWidget);

    await tester.tap(row(l.appearance));
    await tester.pumpAndSettle();
    expect(find.byType(SelectOption), findsNWidgets(3));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SelectOption), findsNothing);
    expect(app.settings.mode, AppMode.light);
    handle.dispose();
    await finishApp(tester, app);
  });

  testWidgets('Auswahl-Zeile mit der Tastatur: Enter öffnet das Menü, Enter auf einem Wert wählt ihn', (tester) async {
    final app = await makeServices();
    await pumpApp(tester, app);
    final l = l10n('de');
    await goTab(tester, l.navSettings);

    Focus.of(tester.element(find.descendant(of: row(l.appearance), matching: find.text(l.light)))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(SelectOption), findsNWidgets(3));

    Focus.of(tester.element(find.descendant(of: option(l.system), matching: find.text(l.system)))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(SelectOption), findsNothing);
    expect(app.settings.mode, AppMode.system);
    await finishApp(tester, app);
  });

  testWidgets('Screenreader: Zeile „Sprache“ nennt die gewählte Sprache', (tester) async {
    final app = await makeServices();
    await pumpApp(tester, app);
    final l = l10n('de');
    await goTab(tester, l.navSettings);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('${l.language}: Deutsch'), findsOneWidget);
    handle.dispose();
    await finishApp(tester, app);
  });

  testWidgets('Auswahl-Zeile: ein langer Wert steht ganz da und wird nicht abgeschnitten', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const long = '2 Tage vorher erledigen';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme('', dark: false),
        home: Scaffold(
          body: SelectRow<int>(
            title: 'Erledigen',
            options: const [(0, 'Am selben Tag'), (2, long)],
            value: 2,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.renderObject<RenderParagraph>(find.text(long));
    expect(text.didExceedMaxLines, isFalse);
  });
}
