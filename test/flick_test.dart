// Anbindung an den Windows-Launcher Flick: Links (`todoplaner://…`), die Liste „heutige
// Aufgaben“ als Ordner und die Shortcuts zum Kopieren.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart' show Scrollable, Size;
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/screens/calendar_tab.dart';
import 'package:todo_liste/screens/settings_tab.dart';
import 'package:todo_liste/screens/sheets/task_sheet.dart';
import 'package:todo_liste/screens/stats_tab.dart';
import 'package:todo_liste/screens/ui_state.dart';
import 'package:todo_liste/screens/week_tab.dart';
import 'package:todo_liste/services/flick_export.dart';
import 'package:todo_liste/services/launch_commands.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  group('parseLaunchCommand', () {
    test('Formular „Neue Aufgabe“', () {
      expect(parseLaunchCommand(['todoplaner://add']), const NewTask());
      expect(parseLaunchCommand(['TODOPLANER://Add/']), const NewTask());
      expect(parseLaunchCommand(['todoplaner:add']), const NewTask());
      expect(parseLaunchCommand(['todoplaner://add?title=Mathe%20lernen']), const NewTask(title: 'Mathe lernen'));
      expect(parseLaunchCommand(['todoplaner://add?title=%C3%9Cbung+%26+Test']), const NewTask(title: 'Übung & Test'));
      expect(parseLaunchCommand(['todoplaner://add?title=%20%20']), const NewTask());
      // Kaputte Kodierung: trotzdem das leere Formular.
      expect(parseLaunchCommand(['todoplaner://add?title=%E0%A4%A']), const NewTask());
      final long = parseLaunchCommand(['todoplaner://add?title=${'a' * 500}'])! as NewTask;
      expect(long.title, hasLength(maxLaunchTitle));
    });

    test('Tabs auf Deutsch und Englisch', () {
      const cases = {
        'aufgaben': AppTab.tasks,
        'Kalender': AppTab.calendar,
        'Wochenplan': AppTab.week,
        'woche': AppTab.week,
        'Statistik': AppTab.stats,
        'Optionen': AppTab.settings,
        'settings': AppTab.settings,
      };
      cases.forEach((name, tab) {
        expect(parseLaunchCommand(['todoplaner://tab/$name']), OpenTab(tab), reason: name);
        expect(parseLaunchCommand(['todoplaner://$name']), OpenTab(tab), reason: name);
      });
      // Flick hängt bei „Aufgaben“ die gewählte Zeile an – sie wird nicht gebraucht.
      expect(parseLaunchCommand(['todoplaner://tab/aufgaben?zeile=01%20%C2%B7%20Mathe']), const OpenTab(AppTab.tasks));
    });

    test('Unbekanntes startet die App normal', () {
      expect(parseLaunchCommand([]), isNull);
      expect(parseLaunchCommand(['--verbose', 'https://example.com/add']), isNull);
      expect(parseLaunchCommand(['todoplaner://']), isNull);
      expect(parseLaunchCommand(['todoplaner://tab']), isNull);
      expect(parseLaunchCommand(['todoplaner://tab/garten']), isNull);
      expect(parseLaunchCommand(['todoplaner://delete-all']), isNull);
      // Der erste Link zählt.
      expect(
        parseLaunchCommand(['x', 'todoplaner://tab/kalender', 'todoplaner://add']),
        const OpenTab(AppTab.calendar),
      );
    });

    test('LaunchCommands hebt einen Aufruf auf, bis jemand zuhört', () {
      final launch = LaunchCommands(['todoplaner://tab/statistik']);
      final got = <LaunchCommand>[];
      launch.deliver(const NewTask());
      launch.onCommand = got.add;
      expect(got, [const NewTask()]);
      launch.deliver(const OpenTab(AppTab.week));
      expect(got, [const NewTask(), const OpenTab(AppTab.week)]);
      launch.onCommand = null;
      launch.deliver(const OpenTab(AppTab.tasks));
      launch.onCommand = got.add;
      expect(got.last, const OpenTab(AppTab.tasks));
    });
  });

  group('flickFolderName', () {
    test('Nummer vorne, verbotene Zeichen ersetzt', () {
      expect(flickFolderName(3, 'Mathe'), '03 · Mathe');
      final n = flickFolderName(1, 'a:b/c\\d*e?f"g<h>i|j\tk\nl');
      expect(n, '01 · a∶b∕c∖d∗e？f”g‹h›iǀj k l');
      expect(RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(n), isFalse);
    });

    test('Kein Punkt oder Leerzeichen am Ende, nicht zu lang, kein halbes Emoji', () {
      expect(flickFolderName(2, 'Referat...  '), '02 · Referat');
      final long = flickFolderName(4, '😀' * 100);
      expect(long.length, lessThanOrEqualTo(FlickExport.maxName));
      expect(long.endsWith('…'), isTrue);
      final units = long.codeUnits;
      expect((units[units.length - 2] & 0xFC00) == 0xD800, isFalse, reason: 'halbes Emoji vor „…“');
    });
  });

  group('flickTodayEntries', () {
    test('Heute und überfällig, in der Reihenfolge der App; der Rest nicht', () async {
      useFixedClock();
      final app = await makeServices();
      final l = l10n('de');
      app.store.ensureDefaultCategories([(name: 'Aufgabe', color: '#34C38F', offset: 0)]);
      final cat = app.store.categories.first.id;
      final t0 = today();
      void add(String title, int inDays, {int? time}) =>
          app.store.addTask(title: title, categoryId: cat, dueDate: addDays(t0, inDays), dueTime: time, subs: const []);
      add('Max Mustermann anrufen', 0, time: 14 * 60);
      add('Vokabeln', 0);
      add('Altlast', -2);
      add('Morgen', 1);
      add('Erledigt', 0);
      app.store.toggleTask(app.store.tasks.firstWhere((t) => t.title == 'Erledigt'));

      final rows = flickTodayEntries(app.store, l);
      expect(rows, [
        '00 · Heute, Mittwoch, 18. November · 3 offen',
        '01 · ⚠ Altlast (überfällig)',
        // Ohne Uhrzeit zählt der Beginn des Tages – wie in der App.
        '02 · Vokabeln',
        '03 · 14∶00 Max Mustermann anrufen',
      ]);
      // Flick sortiert nach Namen: Die Reihenfolge muss dabei bleiben.
      expect([...rows]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())), rows);
      await app.store.refreshPending();
      await app.store.db.close();
    });

    test('Nichts fällig; „In Aufgaben zeigen: Nie“ bleibt draußen', () async {
      useFixedClock();
      final app = await makeServices(lang: 'en');
      final l = l10n('en');
      app.store.ensureDefaultCategories([(name: 'Task', color: '#34C38F', offset: 0)]);
      final c = app.store.categories.first;
      app.store.updateCategory(c, name: c.name, color: c.color, offset: c.offset, listFrom: ListFrom.never);
      app.store.addTask(title: 'Hidden', categoryId: c.id, dueDate: today(), dueTime: null, subs: const []);
      expect(flickTodayEntries(app.store, l), [
        '00 · Today, Wednesday, November 18 · nothing open',
        '01 · Nothing due',
      ]);
      await app.store.refreshPending();
      await app.store.db.close();
    });
  });

  group('FlickExport', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('flick_test_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    List<String> folders(Directory d) => d.existsSync()
        ? ([for (final e in d.listSync().whereType<Directory>()) e.path.split(Platform.pathSeparator).last]..sort())
        : [];

    test('legt Ordner an, gleicht ab und räumt beim Ausschalten auf', () async {
      final dir = Directory('${tmp.path}${Platform.pathSeparator}Heute');
      final f = FlickExport(dir: dir.path);
      await f.push(['00 · Kopf', '01 · A', '02 · B']);
      expect(folders(dir), ['00 · Kopf', '01 · A', '02 · B']);

      // Etwas, das nicht von der App ist, bleibt liegen.
      final foreign = Directory('${dir.path}${Platform.pathSeparator}Eigenes')..createSync();
      File('${foreign.path}${Platform.pathSeparator}notiz.txt').writeAsStringSync('x');

      await f.push(['00 · Kopf', '01 · B']);
      expect(folders(dir), ['00 · Kopf', '01 · B', 'Eigenes']);

      await f.push(null);
      expect(folders(dir), ['Eigenes'], reason: 'nur leere Ordner werden gelöscht');
      foreign.deleteSync(recursive: true);

      await f.push(['00 · X']);
      await f.push(null);
      expect(dir.existsSync(), isFalse, reason: 'leerer Ordner verschwindet ganz');
    });

    test('Ausschalten ohne vorheriges Schreiben fasst nichts an', () async {
      final dir = Directory('${tmp.path}${Platform.pathSeparator}Heute')..createSync();
      Directory('${dir.path}${Platform.pathSeparator}01 · Alt').createSync();
      await FlickExport(dir: dir.path).push(null);
      expect(folders(dir), hasLength(1));
    });

    test('Shortcuts für Flick: Pfad mit / und Platzhalter, die Flick verlangt', () {
      final toml = flickShortcuts(l10n('de'), r'C:\Users\Max Mustermann\AppData\Local\ToDo Planer\Flick\Heute');
      expect(toml, contains('name = "addAufgabe"\nabout = "Neue Aufgabe im ToDo Planer"\nopen = "todoplaner://add"'));
      expect(toml, contains('pick = "C:/Users/Max Mustermann/AppData/Local/ToDo Planer/Flick/Heute"'));
      expect(toml, contains('open = "todoplaner://tab/aufgaben?zeile={name}"'));
      expect(toml, contains('open = "todoplaner://tab/{name}"'));
      expect(toml, contains('open = "todoplaner://add?title={arg}"'));
      // Jeder Link darin versteht die App.
      for (final m in RegExp(r'open = "([^"]+)"').allMatches(toml)) {
        final link = m.group(1)!.replaceAll('{name}', 'Kalender').replaceAll('{arg}', 'x');
        expect(parseLaunchCommand([link]), isNotNull, reason: link);
      }
    });
  });

  group('App', () {
    testWidgets('Links wechseln den Tab und öffnen das Formular mit Titel', (tester) async {
      useFixedClock();
      final app = await makeServices();
      seedDemo(app.store, l10n('de'));
      await pumpApp(tester, app);

      for (final (cmd, page) in [
        (const OpenTab(AppTab.calendar), CalendarTab),
        (const OpenTab(AppTab.week), WeekTab),
        (const OpenTab(AppTab.stats), StatsTab),
        (const OpenTab(AppTab.settings), SettingsTab),
      ]) {
        app.launch.deliver(cmd);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget, reason: '$cmd');
      }

      app.launch.deliver(const NewTask(title: 'Referat'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskSheet), findsOneWidget);
      expect(find.text('Referat'), findsOneWidget);
      // Ein zweiter Aufruf öffnet kein zweites Formular darüber.
      app.launch.deliver(const NewTask());
      await tester.pumpAndSettle();
      expect(find.byType(TaskSheet), findsOneWidget);
      expect(app.store.tasks.where((t) => t.title == 'Referat'), isEmpty, reason: 'gespeichert wird erst per Knopf');
      await finishApp(tester, app);
    });

    testWidgets('Ein Aufruf beim Start wartet, bis die App da ist', (tester) async {
      useFixedClock();
      final app = await makeServices(syncMode: null);
      app.launch.deliver(const OpenTab(AppTab.calendar));
      await pumpApp(tester, app);
      final l = l10n('de');
      await tester.tap(find.text(l.setupLocalTitle));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarTab), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('Optionen: Schalter und Shortcuts kopieren', (tester) async {
      useFixedClock();
      final tmp = Directory.systemTemp.createTempSync('flick_app_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dir = '${tmp.path}${Platform.pathSeparator}Heute';
      final app = await makeServices(flick: FlickExport(dir: dir));
      final l = l10n('de');
      seedDemo(app.store, l);
      await pumpApp(tester, app, size: const Size(412, 2000));
      app.launch.deliver(const OpenTab(AppTab.settings));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l.flickCopy),
        300,
        scrollable: find.descendant(of: find.byType(SettingsTab), matching: find.byType(Scrollable)).first,
      );
      await tester.tap(find.byWidgetPredicate((w) => w is AppSwitch && w.label == l.flickToday));
      await tester.pumpAndSettle();
      expect(app.settings.flick, isTrue);
      // Bleibt gespeichert (nur an diesem Gerät).
      expect(app.settings.toRow().containsKey('flick'), isFalse, reason: 'wird nicht synchronisiert');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(find.text(l.flickCopy));
      await tester.pumpAndSettle();
      expect(find.text(l.flickCopied), findsOneWidget);
      expect(copied, contains('pick = "${dir.replaceAll(r'\', '/')}"'));
      await finishApp(tester, app);
    });
  });
}
