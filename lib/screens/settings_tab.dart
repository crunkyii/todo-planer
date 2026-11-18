import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/settings_store.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/color_math.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../widgets/app_icon.dart';
import '../widgets/overlays.dart';
import '../widgets/pressable.dart';
import '../widgets/ui.dart';
import 'setup_screen.dart';
import 'sheets.dart';
import 'ui_state.dart';

String themeName(AppLocalizations l, String id) => switch (id) {
  'ozean' => l.themeOzean,
  'mint' => l.themeMint,
  'wald' => l.themeWald,
  'sonne' => l.themeSonne,
  'abendrot' => l.themeAbendrot,
  'beere' => l.themeBeere,
  'lavendel' => l.themeLavendel,
  'nord' => l.themeNord,
  'graphit' => l.themeGraphit,
  _ => l.themeHimmel,
};

/// Tab „Optionen“: Theme, Darstellung, Sprache, Aufgaben, Wochenplan, Speicherort.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.settings, app.store, app.sync]),
      builder: (context, _) {
        final s = app.settings;
        final l = context.l;
        final cloud = s.syncMode == SyncMode.cloud;
        return Column(
          children: [
            TopBar(title: l.settings),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: Sizes.contentBottom + MediaQuery.paddingOf(context).bottom),
                children: [
                  CapsHeading(l.theme),
                  _Themes(settings: s),
                  SetRow(
                    title: l.appearance,
                    trailing: Seg<AppMode>(
                      label: l.appearance,
                      options: [(AppMode.light, l.light), (AppMode.dark, l.dark), (AppMode.system, l.system)],
                      value: s.mode,
                      onChanged: (v) => s.update((x) => x.mode = v),
                    ),
                  ),
                  SetRow(
                    title: l.language,
                    trailing: LangSeg(settings: s),
                  ),
                  CapsHeading(l.navTasks),
                  SetRow(
                    title: l.categories,
                    subtitle: l.categoriesCount(app.store.categories.length),
                    chevron: true,
                    onTap: () => ui.set((x) {
                      x.enterDir = 1;
                      x.cats = true;
                    }),
                  ),
                  SetRow(
                    title: l.reminders,
                    inline: true,
                    trailing: AppSwitch(
                      value: s.remind,
                      label: l.reminders,
                      onChanged: (v) => s.update((x) => x.remind = v),
                    ),
                  ),
                  CapsHeading(l.weeklyPlan),
                  SetRow(
                    title: l.grid,
                    trailing: Seg<int>(
                      label: l.grid,
                      options: [for (final r in SettingsStore.rasterChoices) (r, '$r')],
                      value: s.raster,
                      onChanged: (v) => s.update((x) => x.raster = v),
                    ),
                  ),
                  SetRow(
                    title: l.dayStarts,
                    trailing: _HourPicker(
                      label: l.dayStarts,
                      value: s.dayStart,
                      from: SettingsStore.dayStartMin,
                      to: SettingsStore.dayStartMax,
                      onChanged: (v) => s.update((x) => x.dayStart = v),
                    ),
                  ),
                  SetRow(
                    title: l.dayEnds,
                    trailing: _HourPicker(
                      label: l.dayEnds,
                      value: s.dayEnd,
                      from: SettingsStore.dayEndMin,
                      to: SettingsStore.dayEndMax,
                      onChanged: (v) => s.update((x) => x.dayEnd = v),
                    ),
                  ),
                  CapsHeading(l.storage),
                  if (cloud) ..._cloudRows(context, app) else ..._localRows(context, app),
                  SetRow(
                    title: l.exportData,
                    subtitle: l.exportSub,
                    chevron: true,
                    onTap: () => Sheets(context, ui).export(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _cloudRows(BuildContext context, AppServices app) {
    final l = context.l;
    final tok = context.tok;
    final online = app.sync.online;
    final pending = app.store.pending;
    final (icon, text) = !online
        ? (Ic.cloudoff, pending > 0 ? l.offlinePending(pending) : l.offline)
        : (pending > 0 || app.sync.syncing)
        ? (Ic.sync, l.syncing)
        : (Ic.cloudok, l.synced);
    return [
      SetRow(
        title: l.database,
        subtitle: app.settings.cloud?.host,
        trailing: Semantics(
          liveRegion: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 18, color: tok.sub),
              const SizedBox(width: 6),
              Text(text, style: TextStyle(fontSize: 13, color: tok.sub)),
            ],
          ),
        ),
      ),
      SetRow(title: l.connectOtherDb, chevron: true, onTap: app.openSetup),
      SetRow(
        title: app.user?.email ?? '',
        trailing: AppButton(label: l.signOut, icon: Ic.logout, kind: BtnKind.tonal, onTap: app.signOut),
      ),
    ];
  }

  List<Widget> _localRows(BuildContext context, AppServices app) {
    final l = context.l;
    final tok = context.tok;
    return [
      SetRow(
        title: l.setupLocalTitle,
        subtitle: l.noSyncOtherDevices,
        inline: true,
        trailing: AppIcon(Ic.phone, size: 22, color: tok.sub),
      ),
      SetRow(title: l.connectToDb, subtitle: l.connectToDbSub, chevron: true, onTap: app.openSetup),
    ];
  }
}

/// Theme-Vorschau-Kärtchen in einer waagrecht scrollbaren Reihe (.themes/.theme-card).
class _Themes extends StatelessWidget {
  const _Themes({required this.settings});
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final dk = tok.dark;
    final current = themeOf(settings.theme).id;
    return Semantics(
      container: true,
      label: l.theme,
      child: SizedBox(
        // Die Zeile für den Namen wächst mit der Schriftgröße des Systems mit.
        height: 70 * 4 / 3 + 6 + MediaQuery.textScalerOf(context).scale(20) + 18,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          itemCount: appThemes.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final t = appThemes[i];
            final on = t.id == current;
            final bg = dk ? mix(darkBase, t.primary, 0.08) : mix(t.primary, white, 0.95);
            final card = dk ? mix(darkBase, t.primary, 0.16) : white;
            final name = themeName(l, t.id);
            return Pressable(
              onTap: () => settings.update((s) => s.theme = t.id),
              selected: on,
              semanticLabel: name,
              excludeChildSemantics: true,
              radius: BorderRadius.circular(16),
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: Motion.fast,
                      width: 70,
                      height: 70 * 4 / 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: on
                            ? [
                                BoxShadow(color: t.primary, spreadRadius: 4.5),
                                BoxShadow(color: tok.bg, spreadRadius: 2.5),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _ThemePreview(primary: t.primary, bg: bg, card: card, edge: tok.lineSoft),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: on ? tok.text : tok.sub),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.primary, required this.bg, required this.card, required this.edge});
  final Color primary, bg, card, edge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        Widget row(double top) => Positioned(
          left: w * 0.12,
          right: w * 0.12,
          top: h * top,
          height: h * 0.15,
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: primary, width: 3)),
              boxShadow: context.tok.previewShadow,
            ),
          ),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: edge),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1, -1),
                radius: 1.1,
                colors: [alpha(primary, 0.35), alpha(primary, 0)],
                stops: const [0, 0.7],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: w * 0.12,
                  top: h * 0.12,
                  width: w * 0.42,
                  height: h * 0.09,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                row(0.30),
                row(0.50),
                Positioned(
                  right: w * 0.12,
                  bottom: h * 0.10,
                  width: w * 0.26,
                  height: w * 0.26,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      boxShadow: context.tok.previewFabShadow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Stunden-Auswahl „06:00“ (statt <select>): öffnet ein kleines Menü.
class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.from,
    required this.to,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int from;
  final int to;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Builder(
      builder: (btnContext) {
        return Pressable(
          semanticLabel: '$label: ${hmString(value * 60)}',
          excludeChildSemantics: true,
          onTap: () {
            final rect = anchorRect(btnContext);
            if (rect == null) return;
            Navigator.of(context).push(
              AppMenuRoute(
                anchor: rect,
                label: label,
                scrollBehind: Scrollable.maybeOf(btnContext)?.position,
                builder: (menuContext) => [
                  for (var h = from; h <= to; h++)
                    MenuItemRow(
                      entry: MenuEntry(
                        label: hmString(h * 60),
                        radio: true,
                        checked: h == value,
                        onTap: () {
                          Navigator.pop(menuContext);
                          onChanged(h);
                        },
                      ),
                    ),
                ],
              ),
            );
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            decoration: BoxDecoration(
              color: tok.bg,
              border: Border.all(color: tok.line),
              borderRadius: BorderRadius.circular(Sizes.rInput),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hmString(value * 60),
                  style: TextStyle(fontSize: 14, color: tok.text, fontFeatures: Fs.tabular),
                ),
                const SizedBox(width: 4),
                AppIcon(Ic.down, size: 18, color: tok.sub),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Unterseite „Kategorien“ in den Optionen.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.store,
      builder: (context, _) {
        final l = context.l;
        final tok = context.tok;
        final f = Fmt.of(context);
        final store = app.store;
        return Column(
          children: [
            TopBar(
              title: l.categories,
              backLabel: l.back,
              onBack: () => ui.set((s) {
                s.enterDir = -1;
                s.cats = false;
              }),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: Sizes.contentBottom + MediaQuery.paddingOf(context).bottom),
                children: [
                  for (final c in store.categories)
                    SetRow(
                      title: c.name,
                      subtitle: f.categoryInfo(c.offset, store.openCount(c.id), c.listFrom),
                      leading: Dot(tok.item(c.color).c, size: 14),
                      chevron: true,
                      onTap: () => Sheets(context, ui).category(c),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
