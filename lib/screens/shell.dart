import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/sync_service.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
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

  @override
  void initState() {
    super.initState();
    final app = context.app;
    _sub = app.sync.events.listen(_onSync);
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
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    ui.dispose();
    super.dispose();
  }

  void _fab() {
    final sheets = Sheets(context, ui);
    if (ui.tab == AppTab.settings && ui.cats) {
      sheets.category(null);
    } else if (ui.tab == AppTab.week) {
      sheets.newBlock();
    } else if (ui.tab == AppTab.stats || (ui.tab == AppTab.tasks && ui.filter == 'habits')) {
      sheets.habit(null);
    } else {
      sheets.task(null, preset: ui.tab == AppTab.calendar ? ui.calSel : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l;
    final mq = MediaQuery.of(context);
    final low = mq.size.height < 640;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: BlobBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxWidth),
            child: ListenableBuilder(
              listenable: ui,
              builder: (context, _) {
                final fabLabel = ui.tab == AppTab.settings
                    ? (ui.cats ? l.newCategory : null)
                    : ui.tab == AppTab.week
                        ? l.newBlock
                        : (ui.tab == AppTab.stats || (ui.tab == AppTab.tasks && ui.filter == 'habits'))
                            ? l.newHabit
                            : l.newTask;
                return Stack(children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(top: mq.padding.top),
                      child: _PageSwitcher(ui: ui, child: _tab()),
                    ),
                  ),
                  if (fabLabel != null)
                    Positioned(
                      right: Sizes.fabRight,
                      bottom: (low ? 78 : Sizes.fabBottom) + mq.padding.bottom,
                      child: _Fab(label: fabLabel, onTap: _fab, size: low ? 54 : Sizes.fab),
                    ),
                  Positioned(
                    left: Sizes.navGap,
                    right: Sizes.navGap,
                    bottom: (low ? 8 : Sizes.navGap) + mq.padding.bottom,
                    child: _GlassNav(ui: ui, height: low ? 58 : Sizes.navH),
                  ),
                  SnackHost(controller: app.snack, undoLabel: l.undo, bottom: low ? 76 : Sizes.fabBottom),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab() => switch (ui.tab) {
        AppTab.tasks => TasksTab(key: const ValueKey('tasks'), ui: ui),
        AppTab.calendar => CalendarTab(key: const ValueKey('calendar'), ui: ui),
        AppTab.week => WeekTab(key: const ValueKey('week'), ui: ui),
        AppTab.stats => StatsTab(key: const ValueKey('stats'), ui: ui),
        AppTab.settings => ui.cats ? CategoriesPage(key: const ValueKey('cats'), ui: ui) : SettingsTab(key: const ValueKey('settings'), ui: ui),
      };
}

/// Seitenwechsel gleitet in Richtung des Tabs (enter-r / enter-l).
class _PageSwitcher extends StatelessWidget {
  const _PageSwitcher({required this.ui, required this.child});
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

/// Schwebende Milchglas-Navigation mit gleitendem Indikator (Feder-Kurve).
class _GlassNav extends StatelessWidget {
  const _GlassNav({required this.ui, required this.height});
  final UiState ui;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final tabs = [
      (AppTab.tasks, l.navTasks, Ic.tasks, l.navTasks),
      (AppTab.calendar, l.navCalendar, Ic.calendar, l.navCalendar),
      (AppTab.week, l.navWeek, Ic.week, l.weeklyPlan),
      (AppTab.stats, l.navStats, Ic.stats, l.statistics),
      (AppTab.settings, l.navSettings, Ic.settings, l.settings),
    ];
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
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth / tabs.length;
              return Stack(children: [
                AnimatedPositioned(
                  duration: Motion.of(context, Motion.nav),
                  curve: Motion.springNav,
                  left: w * idx,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: DecoratedBox(decoration: BoxDecoration(color: tok.pc, borderRadius: BorderRadius.circular(Sizes.rNavInd))),
                ),
                Row(children: [
                  for (final t in tabs)
                    Expanded(
                      child: Pressable(
                        onTap: () => ui.goTab(t.$1),
                        semanticLabel: t.$4,
                        selected: ui.tab == t.$1,
                        radius: BorderRadius.circular(Sizes.rNavInd),
                        excludeChildSemantics: true,
                        child: SizedBox.expand(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            AppIcon(t.$3, size: 22, color: ui.tab == t.$1 ? tok.onPc : tok.sub),
                            const SizedBox(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(t.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: Fs.nav, fontWeight: FontWeight.w500, color: ui.tab == t.$1 ? tok.onPc : tok.sub)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}
