import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_liste/data/local_db.dart';
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

  static Future<Device> create(FakeSupabase server, {LocalDb? db}) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({'sync.v1': '{"mode":"cloud","url":"${server.url}","key":"k"}'});
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

  Future<Device> device({LocalDb? db}) async {
    final d = await Device.create(server, db: db);
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
}
