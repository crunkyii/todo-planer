import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_liste/app.dart';
import 'package:todo_liste/app_services.dart';
import 'package:todo_liste/data/cloud.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/data/sync_service.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';
import 'package:todo_liste/services/flick_export.dart';
import 'package:todo_liste/services/reminders.dart';
import 'package:todo_liste/services/updater.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/widgets/select.dart';

/// Fester Zeitpunkt für alle Screen-Tests: Mittwoch, 18. November 2026, 10:30.
final fixedNow = DateTime(2026, 11, 18, 10, 30);

/// Setzt die Uhr der App auf [at] und nach dem Test wieder zurück.
void useFixedClock([DateTime? at]) {
  clock = () => at ?? fixedNow;
  addTearDown(() => clock = DateTime.now);
}

/// Lädt Roboto aus dem Flutter-SDK, damit Texte in Tests echte Breiten haben
/// (ohne das zeichnet der Test-Font jedes Zeichen als gleich breites Kästchen).
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final name in ['regular', 'medium', 'bold', 'light']) {
    final f = File('${dir.path}/roboto-$name.ttf');
    if (f.existsSync()) loader.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

AppLocalizations l10n(String lang) => lookupAppLocalizations(Locale(lang));

/// Dienste mit Datenbank im Speicher. [syncMode] `null` = erster Start (Willkommen).
Future<AppServices> makeServices({
  String lang = 'de',
  String mode = 'light',
  String theme = 'himmel',
  String? syncMode = 'local',
  bool cloudConfig = false,
  LocalDb? db,
  bool keepPrefs = false,
  SyncService Function(Store, SettingsStore, Cloud)? sync,
  Cloud? cloud,
  Updater? updater,
  FlickExport? flick,
  Reminders? reminders,
}) async {
  // keepPrefs: „App neu gestartet“ – die gespeicherten Einstellungen bleiben, wie sie sind.
  if (!keepPrefs) {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({
      if (syncMode != null)
        'sync.v1': cloudConfig
            ? '{"mode":"$syncMode","url":"https://abcdefgh.supabase.co","key":"sb_publishable_test_key_123"}'
            : '{"mode":"$syncMode"}',
      'settings.v1': '{"lang":"$lang","mode":"$mode","theme":"$theme"}',
    });
  }
  final settings = SettingsStore(await SharedPreferences.getInstance());
  final store = Store(db ?? LocalDb(NativeDatabase.memory()));
  await store.load();
  final c = cloud ?? Cloud();
  return AppServices(
    settings: settings,
    store: store,
    cloud: c,
    sync: sync?.call(store, settings, c) ?? SyncService(store: store, settings: settings, cloud: c),
    reminders: reminders ?? Reminders(),
    updater: updater,
    // Sonst hinge es vom PC ab, ob die Optionen den Abschnitt „Flick“ zeigen (nur Windows).
    flick: flick ?? FlickExport.off(),
  );
}

/// Beispiel-Daten wie im Prototyp: Aufgaben in jedem Abschnitt, Unteraufgaben,
/// Gewohnheiten mit Serie, Wochenblöcke und erledigte Aufgaben für die Statistik.
void seedDemo(Store store, AppLocalizations l) {
  final t0 = today();
  store.ensureDefaultCategories([
    (name: l.catHomework, color: '#3D9BE9', offset: 1),
    (name: l.catTask, color: '#34C38F', offset: 0),
    (name: l.catTest, color: '#F07A5F', offset: 2),
    (name: l.catAppointment, color: '#8E7CF0', offset: 0),
  ]);
  final c = store.categories;
  Task add(String title, int cat, int inDays, {int? time, List<({String title, bool done})> subs = const []}) =>
      store.addTask(title: title, categoryId: c[cat].id, dueDate: addDays(t0, inDays), dueTime: time, subs: subs);

  // Erledigte Aufgaben an früheren Tagen (für Heatmap, Balken und Serie)
  final real = clock;
  try {
    for (final (daysAgo, n) in [(9, 1), (6, 2), (5, 1), (3, 4), (2, 2), (1, 3)]) {
      clock = () => addDays(real(), -daysAgo);
      for (var i = 0; i < n; i++) {
        store.toggleTask(add('Alt $daysAgo/$i', (daysAgo + i) % 4, -daysAgo));
      }
    }
  } finally {
    clock = real;
  }

  add('Mathe S. 42 Nr. 3–7', 0, -1);
  add('Müll rausbringen', 1, 0, time: 18 * 60);
  final referat = add(
    'Referat Geschichte',
    0,
    1,
    subs: [(title: 'Quellen suchen', done: true), (title: 'Folien bauen', done: false)],
  );
  add('Englisch-Test', 2, 4);
  add('Zahnarzt', 3, 2, time: 15 * 60 + 30);
  add('Ein sehr langer Titel, der zeigen soll, dass nichts überläuft und sauber umbricht <>&"\'', 1, 9);
  store.toggleTask(add('Zimmer aufräumen', 1, 0));

  for (final (name, color) in [('Wasser', '#3D9BE9'), ('Lesen', '#34C38F'), ('Sport', '#F07A5F')]) {
    store.addHabit(name: name, color: color);
  }
  final h = store.habits;
  for (var d = 1; d <= 5; d++) {
    store.toggleHabitDay(h[0].id, isoDate(addDays(t0, -d)));
    if (d <= 2) store.toggleHabitDay(h[1].id, isoDate(addDays(t0, -d)));
  }
  store.toggleHabitDay(h[0].id, isoDate(t0));

  final ws = monday(t0);
  store.addBlocks(
    name: 'Schule',
    color: '#3D9BE9',
    days: [0, 1, 2, 3, 4],
    start: 8 * 60,
    end: 13 * 60,
    repeat: true,
    weekStart: ws,
  );
  store.addBlocks(
    name: 'Training',
    color: '#34C38F',
    days: [2],
    start: 17 * 60,
    end: 18 * 60 + 30,
    repeat: true,
    weekStart: ws,
  );
  store.addBlocks(
    name: 'Lernen',
    color: '#F07A5F',
    days: [2],
    start: 17 * 60 + 30,
    end: 19 * 60,
    repeat: false,
    weekStart: ws,
    taskId: referat.id,
  );
}

Future<void> pumpApp(
  WidgetTester tester,
  AppServices app, {
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(TodoApp(services: app));
  await tester.pumpAndSettle();
}

/// Räumt Timer (Snackbar, Erinnerungen, Mitternacht) und die Datenbank auf.
Future<void> finishApp(WidgetTester tester, AppServices app, {bool closeDb = true}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
  await app.store.refreshPending();
  if (closeDb) await app.store.db.close();
  app.sync.dispose();
  app.dispose();
}

/// Die Auswahl-Zeile mit diesem Titel bzw. Namen.
Finder selectRow(String title) =>
    find.byWidgetPredicate((w) => w is SelectRow && (w.title == title || w.label == title));

/// Wählt in einer Auswahl-Zeile [option]: Zeile antippen, dann im Menü.
Future<void> choose(WidgetTester tester, Finder row, String option) async {
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(SelectOption, option));
  await tester.pumpAndSettle();
}

/// Wechselt über die Navigation unten in einen Tab.
Future<void> goTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
