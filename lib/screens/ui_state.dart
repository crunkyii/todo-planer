import 'package:flutter/foundation.dart';

import '../util/dates.dart';

enum AppTab { tasks, calendar, week, stats, settings }

enum SortMode { date, category, name }

/// Bildschirm-Zustand wie `state` im Prototyp (Tab, Filter, eingeklappte Abschnitte …).
class UiState extends ChangeNotifier {
  AppTab tab = AppTab.tasks;

  /// Unterseite „Kategorien“ in den Optionen.
  bool cats = false;

  /// `alle`, eine Kategorie-ID oder `habits`.
  String filter = 'alle';

  /// Eingeklappte Abschnitte: `Section.name`, `k-<Kategorie>` oder `habits`.
  final Set<String> collapsed = {'done'};
  SortMode sort = SortMode.date;
  bool hideDone = false;

  /// `null` = Suche zu.
  String? search;

  DateTime calMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime calSel = today();
  DateTime weekStart = monday(DateTime.now());

  /// Tagesansicht im Wochenplan (0–6) oder `null` = ganze Woche.
  int? weekDay;
  int statRange = 7;
  String? heatSel;

  /// Richtung der letzten Seiten-Animation (+1 = nach rechts).
  int enterDir = 1;

  /// Art der letzten Wochen-Animation (Zoom in die Tagesansicht oder heraus).
  bool? zoomIn;

  void set(void Function(UiState s) f) {
    f(this);
    notifyListeners();
  }

  void goTab(AppTab t) {
    if (t == tab && !cats) return;
    enterDir = t.index >= tab.index ? 1 : -1;
    tab = t;
    cats = false;
    zoomIn = null;
    notifyListeners();
  }

  void toggleCollapsed(String id) {
    if (!collapsed.remove(id)) collapsed.add(id);
    notifyListeners();
  }

  /// Pfeile im Wochenplan: in der Woche ±7 Tage, in der Tagesansicht ±1 Tag; 0 = heute.
  void weekStep(int dir) {
    zoomIn = null;
    final wd = weekDay;
    if (wd == null) {
      weekStart = dir == 0 ? monday(DateTime.now()) : addDays(weekStart, 7 * dir);
    } else {
      final d = dir == 0 ? today() : addDays(weekStart, wd + dir);
      weekStart = monday(d);
      weekDay = wdIndex(d);
    }
    notifyListeners();
  }

  void toggleWeekDay(int i) {
    zoomIn = weekDay == null;
    weekDay = weekDay == null ? i : null;
    notifyListeners();
  }
}
