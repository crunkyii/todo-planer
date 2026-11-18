import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../util/dates.dart';

/// Eine geplante Erinnerung (Aufgabe mit Uhrzeit, noch offen, in der Zukunft).
class Reminder {
  const Reminder({required this.id, required this.at, required this.title, required this.body});
  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// Wählt die nächsten offenen Aufgaben mit Uhrzeit aus (höchstens [limit]).
List<Reminder> upcomingReminders(Iterable<Task> tasks, String Function(Task) body, {DateTime? now, int limit = 40}) {
  final n = now ?? clock();
  final list = tasks.where((t) => !t.done && !t.deleted && t.hasTime && t.due.isAfter(n)).toList()
    ..sort((a, b) => a.due.compareTo(b.due));
  return [
    for (final t in list.take(limit))
      Reminder(id: t.id.hashCode & 0x7fffffff, at: t.due, title: t.title, body: body(t)),
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

  /// Plant alle Erinnerungen neu. [enabled] = Schalter „Erinnerungen“.
  Future<void> reschedule(List<Reminder> items, {required bool enabled}) async {
    if (!_ready) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    try {
      if (_canSchedule) await _plugin.cancelAll();
      if (!enabled || items.isEmpty) return;
      if (Platform.isAndroid && !_asked) {
        _asked = true;
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      for (final r in items) {
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
