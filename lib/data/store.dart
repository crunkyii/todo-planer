import 'dart:async';

import 'package:flutter/foundation.dart';

import '../util/dates.dart';
import 'local_db.dart';
import 'models.dart';

/// Rückgängig-Aktion für die Snackbar.
typedef Undo = void Function();

/// Name und Farbe einer Standard-Kategorie beim ersten Start.
typedef DefaultCategory = ({String name, String color, int offset});

/// Alle Daten der App im Speicher – jede Änderung landet sofort in der lokalen
/// Datenbank und (mit `dirty`) in der Sync-Warteschlange.
class Store extends ChangeNotifier {
  Store(this.db);

  final LocalDb db;

  final Map<String, TaskCategory> _cats = {};
  final Map<String, Task> _tasks = {};
  final Map<String, Subtask> _subs = {};
  final Map<String, Habit> _habits = {};
  final Map<String, HabitLog> _logs = {};
  final Map<String, WeekBlock> _blocks = {};

  /// Aufgaben mit Änderungen, die noch nicht hochgeladen sind (Wolken-Symbol offline).
  final Set<String> pendingTaskIds = {};
  int pending = 0;
  bool loaded = false;

  /// Wird nach jeder lokalen Änderung aufgerufen (Sync anstoßen, Erinnerungen planen).
  VoidCallback? onLocalChange;

  // ---------- Lesen ----------

  List<TaskCategory> get categories =>
      _cats.values.where((c) => !c.deleted).toList()..sort((a, b) => a.position.compareTo(b.position));

  List<Task> get tasks => _tasks.values.where((t) => !t.deleted).toList();

  List<Habit> get habits => _habits.values.where((h) => !h.deleted).toList()
    ..sort((a, b) => a.position != b.position ? a.position.compareTo(b.position) : a.createdAt.compareTo(b.createdAt));

  List<WeekBlock> get blocks => _blocks.values.where((b) => !b.deleted).toList();

  TaskCategory catOf(String id) {
    final c = _cats[id];
    if (c != null && !c.deleted) return c;
    final list = categories;
    return list.isNotEmpty ? list.first : (c ?? TaskCategory(id: id, name: '', color: '#3D9BE9', offset: 0, position: 0, updatedAt: nowUtc()));
  }

  Task? taskById(String id) => _tasks[id]?.deleted == false ? _tasks[id] : null;
  Habit? habitById(String id) => _habits[id]?.deleted == false ? _habits[id] : null;
  WeekBlock? blockById(String id) => _blocks[id]?.deleted == false ? _blocks[id] : null;

  bool habitDone(String habitId, String day) => _logs['$habitId|$day']?.done ?? false;

  /// Erledigt-Einträge für die Statistik: auch gelöschte erledigte Aufgaben zählen,
  /// damit „Erledigte löschen“ die Statistik nicht leert.
  List<({String day, String cat})> doneEntries() => [
        for (final t in _tasks.values)
          if (t.done && t.doneAt != null) (day: isoDate(t.doneAt!.toLocal()), cat: t.categoryId),
      ];

  // ---------- Laden ----------

  Future<void> load() async {
    _clearMemory();
    for (final r in await db.all(categoriesTable)) {
      final c = TaskCategory.fromJson(r);
      _cats[c.id] = c;
    }
    for (final r in await db.all(tasksTable)) {
      final t = Task.fromJson(r);
      _tasks[t.id] = t;
      if (r['dirty'] == 1) pendingTaskIds.add(t.id);
    }
    for (final r in await db.all(subtasksTable)) {
      final s = Subtask.fromJson(r);
      _subs[s.id] = s;
      if (r['dirty'] == 1) pendingTaskIds.add(s.taskId);
    }
    for (final r in await db.all(habitsTable)) {
      final h = Habit.fromJson(r);
      _habits[h.id] = h;
    }
    for (final r in await db.all(habitLogsTable)) {
      final l = HabitLog.fromJson(r);
      _logs[l.key] = l;
    }
    for (final r in await db.all(blocksTable)) {
      final b = WeekBlock.fromJson(r);
      _blocks[b.id] = b;
    }
    _attachSubs();
    pending = await db.pendingCount();
    loaded = true;
    notifyListeners();
  }

  void _clearMemory() {
    _cats.clear();
    _tasks.clear();
    _subs.clear();
    _habits.clear();
    _logs.clear();
    _blocks.clear();
    pendingTaskIds.clear();
  }

  void _attachSubs() {
    for (final t in _tasks.values) {
      t.subs = [];
    }
    for (final s in _subs.values) {
      if (!s.deleted) _tasks[s.taskId]?.subs.add(s);
    }
    for (final t in _tasks.values) {
      t.subs.sort((a, b) => a.position.compareTo(b.position));
    }
  }

  Future<void> wipe() async {
    await db.wipe();
    _clearMemory();
    pending = 0;
    notifyListeners();
  }

  /// Legt die Standard-Kategorien an, falls es noch keine gibt.
  void ensureDefaultCategories(List<DefaultCategory> defaults) {
    if (_cats.values.any((c) => !c.deleted)) return;
    var pos = 0;
    for (final d in defaults) {
      _put(categoriesTable, TaskCategory(id: newId(), name: d.name, color: d.color, offset: d.offset, position: pos++, updatedAt: nowUtc()));
    }
    _changed();
  }

  // ---------- Schreiben ----------

  final List<Future<void>> _writes = [];

  /// Wartet, bis alle lokalen Schreibvorgänge fertig sind (für Sync und Tests).
  Future<void> flush() async {
    while (_writes.isNotEmpty) {
      await Future.wait(List.of(_writes));
    }
  }

  void _put(TableSpec t, Object model) {
    late final Map<String, Object?> json;
    switch (model) {
      case TaskCategory c:
        c.updatedAt = nowUtc();
        _cats[c.id] = c;
        json = c.toJson();
      case Task x:
        x.updatedAt = nowUtc();
        _tasks[x.id] = x;
        pendingTaskIds.add(x.id);
        json = x.toJson();
      case Subtask s:
        s.updatedAt = nowUtc();
        _subs[s.id] = s;
        pendingTaskIds.add(s.taskId);
        json = s.toJson();
      case Habit h:
        h.updatedAt = nowUtc();
        _habits[h.id] = h;
        json = h.toJson();
      case HabitLog l:
        l.updatedAt = nowUtc();
        _logs[l.key] = l;
        json = l.toJson();
      case WeekBlock b:
        b.updatedAt = nowUtc();
        _blocks[b.id] = b;
        json = b.toJson();
      default:
        throw ArgumentError(model);
    }
    late final Future<void> f;
    f = db.put(t, json, dirty: true).whenComplete(() => _writes.remove(f));
    _writes.add(f);
  }

  /// Alle Ansichten neu zeichnen, ohne etwas zu ändern (z. B. neuer Tag um Mitternacht).
  void touch() => notifyListeners();

  void _changed() {
    _attachSubs();
    notifyListeners();
    onLocalChange?.call();
    unawaited(refreshPending());
  }

  Future<void> refreshPending() async {
    await flush();
    final n = await db.pendingCount();
    if (n != pending) {
      pending = n;
      notifyListeners();
    }
  }

  /// Nach erfolgreichem Upload: Wolken-Symbol entfernen.
  void markSynced() {
    pendingTaskIds.clear();
    notifyListeners();
    unawaited(refreshPending());
  }

  // Aufgaben

  Task addTask({
    required String title,
    required String categoryId,
    required DateTime dueDate,
    required int? dueTime,
    required List<({String title, bool done})> subs,
  }) {
    final now = nowUtc();
    final t = Task(
      id: newId(), title: title, categoryId: categoryId, dueDate: sod(dueDate), dueTime: dueTime,
      done: false, doneAt: null, createdAt: now, updatedAt: now,
    );
    _put(tasksTable, t);
    _writeSubs(t.id, const [], subs);
    _changed();
    return t;
  }

  void updateTask(
    Task t, {
    required String title,
    required String categoryId,
    required DateTime dueDate,
    required int? dueTime,
    required List<({String title, bool done})> subs,
  }) {
    t
      ..title = title
      ..categoryId = categoryId
      ..dueDate = sod(dueDate)
      ..dueTime = dueTime;
    _put(tasksTable, t);
    _writeSubs(t.id, List.of(t.subs), subs);
    _changed();
  }

  /// Unteraufgaben abgleichen: vorhandene der Reihe nach wiederverwenden,
  /// überzählige löschen, fehlende neu anlegen.
  void _writeSubs(String taskId, List<Subtask> old, List<({String title, bool done})> next) {
    for (var i = 0; i < next.length; i++) {
      if (i < old.length) {
        final s = old[i];
        if (s.title != next[i].title || s.done != next[i].done || s.position != i) {
          _put(subtasksTable, s
            ..title = next[i].title
            ..done = next[i].done
            ..position = i);
        }
      } else {
        _put(subtasksTable, Subtask(id: newId(), taskId: taskId, title: next[i].title, done: next[i].done, position: i, updatedAt: nowUtc()));
      }
    }
    for (var i = next.length; i < old.length; i++) {
      _put(subtasksTable, old[i]..deleted = true);
    }
  }

  void toggleTask(Task t) {
    t.done = !t.done;
    t.doneAt = t.done ? nowUtc() : null;
    _put(tasksTable, t);
    _changed();
  }

  void toggleSub(Subtask s) {
    s.done = !s.done;
    _put(subtasksTable, s);
    _changed();
  }

  /// Löscht die Aufgabe samt Unteraufgaben und gibt zurück, wie es rückgängig geht.
  /// Wiederhergestellt werden nur die Unteraufgaben, die *dieser* Aufruf gelöscht hat –
  /// nicht solche, die schon vorher (z. B. im Bearbeiten-Sheet) entfernt wurden.
  void Function() _deleteTask(Task t) {
    final subs = _subs.values.where((s) => s.taskId == t.id && !s.deleted).toList();
    for (final s in subs) {
      _put(subtasksTable, s..deleted = true);
    }
    _put(tasksTable, t..deleted = true);
    return () {
      for (final s in subs) {
        _put(subtasksTable, s..deleted = false);
      }
      _put(tasksTable, t..deleted = false);
    };
  }

  Undo deleteTask(Task t) {
    final restore = _deleteTask(t);
    _changed();
    return () {
      restore();
      _changed();
    };
  }

  /// Löscht alle erledigten Aufgaben. Gibt `null` zurück, wenn es keine gibt.
  ({int count, Undo undo})? clearDone() {
    final removed = tasks.where((t) => t.done).toList();
    if (removed.isEmpty) return null;
    final restores = [for (final t in removed) _deleteTask(t)];
    _changed();
    return (
      count: removed.length,
      undo: () {
        for (final r in restores) {
          r();
        }
        _changed();
      },
    );
  }

  // Kategorien

  void addCategory({required String name, required String color, required int offset}) {
    final pos = _cats.values.fold<int>(-1, (m, c) => c.position > m ? c.position : m) + 1;
    _put(categoriesTable, TaskCategory(id: newId(), name: name, color: color, offset: offset, position: pos, updatedAt: nowUtc()));
    _changed();
  }

  void updateCategory(TaskCategory c, {required String name, required String color, required int offset}) {
    _put(categoriesTable, c
      ..name = name
      ..color = color
      ..offset = offset);
    _changed();
  }

  /// Löscht eine Kategorie; ihre Aufgaben wandern in die erste verbleibende.
  ({TaskCategory target, int moved, Undo undo})? deleteCategory(TaskCategory c) {
    if (categories.length < 2) return null;
    _put(categoriesTable, c..deleted = true);
    final target = categories.first;
    final moved = tasks.where((t) => t.categoryId == c.id).toList();
    for (final t in moved) {
      _put(tasksTable, t..categoryId = target.id);
    }
    _changed();
    return (
      target: target,
      moved: moved.length,
      undo: () {
        _put(categoriesTable, c..deleted = false);
        for (final t in moved) {
          _put(tasksTable, t..categoryId = c.id);
        }
        _changed();
      },
    );
  }

  /// Führt Kategorien mit gleichem Namen zusammen (z. B. die Standard-Kategorien zweier
  /// Geräte nach dem ersten Abgleich). Behalten wird die mit der kleinsten ID – so
  /// entscheiden alle Geräte gleich und löschen nie beide.
  void mergeDuplicateCategories() {
    final byName = <String, List<TaskCategory>>{};
    for (final c in categories) {
      (byName[c.name.trim().toLowerCase()] ??= []).add(c);
    }
    var changed = false;
    for (final group in byName.values.where((g) => g.length > 1)) {
      group.sort((a, b) => a.id.compareTo(b.id));
      final keep = group.first;
      for (final dup in group.skip(1)) {
        for (final t in _tasks.values.where((t) => t.categoryId == dup.id).toList()) {
          _put(tasksTable, t..categoryId = keep.id);
        }
        _put(categoriesTable, dup..deleted = true);
        changed = true;
      }
    }
    if (changed) _changed();
  }

  int openCount(String catId) => tasks.where((t) => t.categoryId == catId && !t.done).length;

  // Gewohnheiten

  void addHabit({required String name, required String color}) {
    final pos = _habits.values.fold<int>(-1, (m, h) => h.position > m ? h.position : m) + 1;
    final now = nowUtc();
    _put(habitsTable, Habit(id: newId(), name: name, color: color, position: pos, createdAt: now, updatedAt: now));
    _changed();
  }

  void updateHabit(Habit h, {required String name, required String color}) {
    _put(habitsTable, h
      ..name = name
      ..color = color);
    _changed();
  }

  Undo deleteHabit(Habit h) {
    _put(habitsTable, h..deleted = true);
    _changed();
    return () {
      _put(habitsTable, h..deleted = false);
      _changed();
    };
  }

  void _setLog(String habitId, String day, bool done) {
    final l = _logs['$habitId|$day'] ?? HabitLog(habitId: habitId, day: day, done: false, updatedAt: nowUtc());
    _put(habitLogsTable, l..done = done);
  }

  /// Hakt einen Tag einer Gewohnheit ab oder öffnet ihn wieder. Gibt den neuen Zustand zurück.
  bool toggleHabitDay(String habitId, String day) {
    final on = !habitDone(habitId, day);
    _setLog(habitId, day, on);
    _changed();
    return on;
  }

  /// Alle Gewohnheiten für heute abhaken – oder alle wieder öffnen, wenn schon alle erledigt sind.
  bool toggleAllHabitsToday() {
    final k = isoDate(today());
    final hs = habits;
    final all = hs.isNotEmpty && hs.every((h) => habitDone(h.id, k));
    for (final h in hs) {
      _setLog(h.id, k, !all);
    }
    _changed();
    return !all;
  }

  int habitStreak(String habitId) => streak((d) => habitDone(habitId, isoDate(d)));

  // Wochenblöcke

  int addBlocks({
    required String name,
    required String color,
    required List<int> days,
    required int start,
    required int end,
    required bool repeat,
    required DateTime weekStart,
  }) {
    for (final d in days) {
      _put(blocksTable, WeekBlock(
        id: newId(), name: name, color: color, day: d, start: start, end: end, repeat: repeat,
        weekStart: repeat ? null : isoDate(weekStart), updatedAt: nowUtc(),
      ));
    }
    _changed();
    return days.length;
  }

  void updateBlock(WeekBlock b, {
    required String name,
    required String color,
    required int day,
    required int start,
    required int end,
    required bool repeat,
    required DateTime weekStart,
  }) {
    _put(blocksTable, b
      ..name = name
      ..color = color
      ..day = day
      ..start = start
      ..end = end
      ..repeat = repeat
      ..weekStart = repeat ? null : isoDate(weekStart));
    _changed();
  }

  Undo deleteBlock(WeekBlock b) {
    _put(blocksTable, b..deleted = true);
    _changed();
    return () {
      _put(blocksTable, b..deleted = false);
      _changed();
    };
  }

  /// Blöcke eines Wochentags in der Woche ab [weekStart].
  List<WeekBlock> blocksFor(int day, DateTime weekStart) {
    final w = isoDate(weekStart);
    return blocks.where((b) => b.day == day && (b.repeat || b.weekStart == w)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // ---------- Sync: Änderungen von Supabase übernehmen ----------

  /// Übernimmt Zeilen vom Server. Der neueste `updated_at` gewinnt; lokale
  /// Änderungen, die neuer sind, bleiben und werden später hochgeladen.
  Future<void> applyRemote(TableSpec t, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final accepted = <Map<String, Object?>>[];
    for (final r in rows) {
      final updated = DateTime.parse(r['updated_at'] as String).toUtc();
      final existing = _existingUpdatedAt(t, r);
      if (existing != null && !updated.isAfter(existing)) continue;
      final row = {for (final k in t.columns.keys) k: r[k]};
      accepted.add(row);
      switch (t.name) {
        case 'categories':
          final c = TaskCategory.fromJson(row);
          _cats[c.id] = c;
        case 'tasks':
          final x = Task.fromJson(row);
          _tasks[x.id] = x;
        case 'subtasks':
          final s = Subtask.fromJson(row);
          _subs[s.id] = s;
        case 'habits':
          final h = Habit.fromJson(row);
          _habits[h.id] = h;
        case 'habit_logs':
          final l = HabitLog.fromJson(row);
          _logs[l.key] = l;
        case 'week_blocks':
          final b = WeekBlock.fromJson(row);
          _blocks[b.id] = b;
      }
    }
    if (accepted.isEmpty) return;
    await db.putAll(t, accepted, dirty: false);
    _attachSubs();
    notifyListeners();
  }

  DateTime? _existingUpdatedAt(TableSpec t, Map<String, Object?> r) => switch (t.name) {
        'categories' => _cats[r['id']]?.updatedAt,
        'tasks' => _tasks[r['id']]?.updatedAt,
        'subtasks' => _subs[r['id']]?.updatedAt,
        'habits' => _habits[r['id']]?.updatedAt,
        'habit_logs' => _logs['${r['habit_id']}|${(r['day'] as String).substring(0, 10)}']?.updatedAt,
        'week_blocks' => _blocks[r['id']]?.updatedAt,
        _ => null,
      };
}
