import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../screens/ui_state.dart';

/// Was ein Aufruf von außen verlangt, z. B. aus dem Launcher Flick (`todoplaner://…`).
///
/// Absichtlich kann ein Aufruf nur etwas **zeigen** (Tab, leeres Formular) – nie Daten ändern.
/// Jede Webseite kann einen `todoplaner://`-Link anbieten; gespeichert wird erst, wenn man selbst
/// im Formular auf „Hinzufügen“ tippt.
sealed class LaunchCommand {
  const LaunchCommand();
}

/// `todoplaner://tab/<name>` – die App in diesem Tab zeigen. Bei „Aufgaben“ kann `?zeile=…` die
/// Zeile aus der Flick-Liste mitbringen; deren Aufgabe wird dann hervorgehoben.
final class OpenTab extends LaunchCommand {
  const OpenTab(this.tab, {this.row});
  final AppTab tab;

  /// Ordnername der gewählten Flick-Zeile (`lib/services/flick_export.dart`), `null` = keine.
  final String? row;

  @override
  bool operator ==(Object other) => other is OpenTab && other.tab == tab && other.row == row;

  @override
  int get hashCode => Object.hash(tab, row);

  @override
  String toString() => 'OpenTab(${tab.name}, $row)';
}

/// `todoplaner://add` (optional `?title=…`) – das Formular „Neue Aufgabe“ öffnen.
final class NewTask extends LaunchCommand {
  const NewTask({this.title});

  /// Vorgabe für den Titel (schon gekürzt), `null` = leer.
  final String? title;

  @override
  bool operator ==(Object other) => other is NewTask && other.title == title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() => 'NewTask($title)';
}

/// Das URL-Schema, das der Windows-Installer für die App einträgt.
const launchScheme = 'todoplaner';

/// Längster Titel, der über einen Link ins Formular kommt (der Rest wird abgeschnitten).
const maxLaunchTitle = 200;

/// Namen der Tabs in Links – deutsch und englisch, ohne Groß-/Kleinschreibung.
const _tabNames = {
  'aufgaben': AppTab.tasks,
  'tasks': AppTab.tasks,
  'kalender': AppTab.calendar,
  'calendar': AppTab.calendar,
  'woche': AppTab.week,
  'wochenplan': AppTab.week,
  'week': AppTab.week,
  'statistik': AppTab.stats,
  'stats': AppTab.stats,
  'statistics': AppTab.stats,
  'optionen': AppTab.settings,
  'einstellungen': AppTab.settings,
  'settings': AppTab.settings,
  'options': AppTab.settings,
};

/// Liest den ersten `todoplaner:`-Link aus den Start-Argumenten. Andere Argumente und
/// unbekannte Links ergeben `null` (die App startet dann ganz normal).
LaunchCommand? parseLaunchCommand(Iterable<String> args) {
  for (final a in args) {
    final uri = Uri.tryParse(a.trim());
    if (uri == null || uri.scheme.toLowerCase() != launchScheme) continue;
    // `todoplaner://tab/kalender` → host „tab“, Pfad „/kalender“; `todoplaner:tab/kalender` → nur Pfad.
    final parts = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ].map((s) => s.toLowerCase()).toList();
    if (parts.isEmpty) return null;
    switch (parts.first) {
      case 'add' || 'new' || 'neu':
        final Map<String, String> query;
        try {
          query = uri.queryParameters;
        } on FormatException {
          return const NewTask();
        }
        final title = (query['title'] ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (title.isEmpty) return const NewTask();
        return NewTask(title: _cut(title, maxLaunchTitle));
      case 'tab' when parts.length > 1:
        final tab = _tabNames[parts[1]];
        if (tab == null) return null;
        String? row;
        try {
          row = uri.queryParameters['zeile'];
        } on FormatException {
          row = null;
        }
        return OpenTab(tab, row: tab == AppTab.tasks && row != null && row.isNotEmpty ? row : null);
      case final name:
        // Kurzform `todoplaner://kalender`.
        final tab = _tabNames[name];
        return tab == null ? null : OpenTab(tab);
    }
  }
  return null;
}

/// Kürzt [s] auf höchstens [max] UTF-16-Einheiten, ohne ein Emoji (Surrogat-Paar) zu zerteilen.
String _cut(String s, int max) {
  if (s.length <= max) return s;
  final end = (s.codeUnitAt(max - 1) & 0xFC00) == 0xD800 ? max - 1 : max;
  return s.substring(0, end);
}

/// Nimmt Aufrufe von außen an: beim Start über die Argumente, danach vom Windows-Runner, wenn die
/// App schon läuft und ein zweiter Start seine Argumente an dieses Fenster weiterreicht
/// (`windows/runner/single_instance.cpp`).
class LaunchCommands {
  LaunchCommands([List<String> startArgs = const []]) : _pending = parseLaunchCommand(startArgs);

  static const _channel = MethodChannel('todo_liste/launch');

  void Function(LaunchCommand)? _onCommand;
  LaunchCommand? _pending;
  bool _listening = false;

  /// Hört auf den Kanal des Runners. Früh aufrufen (in `main`), damit kein Aufruf verloren geht,
  /// solange die App noch bei der Einrichtung oder Anmeldung steht.
  void attach() {
    if (_listening || kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is List) {
        final cmd = parseLaunchCommand([for (final a in call.arguments as List) '$a']);
        if (cmd != null) deliver(cmd);
      }
    });
  }

  /// Wer gerade zuhört (`null` = niemand).
  void Function(LaunchCommand)? get handler => _onCommand;

  /// Der App-Bildschirm meldet sich an; ein wartender Aufruf kommt sofort. `null` = abgemeldet.
  set onCommand(void Function(LaunchCommand)? cb) {
    _onCommand = cb;
    final p = _pending;
    if (cb != null && p != null) {
      _pending = null;
      cb(p);
    }
  }

  /// Gibt den Aufruf weiter – oder hebt ihn auf, bis der App-Bildschirm da ist.
  void deliver(LaunchCommand cmd) {
    final cb = _onCommand;
    if (cb == null) {
      _pending = cmd;
    } else {
      cb(cmd);
    }
  }
}
