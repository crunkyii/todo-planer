import 'dart:async';

import 'package:flutter/foundation.dart';

import '../util/dates.dart';
import '../util/task_logic.dart';
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

  /// Die lokale Datenbank. Nur der Store schreibt hinein – alle anderen gehen über seine Methoden.
  final LocalDb db;

  final Map<String, TaskCategory> _cats = {};
  final Map<String, Task> _tasks = {};
  final Map<String, Subtask> _subs = {};
  final Map<String, Habit> _habits = {};
  final Map<String, HabitLog> _logs = {};
  final Map<String, WeekBlock> _blocks = {};

  /// Jährliche Aufgabe → die Aufgabe fürs nächste Jahr, die beim Abhaken in dieser Sitzung
  /// entstanden ist. Nur diese nimmt „wieder öffnen“ zurück, nie eine selbst angelegte.
  final Map<String, String> _yearlyCopies = {};

  /// Aufgaben mit Änderungen, die noch nicht hochgeladen sind (Wolken-Symbol offline).
  final Set<String> pendingTaskIds = {};

  /// Wie viele Zeilen (aller Tabellen) noch auf den Upload warten.
  int pending = 0;

  /// Wird nach jeder lokalen Änderung aufgerufen – `AppServices` stößt damit den Sync an.
  /// (Erinnerungen und Widgets hängen als normale Zuhörer am Store.)
  VoidCallback? onLocalChange;

  // ---------- Lesen ----------

  List<TaskCategory> get categories =>
      _cats.values.where((c) => !c.deleted).toList()..sort((a, b) => a.position.compareTo(b.position));

  List<Task> get tasks => _tasks.values.where((t) => !t.deleted).toList();

  List<Habit> get habits => _habits.values.where((h) => !h.deleted).toList()
    ..sort((a, b) => a.position != b.position ? a.position.compareTo(b.position) : a.createdAt.compareTo(b.createdAt));

  List<WeekBlock> get blocks => _blocks.values.where((b) => !b.deleted).toList();

  /// Die Kategorie einer Aufgabe. Gibt es sie nicht mehr (gelöscht, noch nicht abgeglichen),
  /// springt die erste vorhandene ein – und ganz ohne Kategorien ein namenloser Platzhalter,
  /// damit die Oberfläche nie ohne Farbe und Vorlauf dasteht.
  TaskCategory catOf(String id) {
    final c = _cats[id];
    if (c != null && !c.deleted) return c;
    final list = categories;
    return list.isNotEmpty
        ? list.first
        : (c ?? TaskCategory(id: id, name: '', color: _placeholderColor, offset: 0, position: 0, updatedAt: nowUtc()));
  }

  /// Farbe des Platzhalters in [catOf] (das Himmelblau der ersten Standard-Kategorie).
  static const _placeholderColor = '#3D9BE9';

  // Der aktuelle Stand eines Eintrags – `null`, wenn er (auch durch den Abgleich) gelöscht wurde.
  // Ein Sheet, das länger offen ist, holt sich damit vor dem Speichern das frische Objekt:
  // Der Abgleich ersetzt Objekte im Speicher, ein altes würde neuere Änderungen überschreiben.
  Task? taskById(String id) => _tasks[id]?.deleted == false ? _tasks[id] : null;
  Habit? habitById(String id) => _habits[id]?.deleted == false ? _habits[id] : null;
  WeekBlock? blockById(String id) => _blocks[id]?.deleted == false ? _blocks[id] : null;
  TaskCategory? categoryById(String id) => _cats[id]?.deleted == false ? _cats[id] : null;

  bool habitDone(String habitId, String day) => _logs[HabitLog.keyOf(habitId, day)]?.done ?? false;

  /// Alle Tage (`JJJJ-MM-TT`, aufsteigend), an denen die Gewohnheit erledigt wurde.
  List<String> habitDoneDays(String habitId) => [
    for (final g in _logs.values)
      if (g.habitId == habitId && g.done) g.day,
  ]..sort();

  /// Erledigt-Einträge für die Statistik: auch gelöschte erledigte Aufgaben zählen,
  /// damit „Erledigte löschen“ die Statistik nicht leert.
  List<({String day, String cat})> doneEntries() => [
    for (final t in _tasks.values)
      if (t.done && t.doneAt != null) (day: isoDate(t.doneAt!.toLocal()), cat: t.categoryId),
  ];

  // ---------- Laden ----------

  /// Liest alles aus der lokalen Datenbank in den Speicher (beim Start der App).
  Future<void> load() async {
    _clearMemory();
    for (final t in syncTables) {
      for (final r in await db.all(t)) {
        _ingest(t, r);
        if (r['dirty'] != 1) continue;
        // Wolken-Symbol: Aufgaben, deren eigene Zeile oder eine Unteraufgabe noch wartet.
        if (t == tasksTable) pendingTaskIds.add(r['id'] as String);
        if (t == subtasksTable) pendingTaskIds.add(r['task_id'] as String);
      }
    }
    _attachSubs();
    pending = await db.pendingCount();
    notifyListeners();
  }

  /// Legt eine Zeile – aus der lokalen Datenbank oder vom Server – als Modell im Speicher ab.
  void _ingest(TableSpec t, Map<String, Object?> row) {
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
      default:
        throw ArgumentError.value(t.name, 'table');
    }
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
      _put(
        TaskCategory(id: newId(), name: d.name, color: d.color, offset: d.offset, position: pos++, updatedAt: nowUtc()),
      );
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

  /// Speichert ein Modell: im Speicher, in der lokalen Datenbank und – über `dirty` – in der
  /// Warteschlange für den Upload. Setzt `updatedAt`, weil beim Abgleich der neueste Stand gewinnt.
  void _put(Object model) {
    final now = nowUtc();
    final TableSpec t;
    final Map<String, Object?> json;
    switch (model) {
      case TaskCategory c:
        c.updatedAt = now;
        _cats[c.id] = c;
        t = categoriesTable;
        json = c.toJson();
      case Task x:
        x.updatedAt = now;
        _tasks[x.id] = x;
        pendingTaskIds.add(x.id);
        t = tasksTable;
        json = x.toJson();
      case Subtask s:
        s.updatedAt = now;
        _subs[s.id] = s;
        pendingTaskIds.add(s.taskId);
        t = subtasksTable;
        json = s.toJson();
      case Habit h:
        h.updatedAt = now;
        _habits[h.id] = h;
        t = habitsTable;
        json = h.toJson();
      case HabitLog l:
        l.updatedAt = now;
        _logs[l.key] = l;
        t = habitLogsTable;
        json = l.toJson();
      case WeekBlock b:
        b.updatedAt = now;
        _blocks[b.id] = b;
        t = blocksTable;
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
    if (pendingTaskIds.isNotEmpty) {
      pendingTaskIds.clear();
      notifyListeners();
    }
    unawaited(refreshPending());
  }

  // ---------- Sync-Warteschlange (nur für den SyncService) ----------

  /// Zeilen von [t], die noch nicht hochgeladen sind.
  Future<List<Map<String, Object?>>> dirtyRows(TableSpec t) => db.dirtyRows(t);

  /// Nimmt hochgeladene Zeilen aus der Warteschlange – ein Commit für alle. Eine Zeile, die
  /// sich inzwischen wieder geändert hat, bleibt drin.
  Future<void> markClean(TableSpec t, List<Map<String, Object?>> rows) => db.transaction(() async {
    for (final r in rows) {
      await db.markClean(t, r);
    }
  });

  /// Stellt alles noch einmal in die Warteschlange (lokale Daten ziehen in ein neues Konto um).
  Future<void> markAllDirty() async {
    await db.markAllDirty();
    await refreshPending();
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
      id: newId(),
      title: title,
      categoryId: categoryId,
      dueDate: sod(dueDate),
      dueTime: dueTime,
      done: false,
      doneAt: null,
      createdAt: now,
      updatedAt: now,
    );
    _put(t);
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
    _put(t);
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
          _put(
            s
              ..title = next[i].title
              ..done = next[i].done
              ..position = i,
          );
        }
      } else {
        _put(
          Subtask(
            id: newId(),
            taskId: taskId,
            title: next[i].title,
            done: next[i].done,
            position: i,
            updatedAt: nowUtc(),
          ),
        );
      }
    }
    for (var i = next.length; i < old.length; i++) {
      _put(old[i]..deleted = true);
    }
  }

  void toggleTask(Task t) {
    t.done = !t.done;
    t.doneAt = t.done ? nowUtc() : null;
    _put(t);
    if (isYearly(t.title)) _yearlyFollowUp(t);
    _changed();
  }

  /// Geburtstag & Co.: Beim Abhaken entsteht dieselbe Aufgabe für das nächste Jahr – außer es
  /// gibt sie schon. Wird gleich wieder geöffnet (Versehen), verschwindet die eben angelegte,
  /// sofern sie noch unverändert ist; eine selbst angelegte oder bearbeitete bleibt immer stehen.
  void _yearlyFollowUp(Task t) {
    final next = nextYearly(t.dueDate, today());
    if (!t.done) {
      final made = _tasks[_yearlyCopies.remove(t.id)];
      final untouched =
          made != null &&
          !made.deleted &&
          !made.done &&
          made.title == t.title &&
          made.categoryId == t.categoryId &&
          made.dueTime == t.dueTime &&
          sameDay(made.dueDate, next) &&
          made.subs.length == t.subs.length &&
          made.subs.every((s) => !s.done);
      if (untouched) _deleteTask(made);
      return;
    }
    final exists = _tasks.values.any(
      (o) => !o.deleted && !o.done && o.id != t.id && o.title == t.title && sameDay(o.dueDate, next),
    );
    if (!exists) {
      final now = nowUtc();
      final n = Task(
        id: newId(),
        title: t.title,
        categoryId: t.categoryId,
        dueDate: next,
        dueTime: t.dueTime,
        done: false,
        doneAt: null,
        createdAt: now,
        updatedAt: now,
      );
      _put(n);
      _writeSubs(n.id, const [], [for (final s in t.subs) (title: s.title, done: false)]);
      _yearlyCopies[t.id] = n.id;
    }
  }

  void toggleSub(Subtask s) {
    s.done = !s.done;
    _put(s);
    _changed();
  }

  /// Löscht die Aufgabe samt Unteraufgaben und gibt zurück, wie es rückgängig geht.
  /// Wiederhergestellt werden nur die Unteraufgaben, die *dieser* Aufruf gelöscht hat –
  /// nicht solche, die schon vorher (z. B. im Bearbeiten-Sheet) entfernt wurden.
  Undo _deleteTask(Task t) {
    final subs = _subs.values.where((s) => s.taskId == t.id && !s.deleted).toList();
    for (final s in subs) {
      _put(s..deleted = true);
    }
    _put(t..deleted = true);
    return () {
      for (final s in subs) {
        _put(s..deleted = false);
      }
      _put(t..deleted = false);
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
    _put(TaskCategory(id: newId(), name: name, color: color, offset: offset, position: pos, updatedAt: nowUtc()));
    _changed();
  }

  void updateCategory(TaskCategory c, {required String name, required String color, required int offset}) {
    _put(
      c
        ..name = name
        ..color = color
        ..offset = offset,
    );
    _changed();
  }

  /// Löscht eine Kategorie; ihre Aufgaben wandern in die erste verbleibende.
  ({TaskCategory target, int moved, Undo undo})? deleteCategory(TaskCategory c) {
    if (categories.length < 2) return null;
    _put(c..deleted = true);
    final target = categories.first;
    final moved = tasks.where((t) => t.categoryId == c.id).toList();
    for (final t in moved) {
      _put(t..categoryId = target.id);
    }
    _changed();
    return (
      target: target,
      moved: moved.length,
      undo: () {
        _put(c..deleted = false);
        for (final t in moved) {
          _put(t..categoryId = c.id);
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
          _put(t..categoryId = keep.id);
        }
        _put(dup..deleted = true);
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
    _put(Habit(id: newId(), name: name, color: color, position: pos, createdAt: now, updatedAt: now));
    _changed();
  }

  void updateHabit(Habit h, {required String name, required String color}) {
    _put(
      h
        ..name = name
        ..color = color,
    );
    _changed();
  }

  Undo deleteHabit(Habit h) {
    _put(h..deleted = true);
    _changed();
    return () {
      _put(h..deleted = false);
      _changed();
    };
  }

  void _setLog(String habitId, String day, bool done) {
    final l =
        _logs[HabitLog.keyOf(habitId, day)] ?? HabitLog(habitId: habitId, day: day, done: false, updatedAt: nowUtc());
    _put(l..done = done);
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
      _put(
        WeekBlock(
          id: newId(),
          name: name,
          color: color,
          day: d,
          start: start,
          end: end,
          repeat: repeat,
          weekStart: repeat ? null : isoDate(weekStart),
          updatedAt: nowUtc(),
        ),
      );
    }
    _changed();
    return days.length;
  }

  void updateBlock(
    WeekBlock b, {
    required String name,
    required String color,
    required int day,
    required int start,
    required int end,
    required bool repeat,
    required DateTime weekStart,
  }) {
    _put(
      b
        ..name = name
        ..color = color
        ..day = day
        ..start = start
        ..end = end
        ..repeat = repeat
        ..weekStart = repeat ? null : isoDate(weekStart),
    );
    _changed();
  }

  Undo deleteBlock(WeekBlock b) {
    _put(b..deleted = true);
    _changed();
    return () {
      _put(b..deleted = false);
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
      _ingest(t, row);
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
    'habit_logs' => _logs[HabitLog.keyOf(r['habit_id'] as String, (r['day'] as String).substring(0, 10))]?.updatedAt,
    'week_blocks' => _blocks[r['id']]?.updatedAt,
    _ => null,
  };
}
