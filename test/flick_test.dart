// Anbindung an den Windows-Launcher Flick: Links (`todoplaner://…`), die Liste „heutige
// Aufgaben“ als Ordner und die Shortcuts zum Kopieren.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart' show Scrollable, Size, Transform;
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/screens/calendar_tab.dart';
import 'package:todo_liste/screens/flick_guide_page.dart';
import 'package:todo_liste/screens/settings_tab.dart';
import 'package:todo_liste/screens/sheets/task_sheet.dart';
import 'package:todo_liste/screens/stats_tab.dart';
import 'package:todo_liste/screens/tasks_tab.dart';
import 'package:todo_liste/screens/ui_state.dart';
import 'package:todo_liste/screens/week_tab.dart';
import 'package:todo_liste/services/flick_export.dart';
import 'package:todo_liste/services/launch_commands.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'harness.dart';

/// Was Flick anzeigt: der Name ohne die unsichtbaren Sortierzeichen.
String _visible(String name) => name.replaceAll(RegExp('[​-‍⁠-⁤]'), '');

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
      // Ein Emoji genau an der Grenze wird nicht halbiert.
      final emoji =
          parseLaunchCommand(['todoplaner://add?title=${'a' * (maxLaunchTitle - 1)}%F0%9F%98%80'])! as NewTask;
      expect(emoji.title, 'a' * (maxLaunchTitle - 1));
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
      // Flick hängt bei „Aufgaben“ die gewählte Zeile an (auch die unsichtbare Nummer).
      expect(
        parseLaunchCommand(['todoplaner://tab/aufgaben?zeile=%E2%80%8B%E2%80%8CMathe%20lernen']),
        const OpenTab(AppTab.tasks, row: '​‌Mathe lernen'),
      );
      expect(parseLaunchCommand(['todoplaner://tab/aufgaben?zeile=']), const OpenTab(AppTab.tasks));
      expect(parseLaunchCommand(['todoplaner://tab/kalender?zeile=x']), const OpenTab(AppTab.calendar));
      expect(parseLaunchCommand(['todoplaner://tab/aufgaben?zeile=%E0%A4%A']), const OpenTab(AppTab.tasks));
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
    test('Keine sichtbare Nummer, verbotene Zeichen ersetzt', () {
      expect(_visible(flickFolderName(3, 'Mathe')), 'Mathe');
      expect(flickFolderName(3, 'Mathe').length, 'Mathe'.length + 2, reason: 'zwei unsichtbare Sortierzeichen');
      final n = flickFolderName(1, 'a:b/c\\d*e?f"g<h>i|j\tk\nl');
      expect(_visible(n), 'a∶b∕c∖d∗e？f”g‹h›iǀj k l');
      expect(RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(n), isFalse);
    });

    test('Kein Punkt oder Leerzeichen am Ende, nicht zu lang, kein halbes Emoji', () {
      expect(_visible(flickFolderName(2, 'Referat...  ')), 'Referat');
      final long = flickFolderName(4, '😀' * 100);
      expect(long.length, lessThanOrEqualTo(FlickExport.maxName));
      expect(long.endsWith('…'), isTrue);
      final units = long.codeUnits;
      expect((units[units.length - 2] & 0xFC00) == 0xD800, isFalse, reason: 'halbes Emoji vor „…“');
    });

    test('Die unsichtbare Nummer hält die Reihenfolge – auch bei gleichen Texten und Großbuchstaben', () {
      final names = [for (var i = 0; i < FlickExport.maxEntries; i++) flickFolderName(i, i.isEven ? 'b' : 'A')];
      expect(names.toSet(), hasLength(FlickExport.maxEntries), reason: 'eindeutig');
      // So sortiert Flick: nach Kleinbuchstaben, Zeichen für Zeichen (Codepunkte).
      expect([...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())), names);
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
      expect(rows.map(_visible), [
        'Heute, Mittwoch, 18. November · 3 offen',
        '⚠ Altlast (überfällig)',
        // Ohne Uhrzeit zählt der Beginn des Tages – wie in der App.
        'Vokabeln',
        '14∶00 Max Mustermann anrufen',
      ]);
      // Flick sortiert nach Namen: Die Reihenfolge muss dabei bleiben.
      expect([...rows]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())), rows);

      // Enter auf einer Zeile: die Aufgabe dahinter – auch wenn sich die Nummer inzwischen verschoben hat.
      expect(flickTaskForRow(app.store, l, rows[2])?.title, 'Vokabeln');
      expect(flickTaskForRow(app.store, l, flickFolderName(7, '⚠ Altlast (überfällig)'))?.title, 'Altlast');
      expect(flickTaskForRow(app.store, l, rows[0]), isNull, reason: 'Kopfzeile');
      expect(flickTaskForRow(app.store, l, flickFolderName(1, 'Gibt es nicht')), isNull);
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
      expect(flickTodayEntries(app.store, l).map(_visible), [
        'Today, Wednesday, November 18 · nothing open',
        'Nothing due',
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
      const icons = 'C:/Users/Max Mustermann/AppData/Local/ToDo Planer/Flick/Icons';
      expect(
        toml,
        contains(
          'name = "addAufgabe"\nabout = "Neue Aufgabe im ToDo Planer"\n'
          'icon = "$icons/aufgabe_hinzufuegen.ico"\nopen = "todoplaner://add"',
        ),
      );
      expect(toml, contains('icon = "$icons/aufgaben_anzeigen.ico"\npick = '));
      expect(toml, contains('icon = "$icons/todo_planer_oeffnen.ico"\nchoices = '));
      expect(toml, contains('pick = "C:/Users/Max Mustermann/AppData/Local/ToDo Planer/Flick/Heute"'));
      expect(toml, contains('open = "todoplaner://tab/aufgaben?zeile={name}"'));
      expect(toml, contains('open = "todoplaner://tab/{name}"'));
      // Jeder Link darin versteht die App.
      for (final m in RegExp(r'open = "([^"]+)"').allMatches(toml)) {
        final link = m.group(1)!.replaceAll('{name}', 'Kalender').replaceAll('{arg}', 'x');
        expect(parseLaunchCommand([link]), isNotNull, reason: link);
      }
    });
  });

  test('Vorlage tool/flick/todo-planer.toml passt zu dem, was die App kopiert', () {
    List<String> lines(String s) => [
      for (final line in s.split('\n'))
        if (line.trim().isNotEmpty && !line.startsWith('#')) line.trimRight(),
    ];
    final file = File('tool/flick/todo-planer.toml').readAsStringSync().replaceAll('\r\n', '\n');
    final app = flickShortcuts(l10n('de'), r'C:\Users\DEIN-NAME\AppData\Local\ToDo Planer\Flick\Heute');
    expect(lines(file), lines(app));
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

    testWidgets('Enter auf einer Flick-Zeile: Aufgaben-Tab, Karte im Bild, wird größer und leuchtet', (tester) async {
      useFixedClock();
      final app = await makeServices();
      final l = l10n('de');
      seedDemo(app.store, l);
      await pumpApp(tester, app);
      app.launch.deliver(const OpenTab(AppTab.calendar));
      await tester.pumpAndSettle();

      final rows = flickTodayEntries(app.store, l);
      final task = flickTaskForRow(app.store, l, rows.last)!;
      app.launch.deliver(OpenTab(AppTab.tasks, row: rows.last));
      // Bild für Bild: Tab-Wechsel, Hinscrollen, dann zweimal größer werden.
      double scaleOf(Finder f) => tester
          .widgetList<Transform>(find.ancestor(of: f, matching: find.byType(Transform)))
          .fold(1.0, (m, w) => m * w.transform.getMaxScaleOnAxis());
      var biggest = 1.0;
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final f = find.descendant(of: find.byType(TasksTab), matching: find.text(task.title));
        if (f.evaluate().isNotEmpty) biggest = biggest < scaleOf(f.first) ? scaleOf(f.first) : biggest;
      }
      expect(find.byType(TasksTab), findsOneWidget);
      final title = find.descendant(of: find.byType(TasksTab), matching: find.text(task.title)).first;
      expect(tester.getRect(title).bottom, lessThanOrEqualTo(915), reason: 'Karte ist im Bild');
      expect(biggest, greaterThan(1.04), reason: 'Karte wurde größer');
      await tester.pumpAndSettle();
      final after = tester
          .widgetList<Transform>(find.ancestor(of: find.text(task.title).first, matching: find.byType(Transform)))
          .map((w) => w.transform.getMaxScaleOnAxis());
      expect(after.every((s) => s <= 1.0001), isTrue, reason: 'danach wieder normal groß');
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
      // Die Symbole werden echt geschrieben – dafür muss die Zeit hier echt laufen.
      await tester.runAsync(() async {
        await tester.tap(find.text(l.flickCopy));
        for (var i = 0; i < 100 && copied == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text(l.flickGuideIntro), findsOneWidget);
      expect(copied, contains('pick = "${dir.replaceAll(r'\', '/')}"'));
      for (final i in FlickIcon.values) {
        final f = File('${tmp.path}${Platform.pathSeparator}Icons${Platform.pathSeparator}${i.file}');
        expect(f.lengthSync(), greaterThan(1000), reason: i.file);
        expect(copied, contains('icon = "${f.path.replaceAll(r'\', '/')}"'));
      }
      // Danach geht die Anleitung auf – mit Schritten, Schalter und Beispielen.
      expect(find.byType(FlickGuidePage), findsOneWidget);
      expect(find.text(l.flickStep2), findsOneWidget);
      expect(find.text('addAufgabe'), findsOneWidget);
      expect(find.text('aufgabe …'), findsNothing);
      await tester.tap(find.byWidgetPredicate((w) => w is AppSwitch && w.label == l.flickToday).last);
      await tester.pumpAndSettle();
      expect(app.settings.flick, isFalse, reason: 'Schalter in der Anleitung ist derselbe');
      copied = null;
      await tester.runAsync(() async {
        await tester.tap(find.text(l.flickCopyAgain));
        for (var i = 0; i < 100 && copied == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(copied, contains('addAufgabe'));
      expect(find.text(l.flickCopied), findsOneWidget, reason: 'Knopf zeigt „kopiert“');
      await tester.tap(find.bySemanticsLabel(l.back).last);
      await tester.pumpAndSettle();
      expect(find.byType(FlickGuidePage), findsNothing);
      await finishApp(tester, app);
    });
  });
}
