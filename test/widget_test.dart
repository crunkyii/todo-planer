import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_liste/app.dart';
import 'package:todo_liste/app_services.dart';
import 'package:todo_liste/data/cloud.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/data/sync_service.dart';
import 'package:todo_liste/screens/shell.dart';
import 'package:todo_liste/services/reminders.dart';

import 'harness.dart' show choose, selectRow;

Future<AppServices> _services({String? syncMode}) async {
  SharedPreferences.setMockInitialValues({
    if (syncMode != null) 'sync.v1': '{"mode":"$syncMode"}',
    'settings.v1': '{"lang":"de"}',
  });
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final store = Store(LocalDb(NativeDatabase.memory()));
  await store.load();
  final cloud = Cloud();
  return AppServices(
    settings: settings,
    store: store,
    cloud: cloud,
    sync: SyncService(store: store, settings: settings, cloud: cloud),
    reminders: Reminders(),
  );
}

Future<void> _pump(WidgetTester tester, AppServices app) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TodoApp(services: app));
  await tester.pumpAndSettle();
}

/// Räumt Timer (Snackbar, Erinnerungen) und die Datenbank auf.
Future<void> _finish(WidgetTester tester, AppServices app) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
  await app.store.refreshPending();
  await app.store.db.close();
  app.dispose(); // u. a. den Mitternachts-Timer beenden
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting());

  testWidgets('Willkommen → „Nur auf diesem Gerät“ öffnet die App mit Standard-Kategorien', (tester) async {
    final app = await _services();
    await _pump(tester, app);
    expect(find.text('Willkommen'), findsOneWidget);

    await tester.tap(find.text('Nur auf diesem Gerät'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Hausübung'), findsOneWidget);
    expect(find.text('Gewohnheiten'), findsWidgets);
    expect(app.settings.syncMode, SyncMode.local);
    await _finish(tester, app);
  });

  testWidgets('Sprache umstellen übersetzt den Willkommen-Bildschirm', (tester) async {
    final app = await _services();
    await _pump(tester, app);
    await choose(tester, selectRow('Sprache · Language'), 'English');
    expect(find.text('Welcome'), findsOneWidget);
    await _finish(tester, app);
  });

  testWidgets('Secret Key wird bei der Einrichtung abgelehnt', (tester) async {
    final app = await _services();
    await _pump(tester, app);
    await tester.tap(find.text('Konto erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Datenbank verbinden'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'https://abcdefgh.supabase.co');
    await tester.enterText(fields.at(1), 'sb_secret_abcdefghijklmnop');
    await tester.ensureVisible(find.text('Verbinden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verbinden'));
    await tester.pumpAndSettle();
    expect(find.text('Das ist der geheime Schlüssel. Bitte den Publishable Key nehmen.'), findsOneWidget);
    await _finish(tester, app);
  });

  testWidgets('Aufgabe über + anlegen, im Formular löschen (Wischen löscht nicht) und abhaken', (tester) async {
    final app = await _services(syncMode: 'local');
    await _pump(tester, app);

    await tester.tap(find.bySemanticsLabel('Neue Aufgabe').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Vokabeln lernen');
    await tester.tap(find.bySemanticsLabel('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('Vokabeln lernen'), findsOneWidget);
    expect(app.store.tasks.single.title, 'Vokabeln lernen');

    // Wischen löscht nicht mehr – gelöscht wird im Formular der Aufgabe.
    await tester.drag(find.text('Vokabeln lernen'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(app.store.tasks, hasLength(1));
    await tester.tap(find.text('Vokabeln lernen'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Aufgabe löschen'));
    await tester.pumpAndSettle();
    expect(app.store.tasks, isEmpty);
    expect(find.text('Rückgängig'), findsOneWidget);
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(app.store.tasks, hasLength(1));

    // Abgehakt wandert sie in den (eingeklappten) Abschnitt „Erledigt“.
    await tester.tap(find.bySemanticsLabel('Erledigt: Vokabeln lernen'));
    await tester.pumpAndSettle();
    expect(app.store.tasks.single.done, isTrue);
    expect(find.text('ERLEDIGT (1)'), findsOneWidget);
    expect(find.text('Vokabeln lernen'), findsNothing);
    await _finish(tester, app);
  });

  testWidgets('Leere Aufgabe zeigt einen Hinweis', (tester) async {
    final app = await _services(syncMode: 'local');
    await _pump(tester, app);
    await tester.tap(find.bySemanticsLabel('Neue Aufgabe').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib ein, was zu tun ist.'), findsOneWidget);
    await _finish(tester, app);
  });

  testWidgets('Alle Tabs lassen sich öffnen', (tester) async {
    final app = await _services(syncMode: 'local');
    app.store.addHabit(name: 'Wasser trinken', color: '#3D9BE9');
    await _pump(tester, app);
    expect(find.text('Wasser trinken'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Kalender'));
    await tester.pumpAndSettle();
    expect(find.text('Nichts fällig.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Wochenplan'));
    await tester.pumpAndSettle();
    expect(find.text('Heute'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Aktivität'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Wasser trinken'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Wasser trinken'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Einstellungen'));
    await tester.pumpAndSettle();
    expect(find.text('Raster (Minuten)'), findsOneWidget);
    await choose(tester, selectRow('Darstellung'), 'Dunkel');
    expect(app.settings.mode, AppMode.dark);
    await _finish(tester, app);
  });
}
