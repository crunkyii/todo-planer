import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../theme/color_math.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../widgets/app_icon.dart';
import '../widgets/pressable.dart';
import '../widgets/ui.dart';
import 'sheets.dart';
import 'ui_state.dart';

const int heatWeeks = 18;

/// Stufe 0–4 der Heatmap aus der Anzahl erledigter Aufgaben eines Tages.
int heatLevel(int n) => n == 0 ? 0 : n <= 1 ? 1 : n <= 3 ? 2 : n <= 5 ? 3 : 4;

/// Obere Achsen-Grenze des Balkendiagramms: mindestens 4, gerade Zahl.
int chartMax(Iterable<int> totals) => math.max(4, (totals.fold<int>(0, math.max) / 2).ceil() * 2);

/// Tab „Statistik“: Kacheln, Heatmap, gestapelte Balken, Kategorien, Gewohnheiten.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.store, ui]),
      builder: (context, _) {
        final l = context.l;
        final store = app.store;
        final range = ui.statRange;
        final entries = store.doneEntries();
        final now = today();
        final days = [for (var i = range - 1; i >= 0; i--) isoDate(addDays(now, -i))];
        final byDay = <String, Map<String, int>>{for (final d in days) d: {}};
        for (final e in entries) {
          final by = byDay[e.day];
          if (by != null) by[e.cat] = (by[e.cat] ?? 0) + 1;
        }
        final perDay = [for (final d in days) byDay[d]!];
        final totals = [for (final by in perDay) by.values.fold<int>(0, (a, b) => a + b)];
        final total = totals.fold<int>(0, (a, b) => a + b);
        final daySet = {for (final e in entries) e.day};
        final st = streak((d) => daySet.contains(isoDate(d)));

        return Column(children: [
          TopBar(
            title: l.statistics,
            trailing: Seg<int>(
              mini: true,
              label: l.period,
              options: [(7, l.daysRange(7)), (30, l.daysRange(30))],
              value: range,
              onChanged: (v) => ui.set((s) => s.statRange = v),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: Sizes.contentBottom + MediaQuery.paddingOf(context).bottom),
              children: [
                _Tiles(total: total, streak: st, range: range),
                _Heatmap(ui: ui, entries: entries),
                _Chart(days: days, perDay: perDay, totals: totals, total: total, range: range),
                _ByCategory(entries: entries, days: days.toSet()),
                _Habits(ui: ui),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.total, required this.streak, required this.range});
  final int total;
  final int streak;
  final int range;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    Widget tile(Widget value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(color: tok.card, borderRadius: BorderRadius.circular(Sizes.rTile), boxShadow: tok.cardShadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 32, child: value),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: tok.sub)),
            ]),
          ),
        );
    final big = TextStyle(fontSize: Fs.tile, height: 32 / 26, fontWeight: FontWeight.w500, color: tok.text, fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(children: [
        tile(Text('$total', style: big), l.tileDone),
        const SizedBox(width: 8),
        tile(Row(children: [AppIcon(Ic.flame, size: 20, stroke: 2, color: tok.p), const SizedBox(width: 4), Text('$streak', style: big)]), l.tileStreak(streak)),
        const SizedBox(width: 8),
        tile(Text(f.oneDecimal(total / range), style: big), l.perDay),
      ]),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(header: true, child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.tok.text))),
      );
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.ui, required this.entries});
  final UiState ui;
  final List<({String day, String cat})> entries;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final count = <String, int>{};
    for (final e in entries) {
      count[e.day] = (count[e.day] ?? 0) + 1;
    }
    final now = today();
    final start = addDays(monday(now), -7 * (heatWeeks - 1));
    final levels = [
      tok.lineSoft,
      mix(tok.lineSoft, tok.p, 0.3),
      mix(tok.lineSoft, tok.p, 0.55),
      mix(tok.lineSoft, tok.p, 0.78),
      tok.p,
    ];
    var total = 0, active = 0;
    for (var i = 0; i < heatWeeks * 7; i++) {
      final d = addDays(start, i);
      if (d.isAfter(now)) break;
      final n = count[isoDate(d)] ?? 0;
      total += n;
      if (n > 0) active++;
    }
    final sel = ui.heatSel;
    final info = sel != null ? l.heatDay(f.longDate(parseIsoDate(sel)), count[sel] ?? 0) : l.heatSummary(total, active);
    final small = TextStyle(fontSize: Fs.micro, color: tok.sub);

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CardTitle(l.activity),
        LayoutBuilder(builder: (context, box) {
          const gap = 3.0, wdW = 20.0, colGap = 4.0;
          final cell = (box.maxWidth - wdW - colGap - gap * (heatWeeks - 1)) / heatWeeks;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: wdW,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(children: [
                    for (var d = 0; d < 7; d++)
                      SizedBox(
                        height: cell + (d < 6 ? gap : 0),
                        child: Align(alignment: Alignment.topLeft, child: Text(d.isEven ? f.wd(d) : '', style: small)),
                      ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: colGap),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ExcludeSemantics(
                  child: SizedBox(
                    height: 14,
                    child: Stack(clipBehavior: Clip.none, children: [
                      for (var w = 0; w < heatWeeks; w++)
                        if (w == 0 || addDays(start, 7 * w).month != addDays(start, 7 * (w - 1)).month)
                          Positioned(left: w * (cell + gap), child: Text(f.monShort(addDays(start, 7 * w)), softWrap: false, style: small)),
                    ]),
                  ),
                ),
                const SizedBox(height: 2),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var w = 0; w < heatWeeks; w++) ...[
                    if (w > 0) const SizedBox(width: gap),
                    Column(children: [
                      for (var d = 0; d < 7; d++) ...[
                        if (d > 0) const SizedBox(height: gap),
                        Builder(builder: (context) {
                          final day = addDays(start, 7 * w + d);
                          if (day.isAfter(now)) return SizedBox(width: cell, height: cell);
                          final k = isoDate(day);
                          final n = count[k] ?? 0;
                          return Pressable(
                            onTap: () => ui.set((s) => s.heatSel = s.heatSel == k ? null : k),
                            pressScale: 0.85,
                            glow: false,
                            selected: k == sel,
                            semanticLabel: l.a11yHeatDay(f.longDate(day), n),
                            radius: BorderRadius.circular(Sizes.rHeat),
                            child: Container(
                              width: cell,
                              height: cell,
                              decoration: BoxDecoration(
                                color: levels[heatLevel(n)],
                                borderRadius: BorderRadius.circular(Sizes.rHeat),
                                boxShadow: k == sel ? [BoxShadow(color: tok.text, spreadRadius: 2)] : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ]),
                  ],
                ]),
              ]),
            ),
          ]);
        }),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6, children: [
          Semantics(liveRegion: true, child: RichB(info, style: TextStyle(fontSize: 12, color: tok.sub), boldWeight: FontWeight.w500)),
          ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(l.less, style: TextStyle(fontSize: 11, color: tok.sub)),
              for (final c in levels) ...[
                const SizedBox(width: 3),
                Container(width: 11, height: 11, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(Sizes.rHeat))),
              ],
              const SizedBox(width: 3),
              Text(l.more, style: TextStyle(fontSize: 11, color: tok.sub)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.days, required this.perDay, required this.totals, required this.total, required this.range});
  final List<String> days;
  final List<Map<String, int>> perDay;
  final List<int> totals;
  final int total;
  final int range;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final store = context.app.store;
    final cats = store.categories;
    final max = chartMax(totals);
    final reduced = Motion.reduced(context);
    const h = 130.0;
    final axis = TextStyle(fontSize: Fs.tiny, color: tok.sub, fontFeatures: const [FontFeature.tabularFigures()]);
    final delay = range > 7 ? 12 : 40;
    final totalMs = Motion.bar.inMilliseconds + delay * (range - 1);

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CardTitle(l.completedTasks),
        Semantics(
          label: l.chartA11y(total, range),
          excludeSemantics: true,
          child: Column(children: [
            SizedBox(
              height: h,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 26,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (final v in [max, max ~/ 2, 0])
                      Positioned(right: 0, bottom: v / max * h - 7, child: Text('$v', style: axis)),
                  ]),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(children: [
                    for (final v in [max, max ~/ 2, 0])
                      Positioned(left: 0, right: 0, bottom: v / max * h - (v == max ? 1 : 0), child: Container(height: 1, color: v == 0 ? tok.line : tok.lineSoft)),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (var i = 0; i < days.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Tooltip(
                            message: l.barTooltip(f.day(parseIsoDate(days[i])), totals[i]),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: reduced ? 1 : 0, end: 1),
                              duration: Duration(milliseconds: reduced ? 0 : totalMs),
                              curve: Interval(delay * i / totalMs, 1, curve: Motion.grow),
                              builder: (context, v, c) => Transform(
                                alignment: Alignment.bottomCenter,
                                transform: Matrix4.diagonal3Values(1, v, 1),
                                child: c,
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                                child: SizedBox(
                                  height: totals[i] / max * h,
                                  child: Column(verticalDirection: VerticalDirection.up, children: [
                                    for (final c in cats.where((c) => (perDay[i][c.id] ?? 0) > 0)) ...[
                                      Expanded(flex: perDay[i][c.id]!, child: Container(constraints: const BoxConstraints(minHeight: 2), color: tok.item(c.color).c)),
                                      const SizedBox(height: 1),
                                    ],
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Row(children: [
              const SizedBox(width: 32),
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    range == 7
                        ? f.wd(wdIndex(parseIsoDate(days[i])))
                        : (i % 5 == 4 || i == range - 1 ? f.dayNum(parseIsoDate(days[i])) : ''),
                    textAlign: TextAlign.center,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: i == range - 1 ? axis.copyWith(color: tok.p, fontWeight: FontWeight.w700) : axis,
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (final c in cats)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Dot(tok.item(c.color).c, size: 9),
              const SizedBox(width: 5),
              Text(c.name, style: TextStyle(fontSize: 12, color: tok.sub)),
            ]),
        ]),
      ]),
    );
  }
}

class _ByCategory extends StatelessWidget {
  const _ByCategory({required this.entries, required this.days});
  final List<({String day, String cat})> entries;
  final Set<String> days;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final cats = context.app.store.categories;
    final by = [for (final c in cats) (c: c, n: entries.where((e) => e.cat == c.id && days.contains(e.day)).length)];
    final max = math.max(1, by.fold<int>(0, (m, x) => math.max(m, x.n)));
    final reduced = Motion.reduced(context);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CardTitle(l.byCategory),
        for (final x in by)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Semantics(
              label: '${x.c.name}: ${x.n}',
              excludeSemantics: true,
              child: Row(children: [
                Expanded(
                  flex: 7,
                  child: Row(children: [
                    Dot(tok.item(x.c.color).c),
                    const SizedBox(width: 8),
                    Expanded(child: Text(x.c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: tok.text))),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 10,
                  child: Container(
                    height: 8,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: tok.lineSoft, borderRadius: BorderRadius.circular(4)),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: reduced ? 1 : 0, end: 1),
                      duration: reduced ? Duration.zero : Motion.fill,
                      curve: Motion.growX,
                      builder: (context, v, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (x.n / max * v).clamp(0.0, 1.0),
                        child: Container(decoration: BoxDecoration(color: tok.item(x.c.color).c, borderRadius: BorderRadius.circular(4))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 28,
                  child: Text('${x.n}', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: tok.sub, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Habits extends StatelessWidget {
  const _Habits({required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final store = context.app.store;
    final hs = store.habits;
    final now = today();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CapsHeading(l.habits, padding: const EdgeInsets.fromLTRB(20, 22, 20, 8)),
      if (hs.isEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), child: Text(l.noHabits, style: TextStyle(fontSize: 14, color: tok.sub)))
      else
        for (final h in hs)
          Builder(builder: (context) {
            final hc = tok.item(h.color);
            final st = store.habitStreak(h.id);
            return AppCard(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Pressable(
                      onTap: () => Sheets(context, ui).habit(h),
                      pressScale: 0.97,
                      glow: false,
                      semanticLabel: '${l.editHabit}: ${h.name}',
                      excludeChildSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(h.name, style: TextStyle(fontSize: Fs.task, fontWeight: FontWeight.w500, color: tok.text)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIcon(Ic.flame, size: 15, stroke: 2, color: hc.c),
                  const SizedBox(width: 3),
                  Text(l.streakDays(st), style: TextStyle(fontSize: 12.5, color: tok.sub, fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  for (var d = 6; d >= 0; d--) ...[
                    if (d < 6) const SizedBox(width: 6),
                    Expanded(
                      child: Builder(builder: (context) {
                        final day = addDays(now, -d);
                        final k = isoDate(day);
                        final on = store.habitDone(h.id, k);
                        return Pressable(
                          onTap: () {
                            if (store.toggleHabitDay(h.id, k)) buzz();
                          },
                          toggled: on,
                          semanticLabel: l.a11yHabitDay(h.name, f.longDate(day)),
                          excludeChildSemantics: true,
                          radius: BorderRadius.circular(Sizes.rHabitDay),
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            height: 46,
                            decoration: BoxDecoration(
                              color: on ? hc.c : hc.ct,
                              borderRadius: BorderRadius.circular(Sizes.rHabitDay),
                              border: d == 0 ? Border.all(color: hc.c, width: 2) : null,
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(f.wd(wdIndex(day)), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: on ? hc.cs : hc.ci)),
                              const SizedBox(height: 1),
                              SizedBox(
                                height: 18,
                                child: on
                                    ? AppIcon(Ic.check, size: 16, stroke: 2.6, color: hc.cs)
                                    : Text('${day.day}',
                                        style: TextStyle(fontSize: 14, height: 18 / 14, fontWeight: FontWeight.w500, color: hc.ci, fontFeatures: const [FontFeature.tabularFigures()])),
                              ),
                            ]),
                          ),
                        );
                      }),
                    ),
                  ],
                ]),
              ]),
            );
          }),
    ]);
  }
}
