// Kompletter Durchlauf in der echten App (Windows/Android):
//   flutter test integration_test -d windows
//
// Die Datenbank liegt in einer temporären Datei, die Einstellungen im Speicher und
// „Supabase“ ist ein nachgebauter Server auf localhost – echte Daten werden nie berührt.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/data/sync_service.dart';
import 'package:todo_liste/screens/login_screen.dart';
import 'package:todo_liste/screens/shell.dart';
import 'package:todo_liste/theme/tokens.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';

import '../test/fake_supabase.dart';
import '../test/harness.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Wartet (mit echter Zeit), bis [done] stimmt – z. B. bis der Sync fertig ist.
Future<void> _until(WidgetTester t, bool Function() done, {String what = ''}) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'Zeitüberschreitung: $what');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting());

  testWidgets('Erster Start → lokal → alle Bereiche → Neustart: Daten sind noch da', (tester) async {
    final dir = Directory.systemTemp.createTempSync('todo_it_');
    final file = File('${dir.path}/test.sqlite');
    var app = await makeServices(lang: 'en', syncMode: null, db: LocalDb(NativeDatabase(file)));
    await pumpApp(tester, app, size: const Size(412, 915));
    final en = l10n('en'), l = l10n('de');

    // Willkommen: Sprache umstellen, „Nur auf diesem Gerät“
    expect(find.text(en.welcome), findsOneWidget);
    await _tap(tester, find.text(en.langDe));
    expect(find.text(l.welcome), findsOneWidget);
    await _tap(tester, find.text(l.setupLocalTitle));
    expect(find.byType(AppShell), findsOneWidget);
    expect(app.store.categories, hasLength(4));

    // Aufgabe mit Unteraufgabe anlegen
    await _tap(tester, find.bySemanticsLabel(l.newTask).last);
    await tester.enterText(find.byType(TextField).first, 'Vokabeln');
    await _tap(tester, find.bySemanticsLabel(l.subtasks));
    await tester.enterText(find.byType(TextField).at(1), 'Seite 1');
    await _tap(tester, find.bySemanticsLabel(l.add));
    expect(find.text('Vokabeln'), findsOneWidget);
    expect(app.store.tasks.single.subs.single.title, 'Seite 1');

    // Bearbeiten
    await _tap(tester, find.text('Vokabeln'));
    await tester.enterText(find.byType(TextField).first, 'Vokabeln lernen');
    await _tap(tester, find.bySemanticsLabel(l.save));
    expect(find.text('Vokabeln lernen'), findsOneWidget);

    // Unteraufgabe und Aufgabe abhaken, wieder öffnen
    await _tap(tester, find.bySemanticsLabel(l.a11yCheckSub('Seite 1')));
    expect(app.store.tasks.single.subs.single.done, isTrue);
    await _tap(tester, find.bySemanticsLabel(l.a11yDone('Vokabeln lernen')));
    expect(app.store.tasks.single.done, isTrue);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Zweite Aufgabe: per Wischen löschen und rückgängig machen
    await _tap(tester, find.bySemanticsLabel(l.newTask).last);
    await tester.enterText(find.byType(TextField).first, 'Wegwischen');
    await _tap(tester, find.bySemanticsLabel(l.add));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Wegwischen'), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(find.text('Wegwischen'), findsNothing);
    await _tap(tester, find.text(l.undo));
    expect(find.text('Wegwischen'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Gewohnheit anlegen und für heute abhaken
    await _tap(tester, find.text(l.habit));
    await tester.enterText(find.byType(TextField).first, 'Wasser');
    await _tap(tester, find.text(l.save));
    await _tap(tester, find.bySemanticsLabel(l.a11yHabitDoneToday('Wasser')));
    expect(app.store.habitDone(app.store.habits.single.id, isoDate(today())), isTrue);

    // Kalender
    await _tap(tester, find.bySemanticsLabel(l.navCalendar));
    await _tap(tester, find.bySemanticsLabel(l.nextMonth));
    await _tap(tester, find.bySemanticsLabel(l.prevMonth));
    // „Hausaufgabe“ ist am nächsten Tag fällig: diesen Tag antippen, dann steht sie unter dem Kalender.
    final due = app.store.tasks.firstWhere((t) => t.title == 'Wegwischen').dueDate;
    expect(dayDiff(due, today()), 1, reason: 'Standard-Kategorie mit „fällig in 1 Tag“');
    await _tap(tester, find.bySemanticsLabel(Fmt(l).dayMonth(due)).first);
    expect(find.text('Wegwischen'), findsOneWidget);

    // Woche: Block anlegen, Tagesansicht und zurück
    await _tap(tester, find.bySemanticsLabel(l.weeklyPlan));
    await _tap(tester, find.bySemanticsLabel(l.newBlock).last);
    await tester.enterText(find.byType(TextField).first, 'Training');
    await _tap(tester, find.text(l.save));
    expect(app.store.blocks.single.name, 'Training');
    await _tap(tester, find.text('${today().day}').first);
    expect(find.bySemanticsLabel(l.backToWeek), findsWidgets);
    await _tap(tester, find.bySemanticsLabel(l.nextDay));
    await _tap(tester, find.bySemanticsLabel(l.prevDay));
    await _tap(tester, find.bySemanticsLabel(l.backToWeek).first);
    await _tap(tester, find.bySemanticsLabel(l.nextWeek));
    await _tap(tester, find.text(l.today));

    // Statistik
    await _tap(tester, find.bySemanticsLabel(l.statistics));
    expect(find.text(l.activity), findsOneWidget);
    expect(find.byKey(const ValueKey('bar-segment')), findsWidgets);
    await _tap(tester, find.text(l.daysRange(30)));

    // Optionen: alle Themes, dunkel, Sprache, Kategorie anlegen
    await _tap(tester, find.bySemanticsLabel(l.settings));
    final themes = find.byType(Scrollable).at(1);
    for (final t in appThemes) {
      final name = find.bySemanticsLabel(RegExp('^${_themeName(l.localeName, t.id)}\$'));
      await tester.scrollUntilVisible(name, 120, scrollable: themes);
      await _tap(tester, name);
      expect(app.settings.theme, t.id);
    }
    await _tap(tester, find.text(l.dark));
    expect(app.settings.mode, AppMode.dark);
    await _tap(tester, find.text(l.langEn));
    expect(find.text(en.appearance), findsOneWidget);
    await _tap(tester, find.text(en.langDe));
    await _tap(tester, find.text(l.categories).last);
    await _tap(tester, find.bySemanticsLabel(l.newCategory).last);
    await tester.enterText(find.byType(TextField).first, 'Referat');
    await _tap(tester, find.text(l.save));
    expect(app.store.categories, hasLength(5));

    // Neustart: neue Dienste auf derselben Datei und denselben Einstellungen
    await finishApp(tester, app);
    app = await makeServices(keepPrefs: true, db: LocalDb(NativeDatabase(file)));
    await pumpApp(tester, app, size: const Size(412, 915));
    expect(find.byType(AppShell), findsOneWidget, reason: 'kein Willkommen mehr');
    expect(app.settings.theme, appThemes.last.id);
    expect(app.settings.mode, AppMode.dark);
    expect(find.text('Wegwischen'), findsOneWidget);
    expect(app.store.categories.map((c) => c.name), contains('Referat'));
    expect(app.store.blocks.single.name, 'Training');
    expect(app.store.habits.single.name, 'Wasser');
    expect(app.store.tasks.firstWhere((t) => t.title == 'Vokabeln lernen').done, isTrue);
    await finishApp(tester, app);
    dir.deleteSync(recursive: true);
  });

  testWidgets('Cloud: Einrichtung prüft Eingaben; angemeldet → offline/online → abmelden', (tester) async {
    final l = l10n('de');

    // Einrichtung: Anleitung in 4 Schritten, „SQL kopieren“ und Eingabeprüfung (ohne Netz)
    var app = await makeServices(syncMode: null);
    await pumpApp(tester, app, size: const Size(412, 915));
    await _tap(tester, find.text(l.setupCloudTitle));
    expect(find.text(l.copySql), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), 'https://abcdefgh.supabase.co');
    await tester.enterText(fields.at(1), 'sb_secret_abcdefghijklmnop');
    await tester.ensureVisible(find.text(l.connect).last);
    await _tap(tester, find.text(l.connect).last);
    expect(find.text(l.errSecretKey), findsOneWidget);
    expect(app.settings.cloud, isNull);
    await finishApp(tester, app);

    // Angemeldet gegen den nachgebauten Server
    final server = await FakeSupabase.start();
    final conn = FakeConnectivity();
    final cloud = FakeCloud(server.url);
    app = await makeServices(
      syncMode: 'cloud',
      cloudConfig: true,
      cloud: cloud,
      sync: (store, settings, c) => SyncService(store: store, settings: settings, cloud: c, connectivity: conn),
    );
    await app.boot(); // wie beim echten Start: Verbindung prüfen, Anmeldung erkennen, erster Abgleich
    await pumpApp(tester, app, size: const Size(412, 915));
    expect(find.byType(AppShell), findsOneWidget);

    Future<void> addTask(String title) async {
      await _tap(tester, find.bySemanticsLabel(l.newTask).last);
      await tester.enterText(find.byType(TextField).first, title);
      await _tap(tester, find.bySemanticsLabel(l.add));
    }

    // Online: Aufgabe landet am Server
    await addTask('Online angelegt');
    await _until(tester, () => server.rows('tasks').length == 1, what: 'erste Aufgabe am Server');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Offline: Toast, lokal gespeichert, nichts am Server
    conn.set(false);
    await tester.pumpAndSettle();
    expect(find.text(l.offlineToast), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await addTask('Offline angelegt');
    expect(find.text('Offline angelegt'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(server.rows('tasks'), hasLength(1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Wieder online: Toast und alles ist oben, ohne Duplikate
    conn.set(true);
    // Gegen localhost ist der Sync so schnell, dass „Wieder online“ gleich von
    // „Alles synchronisiert“ abgelöst werden kann – eine der beiden Meldungen muss da sein.
    await _until(
      tester,
      () => find.textContaining('online').evaluate().isNotEmpty || find.text(l.allSynced).evaluate().isNotEmpty,
      what: 'Meldung nach dem Wieder-online-Gehen',
    );
    await _until(tester, () => server.rows('tasks').length == 2, what: 'Offline-Aufgabe am Server');
    await _until(tester, () => app.store.pending == 0, what: 'Warteschlange leer');
    expect(server.rows('tasks').map((r) => r['title']), unorderedEquals(['Online angelegt', 'Offline angelegt']));
    expect(server.rows('categories'), hasLength(4));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Abmelden führt zur Anmeldung
    await _tap(tester, find.bySemanticsLabel(l.settings));
    await tester.scrollUntilVisible(find.text(l.signOut), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(l.signOut));
    await _until(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, what: 'Anmelde-Bildschirm');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await finishApp(tester, app);
    await server.stop();
  });
}

/// Theme-Namen wie in den ARB-Dateien (Deutsch).
String _themeName(String locale, String id) => const {
  'himmel': 'Himmel',
  'ozean': 'Ozean',
  'mint': 'Mint',
  'wald': 'Wald',
  'sonne': 'Sonne',
  'abendrot': 'Abendrot',
  'beere': 'Beere',
  'lavendel': 'Lavendel',
  'nord': 'Nord',
  'graphit': 'Graphit',
}[id]!;
