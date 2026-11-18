import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/store.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/color_math.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';

/// Startbildschirm-Widgets (nur Android).
///
/// Die Widgets sind natives Android (Kotlin, `android/app/src/main/kotlin/.../widgets`).
/// Sie können die Datenbank der App nicht lesen – darum schreibt die App nach jeder
/// Änderung eine kleine Zusammenfassung als JSON in die Einstellungen ([prefsKey]) und
/// sagt Android über einen Kanal Bescheid, dass neu gezeichnet werden soll.
class HomeWidgets {
  static const prefsKey = 'widget.v1';
  static const _channel = MethodChannel('todo_liste/widgets');

  /// Höchstens so viele offene Aufgaben wandern ins Widget (es zeigt ohnehin nur wenige).
  static const maxTasks = 60;

  /// Wird aufgerufen, wenn im Widget auf „+“ getippt wurde.
  VoidCallback? onNewTask;
  bool _pendingNewTask = false;
  bool _listening = false;
  String? _last;

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Meldet einen „+“-Tipp, der die App gestartet hat, sobald jemand zuhört.
  Future<void> listen(VoidCallback onNewTask) async {
    this.onNewTask = onNewTask;
    if (_pendingNewTask) {
      _pendingNewTask = false;
      onNewTask();
    }
    if (!_android || _listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action' && call.arguments == 'new_task') _newTask();
    });
    try {
      if (await _channel.invokeMethod<String>('initialAction') == 'new_task') _newTask();
    } on MissingPluginException {
      // Tests und andere Plattformen: kein Widget-Kanal.
    }
  }

  void _newTask() {
    final cb = onNewTask;
    if (cb == null) {
      _pendingNewTask = true;
    } else {
      cb();
    }
  }

  /// Schreibt die Zusammenfassung und lässt die Widgets neu zeichnen (nur wenn sich etwas geändert hat).
  Future<void> push(Store store, AppLocalizations l, {required String themeId}) async {
    if (!_android) return;
    final json = jsonEncode(buildWidgetSnapshot(store, l, themeId: themeId));
    if (json == _last) return;
    _last = json;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, json);
      await _channel.invokeMethod<void>('update');
    } on MissingPluginException {
      // Tests: kein Widget-Kanal.
    } on PlatformException catch (e) {
      debugPrint('Widgets nicht aktualisiert: ${e.code}');
    }
  }
}

/// Alles, was die Widgets brauchen – ohne Datum von „heute“: Das rechnet das Widget selbst,
/// damit es auch nach Mitternacht stimmt, wenn die App nicht läuft.
///
/// - `tasks`: offene Aufgaben, nach Fälligkeit sortiert (`t` Titel, `d` Tag, `m` Minuten oder null, `c` Farbe,
///   `k` Kategorie)
/// - `cats`: Kategorien (`id`, `n` Name, `c` Farbe) – jedes Widget kann auf einzelne davon eingestellt werden
/// - `habits`: Gewohnheiten (`n` Name, `c` Farbe, `days` erledigte Tage der letzten 14 Tage)
/// - `labels`: Texte in der Sprache der App; `wd` Wochentage Mo–So; `en` für das Datumsformat
/// - `accent` / `accentDark`: Primärfarbe des gewählten Themes
Map<String, Object?> buildWidgetSnapshot(Store store, AppLocalizations l, {required String themeId}) {
  final f = Fmt(l, l.localeName);
  final open = store.tasks.where((t) => !t.done).toList()..sort((a, b) => a.due.compareTo(b.due));
  final t0 = today();
  final recent = [for (var i = 0; i < 14; i++) isoDate(addDays(t0, -i))];
  final th = themeOf(themeId);
  return {
    'v': 1,
    'en': f.en,
    'accent': toHex(AppTokens.build(th, dark: false).p),
    'accentDark': toHex(AppTokens.build(th, dark: true).p),
    'labels': {
      'today': l.today,
      'tomorrow': l.tomorrow,
      'yesterday': l.yesterday,
      'overdue': l.overdue,
      'upcoming': l.widgetUpcoming,
      'habits': l.habits,
      'nothingDue': l.nothingDue,
      'noHabits': l.widgetNoHabits,
      'newTask': l.newTask,
    },
    'wd': [for (var i = 0; i < 7; i++) f.wd(i)],
    'cats': [
      for (final c in store.categories) {'id': c.id, 'n': c.name, 'c': c.color},
    ],
    'tasks': [
      for (final t in open.take(HomeWidgets.maxTasks))
        {
          't': t.title,
          'd': isoDate(t.dueDate),
          'm': t.dueTime,
          'c': store.catOf(t.categoryId).color,
          'k': t.categoryId,
        },
    ],
    'habits': [
      for (final h in store.habits)
        {'n': h.name, 'c': h.color, 'days': recent.where((d) => store.habitDone(h.id, d)).toList()},
    ],
  };
}
