import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/data/sync_service.dart';
import 'package:todo_liste/util/dates.dart';

import 'fake_supabase.dart';

/// Ein „Gerät“: eigene lokale Datenbank, eigene Einstellungen, eigener Sync.
class Device {
  Device(this.store, this.settings, this.sync);
  final Store store;
  final SettingsStore settings;
  final SyncService sync;

  static Future<Device> create(FakeSupabase server, {LocalDb? db, String mode = 'cloud'}) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({'sync.v1': '{"mode":"$mode","url":"${server.url}","key":"k"}'});
    final settings = SettingsStore(await SharedPreferences.getInstance());
    final store = Store(db ?? LocalDb(NativeDatabase.memory()));
    await store.load();
    final sync = SyncService(store: store, settings: settings, cloud: FakeCloud(server.url));
    store.onLocalChange = () {};
    return Device(store, settings, sync);
  }

  Future<int> pending() async {
    await store.refreshPending();
    return store.pending;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late FakeSupabase server;
  final devices = <Device>[];

  Future<Device> device({LocalDb? db, String mode = 'cloud'}) async {
    final d = await Device.create(server, db: db, mode: mode);
    devices.add(d);
    return d;
  }

  setUp(() async => server = await FakeSupabase.start());

  tearDown(() async {
    final dbs = <LocalDb>{};
    for (final d in devices) {
      await d.store.refreshPending();
      d.sync.dispose();
      dbs.add(d.store.db);
    }
    for (final db in dbs) {
      await db.close();
    }
    devices.clear();
    await server.stop();
  });

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 3));

  String cat(Device d) {
    if (d.store.categories.isEmpty) {
      d.store.ensureDefaultCategories([(name: 'Aufgabe', color: '#34C38F', offset: 0)]);
    }
    return d.store.categories.first.id;
  }

  test('Offline anlegen, ändern und löschen – online wird alles hochgeladen', () async {
    final a = await device();
    a.sync.online = false;
    final c = cat(a);
    final keep = a.store.addTask(title: 'bleibt', categoryId: c, dueDate: today(), dueTime: 480, subs: const []);
    final gone = a.store.addTask(title: 'weg', categoryId: c, dueDate: today(), dueTime: null, subs: const []);
    a.store.updateTask(keep, title: 'bleibt (neu)', categoryId: c, dueDate: today(), dueTime: 540, subs: const []);
    a.store.deleteTask(gone);

    await a.sync.sync();
    expect(server.rows('tasks'), isEmpty, reason: 'offline darf nichts hochgeladen werden');
    expect(await a.pending(), greaterThan(0));

    a.sync.online = true;
    await a.sync.sync();
    expect(await a.pending(), 0);
    final tasks = {for (final r in server.rows('tasks')) r['id']: r};
    expect(tasks[keep.id]!['title'], 'bleibt (neu)');
    expect(tasks[keep.id]!['deleted'], false);
    expect(tasks[gone.id]!['deleted'], true, reason: 'Gelöschtes bleibt als Grabstein');
    expect(server.rows('categories'), hasLength(1));
  });

  test('Zweites Gerät sieht die Änderungen, wiederholter Abgleich erzeugt keine Duplikate', () async {
    final a = await device();
    final t = a.store.addTask(
      title: 'Mathe <S. 12> & "Ü" 🎉',
      categoryId: cat(a),
      dueDate: today(),
      dueTime: null,
      subs: [(title: 'Teil 1', done: true)],
    );
    a.store.addHabit(name: 'Wasser', color: '#3D9BE9');
    a.store.toggleHabitDay(a.store.habits.single.id, isoDate(today()));
    await a.sync.sync();

    final b = await device();
    await b.sync.sync();
    await b.sync.sync();
    final got = b.store.taskById(t.id)!;
    expect(got.title, 'Mathe <S. 12> & "Ü" 🎉');
    expect(got.subs.single.done, isTrue);
    expect(b.store.tasks, hasLength(1));
    expect(b.store.categories, hasLength(1));
    expect(b.store.habitDone(b.store.habits.single.id, isoDate(today())), isTrue);
    expect(await b.pending(), 0, reason: 'heruntergeladene Zeilen sind nicht „offen“');
    expect(server.rows('tasks'), hasLength(1));
  });

  test('Konflikt: die neueste Änderung gewinnt auf beiden Geräten', () async {
    final a = await device();
    final t = a.store.addTask(title: 'Start', categoryId: cat(a), dueDate: today(), dueTime: null, subs: const []);
    await a.sync.sync();
    final b = await device();
    await b.sync.sync();
    final tb = b.store.taskById(t.id)!;

    // A ändert zuerst (offline), B ändert danach – B ist neuer.
    a.store.updateTask(t, title: 'von A', categoryId: t.categoryId, dueDate: t.dueDate, dueTime: null, subs: const []);
    await tick();
    b.store.updateTask(tb, title: 'von B', categoryId: t.categoryId, dueDate: t.dueDate, dueTime: null, subs: const []);

    // B lädt zuerst hoch, dann kommt A mit dem älteren Stand.
    await b.sync.sync();
    await a.sync.sync();
    await b.sync.sync();
    expect(server.rows('tasks').single['title'], 'von B');
    expect(a.store.taskById(t.id)!.title, 'von B');
    expect(b.store.taskById(t.id)!.title, 'von B');
    expect(await a.pending(), 0);
  });

  test('Löschen auf einem Gerät kommt auf dem anderen an', () async {
    final a = await device();
    final t = a.store.addTask(title: 'x', categoryId: cat(a), dueDate: today(), dueTime: null, subs: const []);
    await a.sync.sync();
    final b = await device();
    await b.sync.sync();
    expect(b.store.tasks, hasLength(1));

    await tick();
    a.store.deleteTask(t);
    await a.sync.sync();
    await b.sync.sync();
    expect(b.store.tasks, isEmpty);
  });

  test('Eine abgelehnte Zeile blockiert die Warteschlange nicht', () async {
    final a = await device();
    final c = cat(a);
    for (final title in ['eins', 'kaputt', 'drei']) {
      a.store.addTask(title: title, categoryId: c, dueDate: today(), dueTime: null, subs: const []);
    }
    server.reject = (table, row) => row['title'] == 'kaputt';
    await a.sync.sync();
    expect(server.rows('tasks').map((r) => r['title']), unorderedEquals(['eins', 'drei']));
    expect(a.sync.rejected, 1);
    expect(await a.pending(), 1);

    // Sobald der Server die Zeile annimmt, geht auch sie durch.
    server.reject = null;
    await a.sync.sync();
    expect(server.rows('tasks'), hasLength(3));
    expect(a.sync.rejected, 0);
    expect(await a.pending(), 0);
  });

  test('Sehr viele Aufgaben: Abruf über mehrere Seiten verliert nichts', () async {
    final a = await device();
    final c = cat(a);
    for (var i = 0; i < 620; i++) {
      a.store.addTask(title: 'Aufgabe $i', categoryId: c, dueDate: today(), dueTime: null, subs: const []);
    }
    await a.sync.sync();
    expect(server.rows('tasks'), hasLength(620));

    final b = await device();
    await b.sync.sync();
    expect(b.store.tasks, hasLength(620));
    expect(server.calls['GET tasks'], greaterThan(1), reason: 'mehr als eine Seite');
  });

  test('Einstellungen werden abgeglichen', () async {
    final a = await device();
    a.settings.update((s) {
      s.theme = 'ozean';
      s.raster = 30;
    });
    await a.sync.sync();
    expect(a.settings.dirty, isFalse);

    final b = await device();
    await b.sync.sync();
    expect(b.settings.theme, 'ozean');
    expect(b.settings.raster, 30);
  });

  test('Server mit älterem schema.sql lehnt die neue Sprache ab: der Rest geht trotzdem durch', () async {
    // Wie der CHECK in schema.sql vor 1.7.0: nur Deutsch und Englisch.
    server.reject = (table, row) => table == 'settings' && !const {null, 'de', 'en'}.contains(row['lang']);
    final a = await device();
    final events = <SyncEvent>[];
    final sub = a.sync.events.listen(events.add);
    final c = cat(a);
    a.store.addTask(title: 'Hausübung', categoryId: c, dueDate: today(), dueTime: null, subs: const []);
    a.settings.update((s) {
      s.lang = 'it';
      s.theme = 'ozean';
    });
    await a.sync.sync();
    expect(server.calls['POST settings'], 2, reason: 'einmal abgelehnt, einmal ohne Sprache');
    await a.sync.sync();
    await a.sync.sync();
    await tick();
    await sub.cancel();
    // Kein erneutes Senden bei jedem Abgleich: Jeder Upload käme per Realtime als Änderung zurück.
    expect(server.calls['POST settings'], 2);

    expect(server.rows('tasks').map((r) => r['title']), ['Hausübung'], reason: 'Aufgaben gehen weiter hoch');
    expect(server.rows('settings').single['theme'], 'ozean');
    expect(server.rows('settings').single.containsKey('lang'), isFalse);
    expect(a.settings.lang, 'it');
    expect(a.settings.dirty, isTrue, reason: 'Sprache kommt nach, sobald die Datenbank sie kennt');
    expect(events.whereType<SchemaOutdated>(), hasLength(1));

    // Nach dem neuen schema.sql geht die Sprache mit der nächsten Änderung (oder dem nächsten
    // Start) hoch.
    server.reject = null;
    a.settings.update((s) => s.raster = 30);
    await a.sync.sync();
    expect(server.rows('settings').single['lang'], 'it');
    expect(server.rows('settings').single['raster'], 30);
    expect(a.settings.dirty, isFalse);
  });

  test('Realtime: das eigene Echo stößt keinen neuen Abgleich an', () async {
    final a = await device();
    a.settings.update((s) => s.theme = 'ozean');
    await a.sync.sync();
    final own = server.rows('settings').single;
    expect(a.sync.bringsNews('settings', own), isFalse, reason: 'eigener Upload');
    final newer = a.settings.updatedAt.add(const Duration(seconds: 1)).toIso8601String();
    expect(a.sync.bringsNews('settings', {...own, 'updated_at': newer}), isTrue, reason: 'anderes Gerät');
    expect(a.sync.bringsNews('settings', {'updated_at': 'kaputt'}), isTrue, reason: 'im Zweifel abgleichen');
    expect(a.sync.bringsNews('settings', const {}), isTrue);

    final t = a.store.addTask(title: 'Referat', categoryId: cat(a), dueDate: today(), dueTime: null, subs: const []);
    await a.sync.sync();
    final row = server.rows('tasks').singleWhere((r) => r['id'] == t.id);
    expect(a.sync.bringsNews('tasks', row), isFalse);
    expect(a.sync.bringsNews('unbekannt', row), isTrue);
  });

  test('Neustart: die Warteschlange überlebt und wird später hochgeladen', () async {
    final db = LocalDb(NativeDatabase.memory());
    final a = await device(db: db);
    a.sync.online = false;
    a.store.addTask(title: 'offline', categoryId: cat(a), dueDate: today(), dueTime: null, subs: const []);
    await a.store.flush();

    final again = await device(db: db); // „App neu gestartet“
    expect(again.store.tasks.single.title, 'offline');
    expect(await again.pending(), greaterThan(0));
    await again.sync.sync();
    expect(server.rows('tasks').single['title'], 'offline');
    expect(await again.pending(), 0);
  });

  test('Ohne Anmeldung wird nichts übertragen', () async {
    final a = await device();
    (a.sync.cloud as FakeCloud).signedIn = false;
    a.store.addTask(title: 'x', categoryId: cat(a), dueDate: today(), dueTime: null, subs: const []);
    await a.sync.sync();
    expect(server.calls, isEmpty);
  });

  group('Ältere erledigte Aufgaben nur online', () {
    /// Legt eine Aufgabe an, die vor [daysAgo] Tagen abgehakt wurde.
    Task oldDone(Device d, String title, {int daysAgo = 10, List<({String title, bool done})> subs = const []}) {
      final real = clock;
      clock = () => real().subtract(Duration(days: daysAgo));
      try {
        final t = d.store.addTask(title: title, categoryId: cat(d), dueDate: today(), dueTime: null, subs: subs);
        d.store.toggleTask(t);
        return t;
      } finally {
        clock = real;
      }
    }

    Future<List<Object?>> localIds(Device d, TableSpec t) async => [for (final r in await d.store.db.all(t)) r['id']];

    List<String> stats(Store s) => [for (final e in s.doneEntries()) '${e.day}|${e.cat}']..sort();

    test('Erst hochgeladen, dann vom Gerät genommen – in Supabase bleibt die Zeile unverändert', () async {
      final a = await device();
      a.sync.online = false;
      final old = oldDone(a, 'alt', subs: [(title: 'Teil', done: true)]);
      final fresh = oldDone(a, 'neu', daysAgo: 2);
      await a.sync.sync();
      expect(await a.store.archiveOldDone(), 0, reason: 'steht noch in der Warteschlange');
      expect(await localIds(a, tasksTable), contains(old.id));

      a.sync.online = true;
      await a.sync.sync();
      expect(await localIds(a, tasksTable), [fresh.id], reason: 'nur die frisch erledigte bleibt');
      expect(await localIds(a, subtasksTable), isEmpty);
      expect(await a.pending(), 0, reason: 'das Auslagern ist kein Löschen und lädt nichts hoch');
      final row = server.rows('tasks').firstWhere((r) => r['id'] == old.id);
      expect(row['deleted'], false);
      expect(row['done'], true);
      expect(server.rows('subtasks').single['deleted'], false);
      final syncedAt = row['synced_at'];

      await a.sync.sync();
      expect(server.rows('tasks').firstWhere((r) => r['id'] == old.id)['synced_at'], syncedAt);
    });

    test('Eine Unteraufgabe in der Warteschlange hält die ganze Aufgabe am Gerät', () async {
      final a = await device();
      final old = oldDone(a, 'alt', subs: [(title: 'Teil', done: false)]);
      await a.sync.sync();
      // Nach dem Abgleich liegt sie nur noch im Speicher; ein Haken holt sie zurück.
      a.store.toggleSub(a.store.taskById(old.id)!.subs.single);
      await a.store.flush();
      expect(await a.store.archiveOldDone(), 0);
      expect(await localIds(a, tasksTable), [old.id]);
      expect(await localIds(a, subtasksTable), hasLength(1));

      await a.sync.sync();
      expect(await localIds(a, tasksTable), isEmpty);
      expect(server.rows('subtasks').single['done'], true);
    });

    test('Nur auf diesem Gerät: nichts wird entfernt', () async {
      final a = await device(mode: 'local');
      final old = oldDone(a, 'alt');
      await a.sync.sync();
      expect(server.calls, isEmpty);
      expect(await localIds(a, tasksTable), [old.id]);
      expect(a.store.tasks.single.id, old.id);
      expect(a.store.olderWaiting(), 0);
    });

    test('Statistik ist vor und nach dem Auslagern gleich – auch nach einem Neustart', () async {
      final db = LocalDb(NativeDatabase.memory());
      final a = await device(db: db);
      oldDone(a, 'a', daysAgo: 30);
      oldDone(a, 'b', daysAgo: 9);
      oldDone(a, 'c', daysAgo: 9);
      oldDone(a, 'd', daysAgo: 1);
      a.store.deleteTask(oldDone(a, 'gelöscht', daysAgo: 12)); // zählt weiter mit
      final before = stats(a.store);
      expect(before, hasLength(5));

      await a.sync.sync();
      expect(await localIds(a, tasksTable), hasLength(1));
      expect(stats(a.store), before);

      final again = await device(db: db); // „App neu gestartet“
      expect(again.store.tasks.map((t) => t.title), ['d']);
      expect(stats(again.store), before);
      expect(again.store.olderWaiting(), 3, reason: 'die gelöschte zählt nur für die Statistik');
    });

    test('Der Abruf bringt ausgelagerte Zeilen nicht zurück', () async {
      final a = await device();
      final old = oldDone(a, 'alt', subs: [(title: 'Teil', done: true)]);
      await a.sync.sync();
      final before = stats(a.store);

      await a.settings.resetCursors(); // alles noch einmal vom Server
      await a.sync.sync();
      expect(await localIds(a, tasksTable), isEmpty);
      expect(await localIds(a, subtasksTable), isEmpty);
      expect(stats(a.store), before);

      final again = Store(a.store.db);
      await again.load();
      expect(again.taskById(old.id), isNull);
      expect(again.olderWaiting(), 1);
    });

    test('Erstes Anmelden mit vielen alten Erledigten: nur der Zähler kommt aufs Gerät', () async {
      final a = await device();
      final c = cat(a);
      a.store.addTask(title: 'offen', categoryId: c, dueDate: today(), dueTime: null, subs: const []);
      await a.sync.sync();
      // 620 alte erledigte Aufgaben liegen schon am Server (drei davon mit Unteraufgabe).
      final olds = [
        for (var i = 0; i < 620; i++)
          () {
            final at = nowUtc().subtract(Duration(days: 8 + i % 40));
            return Task(
              id: newId(),
              title: 'Alt $i',
              categoryId: c,
              dueDate: today(),
              dueTime: null,
              done: true,
              doneAt: at,
              createdAt: at,
              updatedAt: at,
            );
          }(),
      ];
      server.seed('tasks', [for (final t in olds) t.toJson()]);
      server.seed('subtasks', [
        for (final t in olds.take(3))
          Subtask(id: newId(), taskId: t.id, title: 'Teil', done: true, position: 0, updatedAt: t.updatedAt).toJson(),
      ]);
      final expected = [for (final t in olds) '${isoDate(t.doneAt!.toLocal())}|$c']..sort();

      final b = await device();
      await b.sync.sync();
      expect(server.calls['GET tasks'], greaterThan(2), reason: 'mehr als eine Seite');
      expect(await localIds(b, tasksTable), hasLength(1));
      expect(await localIds(b, subtasksTable), isEmpty);
      expect(b.store.tasks.single.title, 'offen');
      expect(stats(b.store), expected);
      expect(b.store.olderWaiting(), 620);

      // Nachladen geht seitenweise und nur in den Speicher.
      expect(await b.sync.loadOlderDone(), isTrue);
      expect(b.store.tasksWithOlder, hasLength(1 + SyncService.olderPage));
      expect(b.store.olderWaiting(), 620 - SyncService.olderPage);
      expect(await localIds(b, tasksTable), hasLength(1));
      // Für den Export: alle übrigen, ohne sie in die Liste zu laden.
      final rest = (await b.sync.fetchOlderDone())!;
      expect(rest, hasLength(620 - SyncService.olderPage));
      expect(b.store.tasksWithOlder, hasLength(1 + SyncService.olderPage));
      expect([...b.store.tasksWithOlder, ...rest].where((t) => t.subs.isNotEmpty), hasLength(3));
      expect(b.store.olderWaiting(), 620 - SyncService.olderPage);
      expect(stats(b.store), expected);
    });

    test('Nachladen nach Kategorie und nach Abgabetag', () async {
      final a = await device();
      final first = cat(a);
      a.store.addCategory(name: 'Zweite', color: '#F07A5F', offset: 0);
      final second = a.store.categories.last.id;
      oldDone(a, 'eins');
      final real = clock;
      clock = () => real().subtract(const Duration(days: 20));
      final two = a.store.addTask(title: 'zwei', categoryId: second, dueDate: today(), dueTime: null, subs: const []);
      a.store.toggleTask(two);
      clock = real;
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();

      expect(b.store.olderWaiting(categoryId: first), 1);
      expect(b.store.olderWaiting(dueDay: isoDate(two.dueDate)), 1);
      expect(await b.sync.loadOlderDone(dueDay: isoDate(two.dueDate)), isTrue);
      expect(b.store.tasksWithOlder.map((t) => t.title), ['zwei']);
      expect(b.store.olderWaiting(), 1);
    });

    test('Unteraufgabe einer ausgelagerten Aufgabe abhaken, nachdem der Abruf sie noch einmal brachte', () async {
      final a = await device();
      final t = oldDone(a, 'alt', subs: [(title: 'Teil', done: true)]);
      await a.sync.sync(); // ausgelagert, bleibt bis zum Ende der Sitzung zu sehen
      await a.sync.sync(); // der Abruf bringt die Zeile im Überlappungsfenster noch einmal
      final sub = a.store.tasksWithOlder.single.subs.single;
      await tick();
      a.store.toggleSub(sub);
      await a.sync.sync();

      expect(server.rows('subtasks').single['done'], false);
      expect(a.store.taskById(t.id)!.subs.single.done, false);
      expect(await a.pending(), 0);
      final b = await device();
      await b.sync.sync();
      expect(await b.sync.loadOlderDone(), isTrue);
      expect(b.store.taskById(t.id)!.subs.single.done, false);
    });

    test('Kategorie gelöscht: ihre älteren erledigten Aufgaben zählen zur Ersatz-Kategorie', () async {
      final a = await device();
      final first = cat(a);
      a.store.addCategory(name: 'Zweite', color: '#F07A5F', offset: 0);
      oldDone(a, 'alt');
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      final other = b.store.categories.firstWhere((c) => c.id != first);
      b.store.deleteCategory(b.store.categories.firstWhere((c) => c.id == first));
      expect(b.store.olderWaiting(categoryId: other.id), 1);
    });

    test('Nachladen während eines Abgleichs: wartet und zeigt den Stand danach', () async {
      final a = await device();
      final t = oldDone(a, 'alt');
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      await tick();
      // A ändert die Notiz – die Aufgabe bleibt alt erledigt. B gleicht ab und lädt zugleich nach.
      a.store.updateTask(
        a.store.taskById(t.id)!,
        title: 'alt',
        categoryId: t.categoryId,
        dueDate: t.dueDate,
        dueTime: null,
        subs: const [],
        notes: 'neu',
      );
      await a.sync.sync();
      final running = b.sync.sync();
      expect(await b.sync.loadOlderDone(), isTrue);
      await running;
      expect(b.store.taskById(t.id)!.notes, 'neu');
      expect(await localIds(b, tasksTable), isEmpty);
    });

    test('Offline oder Server nicht erreichbar: Nachladen meldet den Fehler, nichts geht verloren', () async {
      final a = await device();
      oldDone(a, 'alt');
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();

      b.sync.online = false;
      expect(b.sync.canLoadOlder, isFalse);
      expect(await b.sync.loadOlderDone(), isFalse);
      b.sync.online = true;
      server.failReads = true;
      expect(await b.sync.loadOlderDone(), isFalse);
      expect(await b.sync.fetchOlderDone(), isNull);
      expect(b.store.olderWaiting(), 1);
      server.failReads = false;
      expect(await b.sync.loadOlderDone(), isTrue);
      expect(b.store.olderWaiting(), 0);
    });

    test('Wieder öffnen: die alte Aufgabe liegt wieder am Gerät und wird normal abgeglichen', () async {
      final a = await device();
      final old = oldDone(a, 'alt', subs: [(title: 'Teil', done: true)]);
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      expect(b.store.taskById(old.id), isNull);
      await b.sync.loadOlderDone();
      final loaded = b.store.taskById(old.id)!;
      expect(loaded.subs.single.title, 'Teil');
      expect(stats(b.store), hasLength(1));

      await tick();
      b.store.toggleTask(loaded);
      expect(b.store.tasks.single.done, isFalse);
      expect(stats(b.store), isEmpty, reason: 'wieder offen: zählt nicht mehr als erledigt');
      await b.store.flush();
      expect(await localIds(b, tasksTable), [old.id]);
      expect(await localIds(b, subtasksTable), hasLength(1));

      await b.sync.sync();
      expect(server.rows('tasks').single['done'], false);
      expect(await localIds(b, tasksTable), [old.id], reason: 'offen: bleibt am Gerät');

      // Gerät A hatte sie ausgelagert und bekommt sie samt Unteraufgabe zurück.
      await a.sync.sync();
      final back = a.store.tasks.single;
      expect(back.done, isFalse);
      expect(back.subs.single.title, 'Teil');
      expect(stats(a.store), isEmpty);
      expect(await localIds(a, subtasksTable), hasLength(1));
      final again = Store(a.store.db);
      await again.load();
      expect(again.olderWaiting(), 0);
      expect(again.tasks.single.subs, hasLength(1));
    });

    test('Bearbeiten und Löschen einer nachgeladenen Aufgabe kommen am Server an', () async {
      final a = await device();
      final one = oldDone(a, 'eins');
      final two = oldDone(a, 'zwei');
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      await b.sync.loadOlderDone();
      await tick();
      final t = b.store.taskById(one.id)!;
      b.store.updateTask(t, title: 'eins (neu)', categoryId: t.categoryId, dueDate: t.dueDate, dueTime: 600, subs: []);
      expect(b.store.clearDone()!.count, 2, reason: '„Erledigte löschen“ nimmt auch die nachgeladenen');
      final before = stats(b.store);
      expect(before, hasLength(2), reason: 'gelöschte erledigte zählen weiter');
      await b.sync.sync();

      final rows = {for (final r in server.rows('tasks')) r['id']: r};
      expect(rows[one.id]!['title'], 'eins (neu)');
      expect(rows[one.id]!['deleted'], true);
      expect(rows[two.id]!['deleted'], true);
      expect(await localIds(b, tasksTable), isEmpty, reason: 'hochgeladen und wieder ausgelagert');
      expect(stats(b.store), before);
      expect(b.store.tasksWithOlder, isEmpty);
      expect(b.store.olderWaiting(), 0);

      // Gerät A erfährt vom Löschen: nichts mehr zum Nachladen, Statistik bleibt.
      await a.sync.sync();
      expect(a.store.tasksWithOlder, isEmpty);
      expect(a.store.olderWaiting(), 0);
      expect(stats(a.store), hasLength(2));
    });

    test('Jährliche Aufgabe: alte wieder öffnen legt nichts an und löscht nichts', () async {
      final a = await device();
      final old = oldDone(a, 'Max Mustermanns Geburtstag', daysAgo: 20);
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      expect(b.store.tasks.single.done, isFalse, reason: 'die Aufgabe fürs nächste Jahr');
      await b.sync.loadOlderDone();
      b.store.toggleTask(b.store.taskById(old.id)!);
      expect(b.store.tasks, hasLength(2));
      expect(b.store.tasks.every((t) => !t.done), isTrue);
    });

    test('Kontowechsel: Merkzettel werden mit den übrigen Daten verworfen', () async {
      final a = await device();
      oldDone(a, 'alt');
      await a.sync.sync();
      expect(stats(a.store), hasLength(1));
      await a.store.wipe();
      expect(stats(a.store), isEmpty);
      final again = Store(a.store.db);
      await again.load();
      expect(again.doneEntries(), isEmpty);
      expect(again.olderWaiting(), 0);
    });
  });
  group('Feldweise zusammenführen', () {
    Task add(Device d, String title, {List<({String title, bool done})> subs = const []}) =>
        d.store.addTask(title: title, categoryId: cat(d), dueDate: today(), dueTime: null, subs: subs);

    /// Ändert nur die genannten Felder – wie das Bearbeiten-Formular, das alle Felder speichert.
    void edit(Device d, Task t, {String? title, DateTime? dueDate, int? dueTime, String? notes}) => d.store.updateTask(
      t,
      title: title ?? t.title,
      categoryId: t.categoryId,
      dueDate: dueDate ?? t.dueDate,
      dueTime: dueTime ?? t.dueTime,
      subs: [for (final s in t.subs) (id: s.id, title: s.title)],
      notes: notes,
    );

    /// Zwei Geräte mit derselben Aufgabe; danach ändern beide, ohne voneinander zu wissen.
    Future<(Device, Device, Task, Task)> pair({List<({String title, bool done})> subs = const []}) async {
      final a = await device();
      final t = add(a, 'Start', subs: subs);
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      await tick();
      return (a, b, t, b.store.taskById(t.id)!);
    }

    /// Gleicht in der gegebenen Reihenfolge ab, bis beide Geräte alles haben.
    Future<void> settle(Device first, Device second) async {
      await first.sync.sync();
      await second.sync.sync();
      await first.sync.sync();
    }

    Map<String, Object?> serverTask(String id) => server.rows('tasks').firstWhere((r) => r['id'] == id);

    for (final aFirst in [true, false]) {
      final order = aFirst ? 'A lädt zuerst hoch' : 'B lädt zuerst hoch';

      test('Titel am einen, Datum am anderen Gerät: beide Änderungen bleiben ($order)', () async {
        final (a, b, ta, tb) = await pair();
        final due = addDays(today(), 3);
        edit(a, ta, title: 'Neuer Titel');
        await tick();
        edit(b, tb, dueDate: due, dueTime: 600);
        await settle(aFirst ? a : b, aFirst ? b : a);

        final row = serverTask(ta.id);
        expect(row['title'], 'Neuer Titel');
        expect(row['due_date'], isoDate(due));
        expect(row['due_time'], '10:00');
        for (final d in [a, b]) {
          final t = d.store.taskById(ta.id)!;
          expect((t.title, t.dueDate, t.dueTime), ('Neuer Titel', due, 600));
          expect(await d.pending(), 0);
          // Auch nach einem Neustart.
          final again = Store(d.store.db);
          await again.load();
          expect(again.taskById(ta.id)!.title, 'Neuer Titel');
          expect(again.taskById(ta.id)!.dueDate, due);
        }
      });

      test('Dasselbe Feld auf beiden Geräten: der neuere Wert gewinnt ($order)', () async {
        final (a, b, ta, tb) = await pair();
        edit(a, ta, title: 'von A (älter)', notes: 'Notiz von A');
        await tick();
        edit(b, tb, title: 'von B (neuer)');
        await settle(aFirst ? a : b, aFirst ? b : a);

        expect(serverTask(ta.id)['title'], 'von B (neuer)');
        expect(serverTask(ta.id)['notes'], 'Notiz von A', reason: 'die Notiz hat nur A geändert');
        for (final d in [a, b]) {
          expect(d.store.taskById(ta.id)!.title, 'von B (neuer)');
          expect(d.store.taskById(ta.id)!.notes, 'Notiz von A');
          expect(await d.pending(), 0);
        }
      });

      test('Löschen gegen Bearbeiten: gelöscht bleibt gelöscht, die Änderung geht nicht verloren ($order)', () async {
        final (a, b, ta, tb) = await pair();
        a.store.deleteTask(ta);
        await tick();
        edit(b, tb, title: 'noch schnell geändert');
        await settle(aFirst ? a : b, aFirst ? b : a);

        expect(serverTask(ta.id)['deleted'], true);
        expect(serverTask(ta.id)['title'], 'noch schnell geändert');
        expect(a.store.tasks, isEmpty);
        expect(b.store.tasks, isEmpty);
      });

      test('Abhaken am einen, Kategorie am anderen Gerät: erledigt samt Zeitpunkt bleibt ($order)', () async {
        final (a, b, ta, tb) = await pair();
        b.store.addCategory(name: 'Zweite', color: '#F07A5F', offset: 0);
        final second = b.store.categories.last.id;
        a.store.toggleTask(ta);
        await tick();
        b.store.updateTask(tb, title: tb.title, categoryId: second, dueDate: tb.dueDate, dueTime: null, subs: const []);
        await settle(aFirst ? a : b, aFirst ? b : a);
        await a.sync.sync();

        final row = serverTask(ta.id);
        expect(row['done'], true);
        expect(DateTime.parse(row['done_at'] as String), ta.doneAt);
        expect(row['category_id'], second);
        for (final d in [a, b]) {
          final t = d.store.taskById(ta.id)!;
          expect((t.done, t.doneAt, t.categoryId), (true, ta.doneAt, second));
        }
      });
    }

    test('Unteraufgabe: Haken am einen, neuer Text am anderen Gerät', () async {
      final (a, b, ta, tb) = await pair(subs: [(title: 'Teil', done: false)]);
      a.store.toggleSub(ta.subs.single);
      await tick();
      b.store.updateTask(
        tb,
        title: tb.title,
        categoryId: tb.categoryId,
        dueDate: tb.dueDate,
        dueTime: null,
        subs: [(id: tb.subs.single.id, title: 'Teil (genauer)')],
      );
      await settle(b, a);
      for (final d in [a, b]) {
        final s = d.store.taskById(ta.id)!.subs.single;
        expect((s.title, s.done), ('Teil (genauer)', true));
      }
    });

    test('Kategorie und Wochenblock: Name am einen, Rest am anderen Gerät', () async {
      final a = await device();
      cat(a);
      a.store.addBlocks(
        name: 'Schule',
        color: '#3D9BE9',
        days: [0],
        start: 480,
        end: 780,
        repeat: true,
        weekStart: today(),
      );
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      await tick();
      final ca = a.store.categories.single, cb = b.store.categories.single;
      a.store.updateCategory(ca, name: 'Umbenannt', color: ca.color, offset: ca.offset);
      a.store.updateBlock(
        a.store.blocks.single,
        name: 'Uni',
        color: '#3D9BE9',
        day: 0,
        start: 480,
        end: 780,
        repeat: true,
        weekStart: today(),
      );
      await tick();
      b.store.updateCategory(cb, name: cb.name, color: cb.color, offset: 3, listFrom: ListFrom.week);
      b.store.updateBlock(
        b.store.blocks.single,
        name: 'Schule',
        color: '#3D9BE9',
        day: 2,
        start: 540,
        end: 840,
        repeat: true,
        weekStart: today(),
      );
      await settle(a, b);
      for (final d in [a, b]) {
        final c = d.store.categories.single;
        expect((c.name, c.offset, c.listFrom), ('Umbenannt', 3, ListFrom.week));
        final w = d.store.blocks.single;
        expect((w.name, w.day, w.start, w.end), ('Uni', 2, 540, 840));
      }
    });

    test('Zeile ohne Feld-Zeitstempel: die ganze Zeile mit dem neueren Stand gewinnt', () async {
      final a = await device();
      final t = add(a, 'Start');
      await a.sync.sync();
      // Wie von einer älteren App-Version hochgeladen: neuer, aber ohne field_times.
      final later = nowUtc().add(const Duration(minutes: 1)).toIso8601String();
      server.put('tasks', {'id': t.id, 'title': 'alte App', 'due_date': '2026-12-24', 'updated_at': later});
      expect(serverTask(t.id)['field_times'], isNull, reason: 'die Zeitstempel passen nicht mehr zur Zeile');

      // Lokal inzwischen etwas anderes geändert – aber früher: verliert als Ganzes.
      edit(a, t, notes: 'geht verloren');
      await a.sync.sync();
      expect(serverTask(t.id)['title'], 'alte App');
      expect(serverTask(t.id)['notes'], '');
      final got = a.store.taskById(t.id)!;
      expect((got.title, got.notes, isoDate(got.dueDate)), ('alte App', '', '2026-12-24'));
      expect(await a.pending(), 0);

      // Ein älterer Stand ohne Zeitstempel überschreibt nichts.
      server.put('tasks', {'id': t.id, 'title': 'uralt', 'updated_at': t.createdAt.toIso8601String()});
      expect(serverTask(t.id)['title'], 'alte App');

      // Die nächste Änderung der neuen App bekommt wieder Zeitstempel und gewinnt.
      a.sync.online = false;
      clock = () => DateTime.now().add(const Duration(minutes: 2));
      addTearDown(() => clock = DateTime.now);
      edit(a, a.store.taskById(t.id)!, title: 'neue App');
      a.sync.online = true;
      await a.sync.sync();
      expect(serverTask(t.id)['title'], 'neue App');
      expect(serverTask(t.id)['due_date'], '2026-12-24');
      expect(serverTask(t.id)['field_times'], isA<Map<String, Object?>>());
    });

    test('Zeilen von vor dem Update (ohne Zeitstempel am Gerät) werden normal weiter abgeglichen', () async {
      final db = LocalDb(NativeDatabase.memory());
      final a = await device(db: db);
      final t = add(a, 'Start');
      await a.sync.sync();
      // Stand wie vor dem Update: am Gerät und am Server ohne field_times.
      await a.store.flush();
      await db.customStatement('UPDATE tasks SET field_times = NULL');
      serverTask(t.id)['field_times'] = null;

      final again = await device(db: db);
      await tick();
      edit(again, again.store.taskById(t.id)!, title: 'nach dem Update');
      await again.sync.sync();
      expect(serverTask(t.id)['title'], 'nach dem Update');
      final times = serverTask(t.id)['field_times'] as Map;
      expect(times.keys, unorderedEquals(tasksTable.groups.keys));
      expect(times['title'], serverTask(t.id)['updated_at']);
      expect(times['due'], isNot(times['title']), reason: 'nur der Titel wurde geändert');
    });

    test('Server mit älterem schema.sql: es geht ohne field_times weiter, einmal mit Hinweis', () async {
      server.knowsFieldTimes = false;
      final a = await device();
      final events = <SyncEvent>[];
      final sub = a.sync.events.listen(events.add);
      final t = add(a, 'Start');
      await a.sync.sync();
      await tick();
      edit(a, t, title: 'geändert');
      await a.sync.sync();
      await tick();
      await sub.cancel();

      expect(serverTask(t.id)['title'], 'geändert');
      expect(serverTask(t.id).containsKey('field_times'), isFalse);
      expect(await a.pending(), 0);
      expect(a.sync.rejected, 0);
      expect(events.whereType<SchemaOutdated>(), hasLength(1));
    });

    test('Server ohne week_blocks.task_id: Blöcke gehen ohne die Aufgabe hoch', () async {
      server.unknownColumns.add('task_id');
      final a = await device();
      final t = add(a, 'Referat');
      a.store.addBlocks(
        name: 'Referat',
        color: '#3D9BE9',
        days: [0],
        start: 480,
        end: 540,
        repeat: false,
        weekStart: today(),
        taskId: t.id,
      );
      await a.sync.sync();
      final row = server.tables['week_blocks']!.single;
      expect(row.containsKey('task_id'), isFalse);
      expect(await a.pending(), 0);
      expect(a.sync.rejected, 0);
      // Am Gerät bleibt die Verbindung zur Aufgabe.
      expect(a.store.blocks.single.taskId, t.id);
    });

    test('Benachrichtigung kommt an und verträgt sich mit einem neuen Titel vom anderen Gerät', () async {
      final (a, b, ta, tb) = await pair();
      a.store.updateTask(
        ta,
        title: ta.title,
        categoryId: ta.categoryId,
        dueDate: ta.dueDate,
        dueTime: null,
        subs: const [],
        remind: 30,
      );
      await tick();
      edit(b, tb, title: 'Neuer Titel');
      await a.sync.sync();
      await b.sync.sync();
      await a.sync.sync();
      for (final d in [a, b]) {
        final t = d.store.tasks.single;
        expect((t.title, t.remind), ('Neuer Titel', 30));
      }
      expect(serverTask(ta.id)['remind_min'], 30);
    });

    test('Server ohne remind_min: die Benachrichtigung bleibt am Gerät, der Rest geht hoch', () async {
      server.unknownColumns.add('remind_min');
      final a = await device();
      final t = a.store.addTask(
        title: 'Arzt',
        categoryId: cat(a),
        dueDate: today(),
        dueTime: 600,
        remind: 30,
        subs: const [],
      );
      await a.sync.sync();
      await a.sync.sync();
      expect(serverTask(t.id)['title'], 'Arzt');
      expect(await a.pending(), 0);
      expect(a.sync.rejected, 0);
      expect(a.store.taskById(t.id)!.remind, 30);
    });

    test('Block aus einer Aufgabe: die Verbindung kommt auf dem anderen Gerät an', () async {
      final a = await device();
      final t = add(a, 'Referat');
      a.store.addBlocks(
        name: 'Referat',
        color: '#3D9BE9',
        days: [0],
        start: 480,
        end: 540,
        repeat: true,
        weekStart: today(),
        taskId: t.id,
      );
      await a.sync.sync();
      final b = await device();
      await b.sync.sync();
      expect(b.store.blocks.single.taskId, t.id);
    });

    test('Speichern ohne Änderung lässt Zeitstempel und updated_at, wie sie sind', () async {
      final a = await device();
      final t = add(a, 'Start');
      final before = t.updatedAt;
      await tick();
      edit(a, t);
      expect(t.updatedAt, before);
      await tick();
      edit(a, t, title: 'neu');
      expect(t.updatedAt.isAfter(before), isTrue);
    });

    test('Die Uhr eines Geräts geht nach: seine Änderung gilt trotzdem', () async {
      final a = await device();
      final t = add(a, 'Start');
      clock = () => DateTime.now().subtract(const Duration(hours: 1));
      addTearDown(() => clock = DateTime.now);
      edit(a, t, title: 'mit falscher Uhr');
      await a.sync.sync();
      expect(serverTask(t.id)['title'], 'mit falscher Uhr');
      expect(await a.pending(), 0);
    });

    test('Exakt gleicher Zeitpunkt im selben Feld: Es gilt der Stand, der zuerst am Server war', () async {
      final (a, b, ta, tb) = await pair();
      // Beide Uhren gehen nach: Beide Änderungen bekommen denselben Zeitpunkt knapp nach dem Stand.
      clock = () => DateTime.now().subtract(const Duration(hours: 1));
      addTearDown(() => clock = DateTime.now);
      edit(a, ta, title: 'von A');
      edit(b, tb, title: 'von B', notes: 'Notiz von B');
      expect(tb.updatedAt, ta.updatedAt);
      await settle(a, b);
      await b.sync.sync();

      expect(serverTask(ta.id)['title'], 'von A');
      for (final d in [a, b]) {
        expect(d.store.taskById(ta.id)!.title, 'von A');
        expect(d.store.taskById(ta.id)!.notes, 'Notiz von B', reason: 'die Notiz hat nur B geändert');
        expect(await d.pending(), 0);
        final again = Store(d.store.db);
        await again.load();
        expect(again.taskById(ta.id)!.title, 'von A');
      }
    });

    test('Derselbe Stand noch einmal ohne Zeitstempel (ältere App): die Zeitstempel am Server bleiben', () async {
      final a = await device();
      final t = add(a, 'Start');
      await a.sync.sync();
      final row = serverTask(t.id);
      server.put('tasks', {'id': t.id, 'title': 'Start', 'updated_at': row['updated_at'], 'field_times': null});
      expect(serverTask(t.id)['field_times'], isA<Map<String, Object?>>());
    });

    test('Die Feld-Gruppen in schema.sql sind dieselben wie in der App', () {
      final sql = File('supabase/schema.sql').readAsStringSync();
      final start = sql.indexOf("field_groups constant jsonb := '") + "field_groups constant jsonb := '".length;
      final inSql = jsonDecode(sql.substring(start, sql.indexOf("';", start))) as Map<String, Object?>;
      final inApp = {
        for (final t in syncTables)
          if (t.groups.isNotEmpty) t.name: t.groups,
      };
      expect(inSql, inApp);
    });
  });
}
