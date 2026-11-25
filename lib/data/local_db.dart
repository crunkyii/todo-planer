import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'models.dart';

/// Beschreibt eine Tabelle, die lokal und in Supabase gleich aufgebaut ist.
///
/// Neue Tabelle anlegen – an diesen Stellen eintragen:
/// 1. hier eine `TableSpec` und in [syncTables] (Reihenfolge = Reihenfolge beim Hochladen),
/// 2. ein Modell mit `toJson()`/`fromJson()` in `models.dart`,
/// 3. im `Store`: eine eigene Map sowie `_put`, `_ingest` und `_merge`,
/// 4. in `supabase/schema.sql`: die Tabelle und ihr Name in der Schleife für Trigger, RLS und Realtime
///    (samt Feld-Gruppen, wenn sie feldweise zusammengeführt werden soll).
class TableSpec {
  const TableSpec(this.name, this.keys, this.columns, {this.bools = const {}, this.groups = const {}});

  final String name;

  /// Primärschlüssel-Spalten (für Upsert/onConflict).
  final List<String> keys;

  /// Alle Spalten mit SQLite-Typ, in derselben Reihenfolge wie `toJson()`.
  final Map<String, String> columns;

  /// Spalten, die in Supabase `boolean` sind (lokal stehen sie als 0/1 in SQLite).
  final Set<String> bools;

  /// Feld-Gruppen für das feldweise Zusammenführen (siehe `field_merge.dart`): Name der
  /// Gruppe → ihre Spalten. Was zusammengehört (Datum und Uhrzeit, erledigt und wann), ist
  /// eine Gruppe. Leer = die ganze Zeile gewinnt oder verliert als Ganzes.
  ///
  /// Dieselben Gruppen stehen in `supabase/schema.sql` beim Anlegen der Trigger – ein Test
  /// vergleicht beide Stellen.
  final Map<String, List<String>> groups;
}

/// Zeitstempel je Feld-Gruppe als JSON (lokal Text, in Supabase `jsonb`). Ohne NOT NULL:
/// Zeilen von älteren App-Versionen und älteren Servern haben keine.
const _fieldTimes = {'field_times': 'TEXT'};

const categoriesTable = TableSpec(
  'categories',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'name': 'TEXT NOT NULL',
    'color': 'TEXT NOT NULL',
    'offset_days': 'INTEGER NOT NULL',
    // Ohne NOT NULL, damit `ALTER TABLE` bei alten Datenbanken geht; leer heißt „immer“.
    'list_from': 'TEXT',
    'position': 'INTEGER NOT NULL',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
    ..._fieldTimes,
  },
  bools: {'deleted'},
  groups: {
    'name': ['name'],
    'color': ['color'],
    'offset': ['offset_days'],
    'list_from': ['list_from'],
    'position': ['position'],
    'deleted': ['deleted'],
  },
);

const tasksTable = TableSpec(
  'tasks',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'title': 'TEXT NOT NULL',
    // Ohne NOT NULL: Zeilen von einem Server, der die Spalte noch nicht kennt, haben keinen Wert.
    'notes': 'TEXT',
    'category_id': 'TEXT NOT NULL',
    'due_date': 'TEXT NOT NULL',
    'due_time': 'TEXT',
    'remind_min': 'INTEGER',
    'done': 'INTEGER NOT NULL',
    'done_at': 'TEXT',
    'created_at': 'TEXT NOT NULL',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
    ..._fieldTimes,
  },
  bools: {'done', 'deleted'},
  groups: {
    'title': ['title'],
    'notes': ['notes'],
    'category': ['category_id'],
    'due': ['due_date', 'due_time'],
    'remind': ['remind_min'],
    'done': ['done', 'done_at'],
    'deleted': ['deleted'],
  },
);

const subtasksTable = TableSpec(
  'subtasks',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'task_id': 'TEXT NOT NULL',
    'title': 'TEXT NOT NULL',
    'done': 'INTEGER NOT NULL',
    'position': 'INTEGER NOT NULL',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
    ..._fieldTimes,
  },
  bools: {'done', 'deleted'},
  groups: {
    'title': ['title'],
    'done': ['done'],
    'position': ['position'],
    'deleted': ['deleted'],
  },
);

const habitsTable = TableSpec(
  'habits',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'name': 'TEXT NOT NULL',
    'color': 'TEXT NOT NULL',
    'position': 'INTEGER NOT NULL',
    'created_at': 'TEXT NOT NULL',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
    ..._fieldTimes,
  },
  bools: {'deleted'},
  groups: {
    'name': ['name'],
    'color': ['color'],
    'position': ['position'],
    'deleted': ['deleted'],
  },
);

const habitLogsTable = TableSpec(
  'habit_logs',
  ['habit_id', 'day'],
  {'habit_id': 'TEXT NOT NULL', 'day': 'TEXT NOT NULL', 'done': 'INTEGER NOT NULL', 'updated_at': 'TEXT NOT NULL'},
  bools: {'done'},
);

const blocksTable = TableSpec(
  'week_blocks',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'name': 'TEXT NOT NULL',
    'color': 'TEXT NOT NULL',
    'day': 'INTEGER NOT NULL',
    'start_min': 'INTEGER NOT NULL',
    'end_min': 'INTEGER NOT NULL',
    'repeat': 'INTEGER NOT NULL',
    'week_start': 'TEXT',
    'task_id': 'TEXT',
    'remind_min': 'INTEGER',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
    ..._fieldTimes,
  },
  bools: {'repeat', 'deleted'},
  groups: {
    // Tag, Zeit und Wiederholung beschreiben zusammen, wann der Block ist.
    'name': ['name'],
    'color': ['color'],
    'time': ['day', 'start_min', 'end_min', 'repeat', 'week_start'],
    'task': ['task_id'],
    'remind': ['remind_min'],
    'deleted': ['deleted'],
  },
);

const boardColumnsTable = TableSpec(
  'board_columns',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'name': 'TEXT NOT NULL',
    'color': 'TEXT NOT NULL',
    'category_ids': 'TEXT NOT NULL',
    'periods': 'TEXT NOT NULL',
    'status': 'TEXT NOT NULL',
    'query': 'TEXT NOT NULL',
    'position': 'INTEGER NOT NULL',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
    ..._fieldTimes,
  },
  bools: {'deleted'},
  groups: {
    'name': ['name'],
    'color': ['color'],
    'categories': ['category_ids'],
    'periods': ['periods'],
    'status': ['status'],
    'query': ['query'],
    'position': ['position'],
    'deleted': ['deleted'],
  },
);

/// Alle Tabellen. Die Reihenfolge ist wichtig für den Upload: Kategorien vor Aufgaben,
/// Aufgaben vor Unteraufgaben …
const syncTables = [
  categoriesTable,
  habitsTable,
  tasksTable,
  subtasksTable,
  habitLogsTable,
  blocksTable,
  boardColumnsTable,
];

/// Lokale SQLite-Datenbank (über drift). Jede Zeile hat zusätzlich `dirty`:
/// 1 = noch nicht an Supabase geschickt (Sync-Warteschlange).
class LocalDb extends GeneratedDatabase {
  LocalDb([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'todo_liste'));

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  /// Bei jeder Änderung an den Spalten um eins erhöhen und unten in `onUpgrade` nachziehen.
  /// 2: `tasks.notes` · 3: `categories.list_from` · 4: Tabelle `done_archive` ·
  /// 5: `field_times` (Zeitstempel je Feld-Gruppe) · 6: leere `list_from`/`notes` auffüllen ·
  /// 7: `week_blocks.task_id` · 8: `remind_min` (Aufgaben und Blöcke) ·
  /// 9: Tabelle `board_columns`.
  @override
  int get schemaVersion => 9;

  /// Merkzettel der erledigten Aufgaben, die nur noch online liegen (siehe [ArchivedDone]).
  /// Nur am Gerät – diese Tabelle wird nie abgeglichen.
  static const _createArchive =
      'CREATE TABLE IF NOT EXISTS "done_archive" '
      '("id" TEXT NOT NULL PRIMARY KEY, "day" TEXT NOT NULL, "category_id" TEXT NOT NULL, "due_date" TEXT)';

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final t in syncTables) {
        await _createTable(t);
      }
      await customStatement(_createArchive);
    },
    onUpgrade: (m, from, to) async {
      // Zuerst: Die Schritte unten gehen über alle Tabellen.
      if (from < 9) await _createTable(boardColumnsTable);
      if (from < 2) await _addColumn('tasks', 'notes', 'TEXT');
      if (from < 3) await _addColumn('categories', 'list_from', 'TEXT');
      if (from < 4) await customStatement(_createArchive);
      if (from < 5) {
        for (final t in syncTables.where((t) => t.groups.isNotEmpty)) {
          await _addColumn(t.name, 'field_times', 'TEXT');
        }
      }
      // Zeilen von vor den Versionen 2 und 3 haben hier noch nichts stehen. Supabase verlangt
      // einen Wert und lehnt sie sonst bei jedem Hochladen ab – dann sehen andere Geräte die
      // Kategorie nie. `updated_at` bleibt, die Zeilen gehen beim nächsten Abgleich hoch.
      if (from < 6) {
        await customStatement("UPDATE \"categories\" SET \"list_from\" = 'always' WHERE \"list_from\" IS NULL");
        await customStatement("UPDATE \"tasks\" SET \"notes\" = '' WHERE \"notes\" IS NULL");
      }
      if (from < 7) await _addColumn('week_blocks', 'task_id', 'TEXT');
      // Wie bisher: Aufgaben melden sich zu ihrer Uhrzeit, Blöcke gar nicht. Ein Wert muss
      // stehen, weil Supabase leere ablehnt (siehe Version 6).
      if (from < 8) {
        await _addColumn('tasks', 'remind_min', 'INTEGER');
        await _addColumn('week_blocks', 'remind_min', 'INTEGER');
        await customStatement('UPDATE "tasks" SET "remind_min" = 0 WHERE "remind_min" IS NULL');
        await customStatement('UPDATE "week_blocks" SET "remind_min" = $remindNone WHERE "remind_min" IS NULL');
      }
    },
  );

  Future<void> _createTable(TableSpec t) {
    final cols = t.columns.entries.map((e) => '"${e.key}" ${e.value}').join(', ');
    return customStatement(
      'CREATE TABLE IF NOT EXISTS "${t.name}" ($cols, "dirty" INTEGER NOT NULL DEFAULT 0, '
      'PRIMARY KEY (${t.keys.map((k) => '"$k"').join(', ')}))',
    );
  }

  /// Spalte anlegen, falls es sie noch nicht gibt (ein abgebrochenes Update kann sie schon haben).
  Future<void> _addColumn(String table, String column, String type) async {
    final cols = await customSelect('PRAGMA table_info("$table")').get();
    if (cols.any((c) => c.data['name'] == column)) return;
    await customStatement('ALTER TABLE "$table" ADD COLUMN "$column" $type');
  }

  static Object? _toSql(Object? v) => switch (v) {
    final bool b => b ? 1 : 0,
    final Map<Object?, Object?> m => jsonEncode(m), // `field_times`
    _ => v,
  };

  /// Alle Zeilen einer Tabelle als Map (Spaltenname → Wert).
  Future<List<Map<String, Object?>>> all(TableSpec t) async {
    final rows = await customSelect('SELECT * FROM "${t.name}"').get();
    return rows.map((r) => r.data).toList();
  }

  /// Speichert eine Zeile. [dirty] = in die Warteschlange für den Upload.
  Future<void> put(TableSpec t, Map<String, Object?> row, {required bool dirty}) {
    final cols = [...t.columns.keys, 'dirty'];
    final vals = [...t.columns.keys.map((k) => _toSql(row[k])), dirty ? 1 : 0];
    return customStatement(
      'INSERT OR REPLACE INTO "${t.name}" (${cols.map((c) => '"$c"').join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')})',
      vals,
    );
  }

  Future<void> putAll(TableSpec t, Iterable<Map<String, Object?>> rows, {required bool dirty}) => transaction(() async {
    for (final r in rows) {
      await put(t, r, dirty: dirty);
    }
  });

  Future<List<Map<String, Object?>>> dirtyRows(TableSpec t) async {
    final rows = await customSelect('SELECT * FROM "${t.name}" WHERE dirty = 1').get();
    return rows.map((r) => r.data).toList();
  }

  /// Markiert eine Zeile als hochgeladen – aber nur, wenn sie sich seitdem nicht geändert hat.
  Future<void> markClean(TableSpec t, Map<String, Object?> row) {
    final where = t.keys.map((k) => '"$k" = ?').join(' AND ');
    return customStatement('UPDATE "${t.name}" SET dirty = 0 WHERE $where AND updated_at = ?', [
      ...t.keys.map((k) => row[k]),
      row['updated_at'],
    ]);
  }

  Future<void> markAllDirty() => transaction(() async {
    for (final t in syncTables) {
      await customStatement('UPDATE "${t.name}" SET dirty = 1');
    }
  });

  Future<int> pendingCount() async {
    var n = 0;
    for (final t in syncTables) {
      final r = await customSelect('SELECT COUNT(*) AS n FROM "${t.name}" WHERE dirty = 1').getSingle();
      n += r.read<int>('n');
    }
    return n;
  }

  /// Löscht alle lokalen Daten (z. B. wenn sich ein anderes Konto anmeldet).
  Future<void> wipe() => transaction(() async {
    for (final t in syncTables) {
      await customStatement('DELETE FROM "${t.name}"');
    }
    await customStatement('DELETE FROM "done_archive"');
  });

  // ---------- Erledigte Aufgaben, die nur noch online liegen ----------

  Future<List<ArchivedDone>> archived() async {
    final rows = await customSelect('SELECT * FROM "done_archive"').get();
    return [
      for (final r in rows)
        (
          id: r.read<String>('id'),
          day: r.read<String>('day'),
          cat: r.read<String>('category_id'),
          due: r.readNullable<String>('due_date'),
        ),
    ];
  }

  Future<void> _putArchived(ArchivedDone a) => customStatement(
    'INSERT OR REPLACE INTO "done_archive" ("id", "day", "category_id", "due_date") VALUES (?, ?, ?, ?)',
    [a.id, a.day, a.cat, a.due],
  );

  Future<void> putArchived(Iterable<ArchivedDone> entries) => transaction(() async {
    for (final a in entries) {
      await _putArchived(a);
    }
  });

  Future<void> removeArchived(String id) => customStatement('DELETE FROM "done_archive" WHERE "id" = ?', [id]);

  /// Aufgaben, deren eigene Zeile oder eine ihrer Unteraufgaben noch auf den Upload wartet.
  Future<Set<String>> dirtyTaskIds() async {
    final rows = await customSelect(
      'SELECT "id" AS id FROM "tasks" WHERE dirty = 1 UNION SELECT "task_id" AS id FROM "subtasks" WHERE dirty = 1',
    ).get();
    return {for (final r in rows) r.read<String>('id')};
  }

  /// Nimmt Aufgaben samt Unteraufgaben vom Gerät und lässt nur den Merkzettel da – ein Commit
  /// für alle. Das ist kein Löschen: Es wird nichts hochgeladen, die Zeilen in Supabase
  /// bleiben, wie sie sind. Was (wieder) auf den Upload wartet, bleibt liegen.
  Future<void> moveToArchive(Iterable<ArchivedDone> entries) => transaction(() async {
    for (final a in entries) {
      await _putArchived(a);
      await customStatement('DELETE FROM "tasks" WHERE "id" = ? AND dirty = 0', [a.id]);
      await customStatement('DELETE FROM "subtasks" WHERE "task_id" = ? AND dirty = 0', [a.id]);
    }
  });
}
