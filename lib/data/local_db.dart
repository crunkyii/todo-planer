import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Beschreibt eine Tabelle, die lokal und in Supabase gleich aufgebaut ist.
class TableSpec {
  const TableSpec(this.name, this.keys, this.columns);

  final String name;

  /// Primärschlüssel-Spalten (für Upsert/onConflict).
  final List<String> keys;

  /// Alle Spalten mit SQLite-Typ, in derselben Reihenfolge wie `toJson()`.
  final Map<String, String> columns;
}

const categoriesTable = TableSpec(
  'categories',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'name': 'TEXT NOT NULL',
    'color': 'TEXT NOT NULL',
    'offset_days': 'INTEGER NOT NULL',
    'position': 'INTEGER NOT NULL',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
  },
);

const tasksTable = TableSpec(
  'tasks',
  ['id'],
  {
    'id': 'TEXT NOT NULL',
    'title': 'TEXT NOT NULL',
    'category_id': 'TEXT NOT NULL',
    'due_date': 'TEXT NOT NULL',
    'due_time': 'TEXT',
    'done': 'INTEGER NOT NULL',
    'done_at': 'TEXT',
    'created_at': 'TEXT NOT NULL',
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
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
  },
);

const habitLogsTable = TableSpec(
  'habit_logs',
  ['habit_id', 'day'],
  {'habit_id': 'TEXT NOT NULL', 'day': 'TEXT NOT NULL', 'done': 'INTEGER NOT NULL', 'updated_at': 'TEXT NOT NULL'},
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
    'updated_at': 'TEXT NOT NULL',
    'deleted': 'INTEGER NOT NULL',
  },
);

/// Reihenfolge ist wichtig für den Upload: Kategorien vor Aufgaben, Aufgaben vor Unteraufgaben …
const syncTables = [categoriesTable, habitsTable, tasksTable, subtasksTable, habitLogsTable, blocksTable];

/// Lokale SQLite-Datenbank (über drift). Jede Zeile hat zusätzlich `dirty`:
/// 1 = noch nicht an Supabase geschickt (Sync-Warteschlange).
class LocalDb extends GeneratedDatabase {
  LocalDb([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'todo_liste'));

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final t in allTablesSpec) {
        final cols = t.columns.entries.map((e) => '"${e.key}" ${e.value}').join(', ');
        await customStatement(
          'CREATE TABLE "${t.name}" ($cols, "dirty" INTEGER NOT NULL DEFAULT 0, '
          'PRIMARY KEY (${t.keys.map((k) => '"$k"').join(', ')}))',
        );
      }
    },
  );

  static const allTablesSpec = syncTables;

  static Object? _toSql(Object? v) => v is bool ? (v ? 1 : 0) : v;

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
    for (final t in allTablesSpec) {
      await customStatement('UPDATE "${t.name}" SET dirty = 1');
    }
  });

  Future<int> pendingCount() async {
    var n = 0;
    for (final t in allTablesSpec) {
      final r = await customSelect('SELECT COUNT(*) AS n FROM "${t.name}" WHERE dirty = 1').getSingle();
      n += r.read<int>('n');
    }
    return n;
  }

  /// Löscht alle lokalen Daten (z. B. wenn sich ein anderes Konto anmeldet).
  Future<void> wipe() => transaction(() async {
    for (final t in allTablesSpec) {
      await customStatement('DELETE FROM "${t.name}"');
    }
  });
}
