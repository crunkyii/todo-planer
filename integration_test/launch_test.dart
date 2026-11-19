// Links von außen in der echten Windows-App (Launcher Flick):
//   flutter test integration_test/launch_test.dart -d windows
//
// Die App startet sich selbst ein zweites Mal mit einem `todoplaner://`-Link. Der zweite Start
// findet das offene Fenster (single_instance.cpp), reicht den Link weiter und beendet sich;
// das offene Fenster wechselt den Tab bzw. öffnet das Formular. Daten: Datenbank im Speicher.
//
// Ist das Schema `todoplaner://` in der Registry auf genau dieses Test-Programm eingetragen,
// wird zusätzlich der Weg über Windows geprüft (`start todoplaner://…`, so öffnet Flick Links).
// Sonst wird dieser Teil übersprungen – der Test trägt selbst nichts in die Registry ein. Mit der
// Umgebungsvariable TODO_IT_SCHEME=1 schlägt er stattdessen fehl.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart' show Navigator, Size, debugPrint;
import 'package:todo_liste/screens/calendar_tab.dart';
import 'package:todo_liste/screens/sheets/task_sheet.dart';
import 'package:todo_liste/screens/stats_tab.dart';
import 'package:todo_liste/screens/tasks_tab.dart';
import 'package:todo_liste/screens/week_tab.dart';

import '../test/harness.dart';

/// Startet dieses Programm noch einmal mit [args]; es muss sich gleich wieder beenden.
Future<int> _secondStart(List<String> args) async {
  final p = await Process.start(Platform.resolvedExecutable, args);
  final code = await p.exitCode.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      p.kill();
      return -1;
    },
  );
  return code;
}

Future<void> _until(WidgetTester t, Finder f, String what) async {
  for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsWidgets, reason: 'Zeitüberschreitung: $what');
}

Future<bool> _schemeIsThisApp() async {
  final r = await Process.run('reg', ['query', r'HKCU\Software\Classes\todoplaner\shell\open\command', '/ve']);
  return r.exitCode == 0 && '${r.stdout}'.toLowerCase().contains(Platform.resolvedExecutable.toLowerCase());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting());

  testWidgets('Zweiter Start mit Link → Tab bzw. Formular im offenen Fenster', (tester) async {
    final app = await makeServices();
    seedDemo(app.store, l10n('de'));
    app.launch.attach();
    await pumpApp(tester, app, size: const Size(1280, 800));
    expect(find.byType(TasksTab), findsOneWidget);

    for (final (link, page) in [
      ('todoplaner://tab/kalender', CalendarTab),
      ('todoplaner://tab/Wochenplan', WeekTab),
      ('todoplaner://tab/statistik', StatsTab),
      ('todoplaner://tab/aufgaben?zeile=01%20%C2%B7%20Test', TasksTab),
    ]) {
      final code = await tester.runAsync(() => _secondStart([link]));
      expect(code, 0, reason: 'zweiter Start beendet sich: $link');
      await _until(tester, find.byType(page), link);
    }

    final code = await tester.runAsync(() => _secondStart(['todoplaner://add?title=Max%20Mustermann%20anrufen']));
    expect(code, 0);
    await _until(tester, find.byType(TaskSheet), 'Formular');
    expect(find.text('Max Mustermann anrufen'), findsOneWidget);

    if (await tester.runAsync(_schemeIsThisApp) ?? false) {
      Navigator.of(tester.element(find.byType(TaskSheet))).pop();
      await tester.pumpAndSettle();
      await tester.runAsync(() => Process.run('cmd', ['/c', 'start', '', 'todoplaner://tab/kalender']));
      await _until(tester, find.byType(CalendarTab), 'start todoplaner://tab/kalender');
    } else {
      // Wer das Schema absichtlich eingetragen hat, will nicht, dass der Teil still übersprungen wird.
      expect(
        Platform.environment['TODO_IT_SCHEME'],
        isNull,
        reason: 'todoplaner:// zeigt nicht auf ${Platform.resolvedExecutable}',
      );
      debugPrint('todoplaner:// ist nicht auf dieses Programm eingetragen – Weg über Windows übersprungen.');
    }
    await finishApp(tester, app);
  }, skip: !Platform.isWindows);
}
