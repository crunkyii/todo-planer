import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/color_math.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/task_logic.dart';

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

  Store? _store;

  /// Meldet einen „+“-Tipp, der die App gestartet hat, sobald jemand zuhört, und übernimmt
  /// Gewohnheiten, die im Widget abgehakt wurden, in [store].
  Future<void> listen(VoidCallback onNewTask, {Store? store}) async {
    this.onNewTask = onNewTask;
    _store = store;
    if (_pendingNewTask) {
      _pendingNewTask = false;
      onNewTask();
    }
    if (!_android || _listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action' && call.arguments == 'new_task') _newTask();
      if (call.method == 'action' && call.arguments == 'habits') await applyHabitToggles();
    });
    await applyHabitToggles();
    try {
      if (await _channel.invokeMethod<String>('initialAction') == 'new_task') _newTask();
    } on MissingPluginException {
      // Tests und andere Plattformen: kein Widget-Kanal.
    }
  }

  /// Holt die im Widget abgehakten Gewohnheiten von Android und trägt sie in die Daten ein
  /// (beim Start, beim Zurückkommen in die App und sofort, wenn die App im Hintergrund läuft).
  Future<void> applyHabitToggles() async {
    final store = _store;
    if (!_android || store == null) return;
    try {
      applyWidgetHabitToggles(store, await _channel.invokeMethod<String>('takeHabitToggles'));
    } on MissingPluginException {
      // Tests: kein Widget-Kanal.
    } on PlatformException catch (e) {
      debugPrint('Widget-Gewohnheiten nicht übernommen: ${e.code}');
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

/// Trägt ein, was im Widget abgehakt wurde. [json] ist der Merkzettel von Android:
/// `{"<Gewohnheit>|<Tag>": true/false}` – der zuletzt gewünschte Zustand je Gewohnheit und Tag.
/// Unbekannte Gewohnheiten und kaputte Einträge werden übersprungen. Gibt zurück, wie viele
/// Tage sich geändert haben.
int applyWidgetHabitToggles(Store store, String? json) {
  if (json == null) return 0;
  final Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException {
    return 0;
  }
  if (data is! Map<String, dynamic>) return 0;
  final known = {for (final h in store.habits) h.id};
  var changed = 0;
  data.forEach((key, done) {
    final cut = key.lastIndexOf('|');
    if (cut <= 0 || done is! bool) return;
    final id = key.substring(0, cut);
    final day = key.substring(cut + 1);
    if (!known.contains(id) || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return;
    if (store.habitDone(id, day) != done) {
      store.toggleHabitDay(id, day);
      changed++;
    }
  });
  return changed;
}

/// Alles, was die Widgets brauchen – ohne Datum von „heute“: Das rechnet das Widget selbst,
/// damit es auch nach Mitternacht stimmt, wenn die App nicht läuft.
///
/// - `tasks`: offene Aufgaben, nach Fälligkeit sortiert (`t` Titel, `d` Abgabetag, `s` Tag, ab dem sie in der
///   Liste steht (Abgabe minus Vorlauf der Kategorie), `m` Minuten oder null, `c` Farbe,
///   `k` Kategorie)
/// - `cats`: Kategorien (`id`, `n` Name, `c` Farbe) – jedes Widget kann auf einzelne davon eingestellt werden
/// - `habits`: Gewohnheiten (`id`, `n` Name, `c` Farbe, `days` erledigte Tage der letzten 14 Tage)
/// - `labels`: Texte in der Sprache der App (`until`/`untilDate` mit `{}` als Platz für Tag/Uhrzeit);
///   `wd` Wochentage Mo–So; `mon` Monate kurz (Jän.–Dez.); `en`/`lang` für das Datumsformat
/// - `accent` / `accentDark`: Primärfarbe des gewählten Themes
Map<String, Object?> buildWidgetSnapshot(Store store, AppLocalizations l, {required String themeId}) {
  final f = Fmt(l);
  int offset(Task t) => store.catOf(t.categoryId).offset;
  // Gleiche Reihenfolge wie die Aufgabenliste der App.
  final open = openTasksByDo(store.tasks, offset);
  final t0 = today();
  final recent = [for (var i = 0; i < 14; i++) isoDate(addDays(t0, -i))];
  final th = themeOf(themeId);
  return {
    // Version des Formats – noch liest sie niemand; sie ist für spätere Änderungen da.
    'v': 1,
    'en': f.en,
    'lang': l.localeName,
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
      'until': l.widgetUntil('{}'),
      'untilDate': l.widgetUntilDate('{}'),
    },
    'wd': [for (var i = 0; i < 7; i++) f.wd(i)],
    'mon': [for (var m = 1; m <= 12; m++) f.monShort(DateTime(2024, m))],
    'cats': [
      for (final c in store.categories) {'id': c.id, 'n': c.name, 'c': c.color},
    ],
    'tasks': [
      for (final t in open.take(HomeWidgets.maxTasks))
        {
          't': t.title,
          'd': isoDate(t.dueDate),
          's': isoDate(doDate(t, offset(t))),
          'm': t.dueTime,
          'c': store.catOf(t.categoryId).color,
          'k': t.categoryId,
        },
    ],
    'habits': [
      for (final h in store.habits)
        {'id': h.id, 'n': h.name, 'c': h.color, 'days': recent.where((d) => store.habitDone(h.id, d)).toList()},
    ],
  };
}
