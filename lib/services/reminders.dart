import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../util/dates.dart';

/// Eine geplante Benachrichtigung (Aufgabe oder Block, in der Zukunft).
class Reminder {
  const Reminder({required this.id, required this.at, required this.title, required this.body, this.taskId});
  final int id;

  /// Die Aufgabe, um die es geht (Block ohne Aufgabe: `null`).
  final String? taskId;
  final DateTime at;
  final String title;
  final String body;
}

/// [minutes] vor [time]. Ganze Tage nach dem Kalender: „1 Tag vorher“ ist auch über die
/// Zeitumstellung hinweg dieselbe Uhrzeit. Der Rest ist echte Zeit.
DateTime _before(DateTime time, int minutes) {
  const day = 24 * 60;
  return DateTime(
    time.year,
    time.month,
    time.day - minutes ~/ day,
    time.hour,
    time.minute,
  ).subtract(Duration(minutes: minutes % day));
}

/// So viele Tage im Voraus werden Blöcke geplant. Die App plant bei jedem Start neu.
const _blockDays = 14;

/// Wählt die nächsten offenen Aufgaben mit Uhrzeit aus, die sich melden sollen (höchstens [limit]).
List<Reminder> upcomingReminders(Iterable<Task> tasks, String Function(Task) body, {DateTime? now, int limit = 40}) {
  final n = now ?? clock();
  final list = [
    for (final t in tasks)
      if (!t.done && !t.deleted && t.hasTime && t.remind != remindNone)
        if (_before(t.due, t.remind) case final at when at.isAfter(n)) (t, at),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [
    for (final (t, at) in list.take(limit))
      Reminder(id: t.id.hashCode & 0x7fffffff, at: at, title: t.title, body: body(t), taskId: t.id),
  ];
}

/// Die nächsten Blöcke, die sich melden sollen (höchstens [limit]). [blocksOn] liefert die
/// Blöcke eines Tages, [body] bekommt den Block und seinen Tag. Einmalige Blöcke, deren Aufgabe
/// erledigt ist ([taskDone]), melden sich nicht; wöchentliche gehen weiter.
List<Reminder> upcomingBlockReminders(
  List<WeekBlock> Function(DateTime day) blocksOn,
  String Function(WeekBlock, DateTime day) body, {
  bool Function(String taskId)? taskDone,
  DateTime? now,
  int limit = 60,
}) {
  final n = now ?? clock();
  final end = addDays(n, _blockDays);
  final list = <(WeekBlock, DateTime, DateTime)>[];
  // Ein Block mit einer Woche Vorlauf meldet sich schon, wenn er selbst noch weiter weg ist.
  for (var i = 0; i <= _blockDays + remindMax ~/ (24 * 60); i++) {
    final day = addDays(sod(n), i);
    for (final b in blocksOn(day)) {
      if (b.remind == remindNone) continue;
      if (b.taskId case final id? when !b.repeat && (taskDone?.call(id) ?? false)) continue;
      final at = _before(DateTime(day.year, day.month, day.day, 0, b.start), b.remind);
      if (at.isAfter(n) && at.isBefore(end)) list.add((b, day, at));
    }
  }
  list.sort((a, b) => a.$3.compareTo(b.$3));
  return [
    for (final (b, day, at) in list.take(limit))
      Reminder(
        id: '${b.id}@${isoDate(day)}'.hashCode & 0x7fffffff,
        at: at,
        title: b.name,
        body: body(b, day),
        taskId: b.taskId,
      ),
  ];
}

/// Alles zusammen. Meldet sich eine Aufgabe schon selbst genau dann, wenn auch ihr Block
/// dran wäre, kommt nur die eine Benachrichtigung.
List<Reminder> mergeReminders(List<Reminder> tasks, List<Reminder> blocks) {
  final seen = {for (final r in tasks) (r.taskId, r.at)};
  return [
    ...tasks,
    for (final r in blocks)
      if (r.taskId == null || !seen.contains((r.taskId, r.at))) r,
  ];
}

/// Erinnerungen per System-Benachrichtigung (Android, Windows). Unter Linux kann das
/// Plugin nicht vorplanen – dort erinnert die App, solange sie läuft (Timer).
class Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  final List<Timer> _timers = [];
  bool _ready = false;
  bool _asked = false;
  String _channelName = 'Reminders';
  String _channelDesc = '';

  bool get _canSchedule => !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  Future<void> init({required String appName}) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isWindows || Platform.isLinux)) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(defaultActionName: appName),
          windows: WindowsInitializationSettings(
            appName: appName,
            appUserModelId: 'at.todoliste.app',
            guid: '6a1f6b0e-3c2d-4f5e-9a7b-2c1d0e9f8a71',
          ),
        ),
      );
      _ready = true;
    } on Object catch (e) {
      debugPrint('Erinnerungen nicht verfügbar: ${e.runtimeType}');
    }
  }

  void setTexts({required String channelName, required String channelDesc}) {
    _channelName = channelName;
    _channelDesc = channelDesc;
  }

  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    ),
    linux: const LinuxNotificationDetails(),
    windows: const WindowsNotificationDetails(),
  );

  Future<void> _last = Future.value();
  int _run = 0;

  /// Plant alle Erinnerungen neu. [enabled] = Schalter „Erinnerungen“. Läuft noch eine Planung,
  /// hört sie auf – sonst legte sie nach dem Löschen hier noch Veraltetes an.
  Future<void> reschedule(List<Reminder> items, {required bool enabled}) {
    final run = ++_run;
    return _last = _last.then((_) => run == _run ? _reschedule(items, run, enabled: enabled) : null);
  }

  Future<void> _reschedule(List<Reminder> items, int run, {required bool enabled}) async {
    if (!_ready) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    try {
      // Am Handy bleibt stehen, was schon angezeigt wird; nur das Geplante fällt weg.
      if (_canSchedule) await (Platform.isAndroid ? _plugin.cancelAllPendingNotifications() : _plugin.cancelAll());
      if (!enabled || items.isEmpty) return;
      if (Platform.isAndroid && !_asked) {
        _asked = true;
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      for (final r in items) {
        if (run != _run) return;
        if (_canSchedule) {
          await _plugin.zonedSchedule(
            id: r.id,
            title: r.title,
            body: r.body,
            scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } else {
          final wait = r.at.difference(DateTime.now());
          if (wait.inDays > 7) continue;
          _timers.add(
            Timer(wait, () => _plugin.show(id: r.id, title: r.title, body: r.body, notificationDetails: _details)),
          );
        }
      }
    } on Object catch (e) {
      debugPrint('Erinnerungen konnten nicht geplant werden: ${e.runtimeType}');
    }
  }
}
