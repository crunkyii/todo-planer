import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_liste/data/local_db.dart';
import 'package:todo_liste/data/store.dart';
import 'package:todo_liste/services/export.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';

import 'harness.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Store store;
  final l = l10n('de');
  final f = Fmt(l);

  setUpAll(() async {
    await initializeDateFormatting();
    clock = () => DateTime(2026, 11, 18, 10, 30);
  });
  tearDownAll(() => clock = DateTime.now);

  setUp(() async {
    store = Store(LocalDb(NativeDatabase.memory()));
    await store.load();
    store.ensureDefaultCategories([(name: 'Termin', color: '#3D9BE9', offset: 0)]);
    final cat = store.categories.first.id;
    store.addTask(
      title: "Max Mustermann's Geburtstag",
      categoryId: cat,
      dueDate: DateTime(2026, 12, 3),
      dueTime: 8 * 60,
      subs: [(title: 'Geschenk', done: true), (title: 'Karte', done: false)],
      notes: 'Lieblingsfarbe: grün',
    );
    final done = store.addTask(title: 'Einkaufen; Milch', categoryId: cat, dueDate: today(), dueTime: null, subs: []);
    store.toggleTask(done);
    store.addTask(title: '=SUMME(A1)', categoryId: cat, dueDate: today(), dueTime: null, subs: []);
    store.addHabit(name: 'Trinken', color: '#34C38F');
    store.toggleHabitDay(store.habits.first.id, '2026-11-17');
    store.toggleHabitDay(store.habits.first.id, '2026-11-18');
  });

  tearDown(() async {
    await store.refreshPending();
    await store.db.close();
  });

  test('Daten: offene Aufgaben zuerst, Gewohnheiten mit Tagen', () {
    final data = buildExport(store, l, f);
    expect(data.stamp, 'Stand: 18.11.2026');
    expect(data.tables.map((t) => t.title), [l.navTasks, l.habits, l.weeklyPlan, l.categories]);
    final tasks = data.tables.first;
    expect(tasks.rows.last.first, 'Einkaufen; Milch'); // erledigt steht hinten
    final birthday = tasks.rows.firstWhere((r) => r.first.contains('Geburtstag'));
    expect(birthday, [
      "Max Mustermann's Geburtstag",
      'Termin',
      '03.12.2026',
      '08:00',
      'Nein',
      'Ja',
      '[x] Geschenk, [ ] Karte',
      'Lieblingsfarbe: grün',
    ]);
    expect(data.tables[1].rows.single, ['Trinken', '2', '18.11.2026']);
    for (final t in data.tables) {
      for (final r in t.rows) {
        expect(r, hasLength(t.head.length), reason: t.title);
      }
    }
  });

  test('Text: Überschriften und Angaben', () {
    final txt = exportTxt(buildExport(store, l, f));
    expect(txt, startsWith('Todo-Liste\r\nStand: 18.11.2026\r\n'));
    expect(txt, contains('AUFGABEN (3)'));
    expect(txt, contains("- Max Mustermann's Geburtstag\r\n  Kategorie: Termin | Abgabe: 03.12.2026 | Uhrzeit: 08:00"));
    expect(txt, contains('GEWOHNHEITEN (1)'));
  });

  test('Tabelle: Strichpunkte in Anführungszeichen, Formeln entschärft', () {
    final csv = exportCsv(buildExport(store, l, f));
    expect(csv, contains('Titel;Kategorie;Abgabe;Uhrzeit;Erledigt;Jährlich;Unteraufgaben;Notiz\r\n'));
    expect(csv, contains('"Einkaufen; Milch";Termin;18.11.2026;;Ja;Nein;;\r\n'));
    expect(csv, contains("'=SUMME(A1);Termin"));
    expect(csv, isNot(contains('\n=SUMME')));
  });

  test('Dateien: PDF, Text und Tabelle mit richtigem Anfang und Namen', () async {
    final data = buildExport(store, l, f);
    final pdf = await exportBytes(data, ExportFormat.pdf);
    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(pdf.length, greaterThan(1000));
    final csv = await exportBytes(data, ExportFormat.csv);
    expect(csv.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final txt = await exportBytes(data, ExportFormat.txt);
    expect(utf8.decode(txt), contains('Jährlich: Ja'));
    expect(exportFileName(ExportFormat.pdf), 'todo-liste-2026-11-18.pdf');
  });

  test('Tabelle: Anführungszeichen, - und @ am Anfang, Komma auf Englisch', () {
    const data = ExportData(
      title: 'T',
      stamp: 'S',
      tables: [
        ExportTable(
          'A',
          ['x', 'y'],
          [
            ['sagt "hallo"', '-5'],
            ['@home', 'a,b'],
          ],
        ),
      ],
    );
    expect(exportCsv(data), 'A\r\nx;y\r\n"sagt ""hallo""";\'-5\r\n\'@home;"a,b"\r\n');
    expect(exportCsv(data, sep: ','), contains('\'@home,"a,b"'));
  });

  test('PDF: 400 Aufgaben, sehr lange Titel und 60 Unteraufgaben ergeben ein endliches Dokument', () async {
    final cat = store.categories.first.id;
    for (var i = 0; i < 400; i++) {
      store.addTask(title: 'Aufgabe $i ${'lang ' * 30}', categoryId: cat, dueDate: today(), dueTime: null, subs: []);
    }
    store.addTask(
      title: 'Packliste',
      categoryId: cat,
      dueDate: today(),
      dueTime: null,
      subs: [for (var i = 0; i < 60; i++) (title: 'Unteraufgabe Nummer $i mit Text', done: false)],
    );
    final pdf = await exportBytes(buildExport(store, l, f), ExportFormat.pdf);
    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
  });

  test('PDF-Schrift: Umlaute bleiben, Emojis und Sonderzeichen werden ersetzt', () {
    expect(pdfSafe('Jänner „Größe“ – 5 € 🎂'), 'Jänner "Größe" - 5 EUR ?');
  });
}
