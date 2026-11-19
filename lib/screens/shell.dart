import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/sync_service.dart';
import '../services/flick_export.dart';
import '../services/launch_commands.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/tokens.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/layout.dart';
import '../widgets/overlays.dart';
import '../widgets/pressable.dart';
import '../widgets/snack.dart';
import '../widgets/ui.dart';
import 'calendar_tab.dart';
import 'settings_tab.dart';
import 'sheets.dart';
import 'stats_tab.dart';
import 'tasks_tab.dart';
import 'ui_state.dart';
import 'week_tab.dart';

/// Der Haupt-Bildschirm: Inhalt des Tabs, FAB, Glas-Navigation unten und Meldungen.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ui = UiState();
  StreamSubscription<SyncEvent>? _sub;
  late final _widgets = context.app.homeWidgets;
  late final _launch = context.app.launch;
  AppLifecycleListener? _resume;

  /// Hält den Zustand der Seite (Scroll-Position), wenn das Fenster zwischen schmal und breit wechselt.
  final _pageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final app = context.app;
    _sub = app.sync.events.listen(_onSync);
    // „+“ im Startbildschirm-Widget: Sheet für eine neue Aufgabe öffnen.
    _widgets.listen(_newTask, store: app.store);
    // Aufruf von außen (Launcher Flick, `todoplaner://…`).
    _launch.onCommand = _onLaunch;
    // Zurück in der App: im Widget abgehakte Gewohnheiten übernehmen.
    _resume = AppLifecycleListener(onResume: _widgets.applyHabitToggles);
  }

  /// Öffnet das Formular „Neue Aufgabe“ über allem, was gerade offen ist – außer es ist schon eins offen.
  void _newTask({String? title}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      // Liefert die oberste Route, ohne etwas zu schließen.
      Route<dynamic>? top;
      nav.popUntil((route) {
        top = route;
        return true;
      });
      // Schon ein Formular offen (z. B. mehrmals auf „+“ getippt): kein zweites darüber.
      if (top is AppSheetRoute) return;
      // Ein offenes ⋮-Menü zuerst schließen, sonst läge das Formular über dem Menü.
      if (top is AppMenuRoute) nav.pop();
      Sheets(context, ui).task(null, title: title);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _onLaunch(LaunchCommand cmd) {
    switch (cmd) {
      case NewTask(:final title):
        _newTask(title: title);
      case OpenTab(:final tab, :final row):
        // Ein offenes Formular oder Menü bleibt, wie es ist (nichts Getipptes geht verloren);
        // nur ein ⋮-Menü schließt sich, damit man den Tab auch sieht.
        final nav = Navigator.of(context);
        Route<dynamic>? top;
        nav.popUntil((route) {
          top = route;
          return true;
        });
        if (top is AppMenuRoute) nav.pop();
        ui.goTab(tab);
        if (row != null) _focusFlickRow(row);
    }
  }

  /// Flick: Enter auf einer Zeile der heutigen Aufgaben – deren Karte sichtbar machen und hervorheben.
  void _focusFlickRow(String row) {
    final store = context.app.store;
    final t = flickTaskForRow(store, context.l, row);
    if (t == null) return;
    ui.set((x) {
      // Nichts darf die Karte verstecken: Suche, Filter, „Erledigte ausblenden“ passt (sie ist offen).
      x.search = null;
      x.filter = filterAll;
      x.collapsed
        ..remove(sectionOf(t, store.catOf(t.categoryId).offset).name)
        ..remove('k-${t.categoryId}');
    });
    ui.focusTask.value = t.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.app.enterApp(context.l);
  }

  void _onSync(SyncEvent e) {
    final l = context.l;
    final s = context.app.snack;
    switch (e) {
      case WentOffline():
        s.show(l.offlineToast, icon: Ic.cloudoff);
      case BackOnline(:final pending):
        s.show(pending > 0 ? l.backOnlineSyncing(pending) : l.backOnline, icon: pending > 0 ? Ic.sync : Ic.cloudok);
      case AllSynced():
        s.show(l.allSynced, icon: Ic.cloudok);
      case SchemaOutdated():
        s.show(l.schemaOutdated, icon: Ic.database);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _widgets.onNewTask = null;
    // Nur abmelden, wenn nicht schon ein neuer App-Bildschirm übernommen hat (Wechsel mit Animation).
    if (_launch.handler == _onLaunch) _launch.onCommand = null;
    _resume?.dispose();
    ui.dispose();
    super.dispose();
  }

  /// Was der +-Knopf im aktuellen Tab macht (Beschriftung und Aktion an einer Stelle).
  ({String label, VoidCallback onTap})? _fab(AppLocalizations l) {
    final sheets = Sheets(context, ui);
    return switch (ui.tab) {
      AppTab.settings => ui.cats ? (label: l.newCategory, onTap: () => sheets.category(null)) : null,
      AppTab.week => (label: l.newBlock, onTap: () => sheets.newBlock()),
      AppTab.stats => (label: l.newHabit, onTap: () => sheets.habit(null)),
      AppTab.tasks when ui.filter == filterHabits => (label: l.newHabit, onTap: () => sheets.habit(null)),
      _ => (label: l.newTask, onTap: () => sheets.task(null, preset: ui.tab == AppTab.calendar ? ui.calSel : null)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l;
    final mq = MediaQuery.of(context);
    final low = mq.size.height < Sizes.lowHeight;
    final wide = Sizes.isWide(mq.size);
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: BlobBackground(
        child: ListenableBuilder(
          listenable: ui,
          builder: (context, _) {
            final fab = _fab(l);
            final page = Padding(
              padding: EdgeInsets.only(top: mq.padding.top),
              child: _PageSwitcher(key: _pageKey, ui: ui, child: _tab()),
            );
            // Breit (PC): Navigation und „Neu“-Knopf links, der Inhalt nutzt den Platz daneben.
            if (wide) {
              return ShellLayout(
                wide: true,
                child: Row(
                  children: [
                    _SideNav(ui: ui, fab: fab),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: _wideWidth),
                                child: page,
                              ),
                            ),
                          ),
                          SnackHost(controller: app.snack, undoLabel: l.undo, bottom: Sizes.wideBottom),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.maxWidth),
                child: Stack(
                  children: [
                    Positioned.fill(child: page),
                    // Schlüssel: In den Optionen fehlt der Plus-Knopf. Ohne Schlüssel rückt die Leiste dann
                    // auf seinen Platz, wird neu aufgebaut – und ihr Balken springt, statt zu gleiten.
                    if (fab != null)
                      Positioned(
                        key: const ValueKey('fab'),
                        right: Sizes.fabRight,
                        bottom: (low ? 78 : Sizes.fabBottom) + mq.padding.bottom,
                        child: _Fab(label: fab.label, onTap: fab.onTap, size: low ? 54 : Sizes.fab),
                      ),
                    Positioned(
                      key: const ValueKey('nav'),
                      left: Sizes.navGap,
                      right: Sizes.navGap,
                      bottom: (low ? 8 : Sizes.navGap) + mq.padding.bottom,
                      child: _GlassNav(ui: ui, height: low ? 58 : Sizes.navH),
                    ),
                    SnackHost(controller: app.snack, undoLabel: l.undo, bottom: low ? 76 : Sizes.fabBottom),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Wie breit der Inhalt im breiten Layout wird: Listen bleiben lesbar, Raster nutzen den Platz.
  double get _wideWidth => switch (ui.tab) {
    AppTab.week => Sizes.wideWeek,
    AppTab.tasks => Sizes.wideBoard,
    AppTab.calendar || AppTab.stats => Sizes.wideGrid,
    AppTab.settings => Sizes.wideList,
  };

  Widget _tab() => switch (ui.tab) {
    AppTab.tasks => TasksTab(key: const ValueKey('tasks'), ui: ui),
    AppTab.calendar => CalendarTab(key: const ValueKey('calendar'), ui: ui),
    AppTab.week => WeekTab(key: const ValueKey('week'), ui: ui),
    AppTab.stats => StatsTab(key: const ValueKey('stats'), ui: ui),
    AppTab.settings =>
      ui.cats
          ? CategoriesPage(key: const ValueKey('cats'), ui: ui)
          : SettingsTab(key: const ValueKey('settings'), ui: ui),
  };
}

/// Seitenwechsel gleitet in Richtung des Tabs (enter-r / enter-l).
class _PageSwitcher extends StatelessWidget {
  const _PageSwitcher({super.key, required this.ui, required this.child});
  final UiState ui;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return AnimatedSwitcher(
      duration: Motion.page,
      switchInCurve: Motion.enter,
      switchOutCurve: const Threshold(0),
      layoutBuilder: (current, previous) => Stack(children: [?current]),
      // Die Feder-Kurve schießt über 1 hinaus – deshalb die Deckkraft begrenzen.
      transitionBuilder: (c, a) => AnimatedBuilder(
        animation: a,
        builder: (context, w) => Opacity(
          opacity: (a.value * 2).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(36 * ui.enterDir * (1 - a.value), 0), child: w),
        ),
        child: c,
      ),
      child: child,
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.label, required this.onTap, required this.size});
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: tok.p, boxShadow: tok.fabShadow),
        child: AppIcon(Ic.plus, size: 28, stroke: 2.2, color: tok.onP),
      ),
    );
  }
}

/// Die Tabs der Navigation: Tab, kurze Beschriftung, Symbol, Beschriftung für Screenreader.
List<(AppTab, String, Ic, String)> _navTabs(AppLocalizations l) => [
  (AppTab.tasks, l.navTasks, Ic.tasks, l.navTasks),
  (AppTab.calendar, l.navCalendar, Ic.calendar, l.navCalendar),
  (AppTab.week, l.navWeek, Ic.week, l.weeklyPlan),
  (AppTab.stats, l.navStats, Ic.stats, l.statistics),
  (AppTab.settings, l.navSettings, Ic.settings, l.settings),
];

/// Navigation am linken Rand (breites Layout): App-Name, „Neu“-Knopf und die Tabs untereinander.
class _SideNav extends StatelessWidget {
  const _SideNav({required this.ui, required this.fab});
  final UiState ui;
  final ({String label, VoidCallback onTap})? fab;

  static const double _itemH = 48;
  static const double _buttonH = 40;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final tabs = _navTabs(l);
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(Sizes.navGap, Sizes.navGap + top, 0, Sizes.navGap),
      child: SizedBox(
        width: Sizes.sideNavW,
        child: Glass(
          color: tok.glass,
          blur: 22,
          radius: BorderRadius.circular(Sizes.rNav),
          border: Border.all(color: tok.glassEdge),
          shadow: tok.navShadow,
          // Scrollbar: Bei niedrigem Fenster oder großer Schrift passt nicht alles untereinander.
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    child: Text(
                      l.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: tok.text),
                    ),
                  ),
                  // In den Optionen gibt es nichts anzulegen: Der Platz bleibt, damit die Tabs nicht springen.
                  if (fab case final f?)
                    AppButton(label: f.label, icon: Ic.plus, height: _buttonH, onTap: f.onTap)
                  else
                    const SizedBox(height: _buttonH),
                  const SizedBox(height: 16),
                  Semantics(
                    container: true,
                    label: l.mainNavigation,
                    explicitChildNodes: true,
                    child: SizedBox(
                      height: _itemH * tabs.length,
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: Motion.of(context, Motion.nav),
                            curve: Motion.springNav,
                            top: _itemH * ui.tab.index,
                            left: 0,
                            right: 0,
                            height: _itemH,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: tok.pc,
                                borderRadius: BorderRadius.circular(Sizes.rNavInd),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              for (final t in tabs)
                                SizedBox(
                                  height: _itemH,
                                  child: Pressable(
                                    onTap: () => ui.goTab(t.$1),
                                    semanticLabel: t.$4,
                                    selected: ui.tab == t.$1,
                                    // Die Zeile ist breit: nur ein Hauch Feder, sonst hüpft die Schrift.
                                    pressScale: 0.985,
                                    overshoot: 0.01,
                                    radius: BorderRadius.circular(Sizes.rNavInd),
                                    excludeChildSemantics: true,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: Row(
                                        children: [
                                          AppIcon(t.$3, size: 22, color: ui.tab == t.$1 ? tok.onPc : tok.sub),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              t.$4,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: ui.tab == t.$1 ? tok.onPc : tok.sub,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Schwebende Milchglas-Navigation mit gleitendem Indikator (Feder-Kurve).
class _GlassNav extends StatelessWidget {
  const _GlassNav({required this.ui, required this.height});
  final UiState ui;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final tabs = _navTabs(l);
    final idx = ui.tab.index;
    return Semantics(
      container: true,
      label: l.mainNavigation,
      explicitChildNodes: true,
      child: Glass(
        color: tok.glass,
        blur: 22,
        radius: BorderRadius.circular(Sizes.rNav),
        border: Border.all(color: tok.glassEdge),
        shadow: tok.navShadow,
        child: SizedBox(
          height: height - 2,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth / tabs.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: Motion.of(context, Motion.nav),
                      curve: Motion.springNav,
                      left: w * idx,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: tok.pc, borderRadius: BorderRadius.circular(Sizes.rNavInd)),
                      ),
                    ),
                    // Die Leiste ist fest hoch – die Beschriftung wächst nur begrenzt mit.
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.15,
                      child: Row(
                        children: [
                          for (final t in tabs)
                            Expanded(
                              child: Pressable(
                                onTap: () => ui.goTab(t.$1),
                                semanticLabel: t.$4,
                                selected: ui.tab == t.$1,
                                radius: BorderRadius.circular(Sizes.rNavInd),
                                excludeChildSemantics: true,
                                child: SizedBox.expand(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AppIcon(t.$3, size: 22, color: ui.tab == t.$1 ? tok.onPc : tok.sub),
                                      const SizedBox(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: Text(
                                          t.$2,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: Fs.nav,
                                            fontWeight: FontWeight.w500,
                                            color: ui.tab == t.$1 ? tok.onPc : tok.sub,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
