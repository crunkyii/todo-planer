import 'dart:math';

import '../util/dates.dart';

/// Datenmodelle der App. Jedes Modell hat `toJson()` mit denselben Spaltennamen
/// wie in Supabase (`supabase/schema.sql`) und in der lokalen Datenbank.
/// `updatedAt` (UTC) entscheidet bei Konflikten: der neueste Stand gewinnt.
/// `deleted` ist ein Grabstein, damit Löschungen auf andere Geräte kommen.

final _rnd = Random.secure();

/// Zufällige UUID v4 (für Supabase-Spalten vom Typ uuid).
String newId() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

DateTime nowUtc() => DateTime.now().toUtc();

bool _b(Object? v) => v == true || v == 1;
DateTime _t(Object? v) => DateTime.parse(v as String).toUtc();
DateTime? _tn(Object? v) => v == null ? null : _t(v);
String _ts(DateTime d) => d.toUtc().toIso8601String();

class TaskCategory {
  TaskCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.offset,
    required this.position,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  String name;
  String color;

  /// Vorlauf in Tagen: so viele Tage vor der Fälligkeit erscheint die Aufgabe.
  int offset;
  int position;
  DateTime updatedAt;
  bool deleted;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'offset_days': offset,
        'position': position,
        'updated_at': _ts(updatedAt),
        'deleted': deleted,
      };

  factory TaskCategory.fromJson(Map<String, Object?> j) => TaskCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as String,
        offset: (j['offset_days'] as num).toInt(),
        position: (j['position'] as num).toInt(),
        updatedAt: _t(j['updated_at']),
        deleted: _b(j['deleted']),
      );
}

class Subtask {
  Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.done,
    required this.position,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String taskId;
  String title;
  bool done;
  int position;
  DateTime updatedAt;
  bool deleted;

  Map<String, Object?> toJson() => {
        'id': id,
        'task_id': taskId,
        'title': title,
        'done': done,
        'position': position,
        'updated_at': _ts(updatedAt),
        'deleted': deleted,
      };

  factory Subtask.fromJson(Map<String, Object?> j) => Subtask(
        id: j['id'] as String,
        taskId: j['task_id'] as String,
        title: j['title'] as String,
        done: _b(j['done']),
        position: (j['position'] as num).toInt(),
        updatedAt: _t(j['updated_at']),
        deleted: _b(j['deleted']),
      );
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.dueDate,
    required this.dueTime,
    required this.done,
    required this.doneAt,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    List<Subtask>? subs,
  }) : subs = subs ?? [];

  final String id;
  String title;
  String categoryId;

  /// Fälligkeitstag (lokales Datum, ohne Uhrzeit).
  DateTime dueDate;

  /// Uhrzeit in Minuten seit Mitternacht oder `null` = ganztägig.
  int? dueTime;
  bool done;
  DateTime? doneAt;
  final DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  /// Nicht gelöschte Unteraufgaben, sortiert. Wird vom Store gepflegt.
  List<Subtask> subs;

  bool get hasTime => dueTime != null;

  /// Fälligkeit als lokaler Zeitpunkt (ganztägig = Mitternacht).
  DateTime get due => dueDate.add(Duration(minutes: dueTime ?? 0));

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'category_id': categoryId,
        'due_date': isoDate(dueDate),
        'due_time': dueTime == null ? null : hmString(dueTime!),
        'done': done,
        'done_at': doneAt == null ? null : _ts(doneAt!),
        'created_at': _ts(createdAt),
        'updated_at': _ts(updatedAt),
        'deleted': deleted,
      };

  factory Task.fromJson(Map<String, Object?> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        categoryId: j['category_id'] as String,
        dueDate: parseIsoDate(j['due_date'] as String),
        dueTime: j['due_time'] == null ? null : parseHm(j['due_time'] as String),
        done: _b(j['done']),
        doneAt: _tn(j['done_at']),
        createdAt: _t(j['created_at']),
        updatedAt: _t(j['updated_at']),
        deleted: _b(j['deleted']),
      );
}

class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  String name;
  String color;
  int position;
  final DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'position': position,
        'created_at': _ts(createdAt),
        'updated_at': _ts(updatedAt),
        'deleted': deleted,
      };

  factory Habit.fromJson(Map<String, Object?> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as String,
        position: (j['position'] as num).toInt(),
        createdAt: _t(j['created_at']),
        updatedAt: _t(j['updated_at']),
        deleted: _b(j['deleted']),
      );
}

/// Ein abgehakter (oder wieder geöffneter) Tag einer Gewohnheit.
class HabitLog {
  HabitLog({required this.habitId, required this.day, required this.done, required this.updatedAt});

  final String habitId;

  /// Tag als `yyyy-mm-dd`.
  final String day;
  bool done;
  DateTime updatedAt;

  String get key => '$habitId|$day';

  Map<String, Object?> toJson() => {
        'habit_id': habitId,
        'day': day,
        'done': done,
        'updated_at': _ts(updatedAt),
      };

  factory HabitLog.fromJson(Map<String, Object?> j) => HabitLog(
        habitId: j['habit_id'] as String,
        day: (j['day'] as String).substring(0, 10),
        done: _b(j['done']),
        updatedAt: _t(j['updated_at']),
      );
}

/// Ein Block im Wochenplan.
class WeekBlock {
  WeekBlock({
    required this.id,
    required this.name,
    required this.color,
    required this.day,
    required this.start,
    required this.end,
    required this.repeat,
    required this.weekStart,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  String name;
  String color;

  /// Wochentag 0 = Montag … 6 = Sonntag.
  int day;

  /// Minuten seit Mitternacht.
  int start;
  int end;

  /// `true` = jede Woche, sonst nur in der Woche [weekStart] (Montag, `yyyy-mm-dd`).
  bool repeat;
  String? weekStart;
  DateTime updatedAt;
  bool deleted;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'day': day,
        'start_min': start,
        'end_min': end,
        'repeat': repeat,
        'week_start': weekStart,
        'updated_at': _ts(updatedAt),
        'deleted': deleted,
      };

  factory WeekBlock.fromJson(Map<String, Object?> j) => WeekBlock(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as String,
        day: (j['day'] as num).toInt(),
        start: (j['start_min'] as num).toInt(),
        end: (j['end_min'] as num).toInt(),
        repeat: _b(j['repeat']),
        weekStart: (j['week_start'] as String?)?.substring(0, 10),
        updatedAt: _t(j['updated_at']),
        deleted: _b(j['deleted']),
      );
}
