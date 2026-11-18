import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/week_layout.dart';
import '../widgets/app_icon.dart';
import '../widgets/pressable.dart';
import '../widgets/swipe.dart';
import '../widgets/layout.dart';
import '../widgets/ui.dart';
import 'sheets.dart';
import 'ui_state.dart';

/// Tab „Woche“: Wochenplan mit Zeitraster, Tagesansicht per Tipp auf den Tag.
class WeekTab extends StatefulWidget {
  const WeekTab({super.key, required this.ui});
  final UiState ui;

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends State<WeekTab> {
  late final ScrollController _scroll;
  final _gridKey = GlobalKey();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    final s = context.app.settings;
    // Beim Öffnen auf 7:00 scrollen.
    _scroll = ScrollController(initialScrollOffset: math.max(0, (7 - s.dayStart) * Sizes.hour));
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ui = widget.ui;
    return ListenableBuilder(
      listenable: Listenable.merge([app.store, app.settings]),
      builder: (context, _) {
        final one = ui.weekDay != null;
        // GlobalKey: Beim Wechsel Woche ↔ Tag wird das Raster nur umgehängt, nicht neu
        // gebaut – so bleibt die Scroll-Position erhalten.
        final grid = Column(
          key: _gridKey,
          children: [
            _DayHeads(ui: ui),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.only(bottom: ShellLayout.bottomOf(context, narrow: Sizes.weekBottom)),
                child: _Grid(ui: ui),
              ),
            ),
          ],
        );
        Widget body = grid;
        if (ui.zoomIn != null && !Motion.reduced(context)) {
          body = TweenAnimationBuilder<double>(
            key: ValueKey('${ui.weekDay}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Motion.zoom,
            builder: (context, v, c) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(scale: (ui.zoomIn! ? 0.92 : 1.06) + (ui.zoomIn! ? 0.08 : -0.06) * v, child: c),
            ),
            child: grid,
          );
        }
        return Column(
          children: [
            _WeekHead(ui: ui, one: one),
            // Wischen links/rechts: nächste/vorige Woche (in der Tagesansicht: Tag)
            Expanded(
              child: ClipRect(
                child: SwipeStep(onMove: ui.weekStep, child: body),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekHead extends StatelessWidget {
  const _WeekHead({required this.ui, required this.one});
  final UiState ui;
  final bool one;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final ws = ui.weekStart;
    final sel = one ? addDays(ws, ui.weekDay!) : null;
    final narrow = MediaQuery.sizeOf(context).width <= Sizes.narrowWidth;
    return Padding(
      padding: EdgeInsets.fromLTRB(one ? 4 : (narrow ? 16 : 20), 10, 8, 6),
      child: Row(
        children: [
          if (one)
            IconBtn(
              Ic.back,
              label: l.backToWeek,
              onTap: () => ui.set((s) {
                s.weekDay = null;
                s.zoomIn = false;
              }),
            ),
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    one ? f.day(sel!) : f.weekLabel(ws),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: tok.text),
                  ),
                  Text(
                    one ? l.dayAndWeek(f.dayMonth(sel!), f.weekLabel(ws)) : f.weekRange(ws),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: tok.sub),
                  ),
                ],
              ),
            ),
          ),
          IconBtn(Ic.left, label: one ? l.prevDay : l.prevWeek, onTap: () => ui.weekStep(-1)),
          AppButton(label: l.today, kind: BtnKind.text, padding: narrow ? 8 : 16, onTap: () => ui.weekStep(0)),
          IconBtn(Ic.right, label: one ? l.nextDay : l.nextWeek, onTap: () => ui.weekStep(1)),
        ],
      ),
    );
  }
}

const double _timesW = 38;

class _DayHeads extends StatelessWidget {
  const _DayHeads({required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final one = ui.weekDay != null;
    final idx = one ? [ui.weekDay!] : [for (var i = 0; i < 7; i++) i];
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 2, 4, 6),
      decoration: BoxDecoration(
        color: tok.bg,
        border: Border(bottom: BorderSide(color: tok.line)),
      ),
      child: Row(
        children: [
          const SizedBox(width: _timesW),
          for (final i in idx)
            Expanded(
              child: Builder(
                builder: (context) {
                  final d = addDays(ui.weekStart, i);
                  final isToday = sameDay(d, clock());
                  final num = Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? tok.p : Colors.transparent),
                    child: Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isToday ? tok.onP : tok.text,
                        fontFeatures: Fs.tabular,
                      ),
                    ),
                  );
                  final label = Text(
                    one ? f.wdLong(i) : f.wd(i),
                    style: TextStyle(fontSize: one ? 13 : 11, color: one ? tok.text : tok.sub),
                  );
                  return Pressable(
                    onTap: () => ui.toggleWeekDay(i),
                    semanticLabel: one ? l.backToWeek : l.showDay(f.wdLong(i)),
                    toggled: one,
                    excludeChildSemantics: true,
                    child: one
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [label, const SizedBox(width: 8), num],
                          )
                        : Column(children: [label, const SizedBox(height: 2), num]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final tok = context.tok;
    final f = Fmt.of(context);
    final l = context.l;
    final one = ui.weekDay != null;
    final start = s.dayStart, end = s.dayEnd;
    final height = (end - start) * Sizes.hour;
    final idx = one ? [ui.weekDay!] : [for (var i = 0; i < 7; i++) i];
    final narrow = MediaQuery.sizeOf(context).width <= Sizes.narrowWidth;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _timesW,
              child: ExcludeSemantics(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var h = start + 1; h < end; h++)
                      Positioned(
                        top: (h - start) * Sizes.hour - 7,
                        right: 6,
                        child: Text(
                          hmString(h * 60),
                          style: TextStyle(fontSize: Fs.tiny, height: 1.3, color: tok.sub, fontFeatures: Fs.tabular),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final i in idx)
              Expanded(
                child: _DayColumn(
                  day: i,
                  one: one,
                  narrow: narrow,
                  height: height,
                  ui: ui,
                  label: f.wdLong(i),
                  blockLabel: (b) => l.a11yBlock(b.name, f.wdLong(i), f.time(b.start), f.time(b.end)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.one,
    required this.narrow,
    required this.height,
    required this.ui,
    required this.label,
    required this.blockLabel,
  });
  final int day;
  final bool one;
  final bool narrow;
  final double height;
  final UiState ui;
  final String label;
  final String Function(WeekBlock) blockLabel;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final tok = context.tok;
    final f = Fmt.of(context);
    final startMin = s.dayStart * 60;
    final blocks = app.store.blocksFor(day, ui.weekStart);
    final lay = layoutLanes(blocks);
    final d = addDays(ui.weekStart, day);
    final now = clock();
    final nm = now.hour * 60 + now.minute;
    final showNow = sameDay(d, now) && nm >= startMin && nm <= s.dayEnd * 60;

    return LayoutBuilder(
      builder: (context, box) {
        // Nur für Finger/Maus: Für Screenreader und Tastatur gibt es den +-Knopf „Neuer Block“.
        return GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) {
            final m = ((startMin + e.localPosition.dy / Sizes.hour * 60) / s.raster).floor() * s.raster;
            Sheets(context, ui).newBlock(day: day, start: m);
          },
          child: Semantics(
            label: label,
            child: CustomPaint(
              painter: _GridPainter(line: tok.line, soft: tok.lineSoft, rasterPx: Sizes.hour * s.raster / 60),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final b in blocks)
                    Builder(
                      builder: (context) {
                        final top = math.max(0.0, (b.start - startMin) / 60 * Sizes.hour);
                        final bottom = math.min(height, (b.end - startMin) / 60 * Sizes.hour);
                        if (bottom <= 0 || top >= height) return const SizedBox.shrink();
                        final h = math.max(14.0, bottom - top - 2);
                        final bc = tok.item(b.color);
                        final fs = one ? 13.0 : (narrow ? 9.5 : 10.0);
                        final lh = one ? 16.0 : (narrow ? 11.0 : 12.0);
                        // Die Zeilen mit der Uhrzeit wachsen mit der Systemschrift – also auch
                        // die Höhe, ab der sie Platz haben.
                        final ts = MediaQuery.textScalerOf(context).scale(1);
                        final w = box.maxWidth / lay.lanes[b.id]!;
                        final timeStyle = TextStyle(
                          fontSize: one ? 12 : fs,
                          height: lh / fs,
                          color: bc.ci.withValues(alpha: 0.85),
                          fontFeatures: Fs.tabular,
                        );
                        return Positioned(
                          top: top,
                          height: h,
                          left: lay.lane[b.id]! * w + 2,
                          width: w - 4,
                          child: Pressable(
                            onTap: () => Sheets(context, ui).block(b),
                            pressScale: 0.95,
                            radius: BorderRadius.circular(one ? 8 : Sizes.rBlock),
                            semanticLabel: blockLabel(b),
                            excludeChildSemantics: true,
                            child: Container(
                              clipBehavior: Clip.hardEdge,
                              padding: one
                                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
                                  : (narrow ? const EdgeInsets.fromLTRB(2, 2, 1, 2) : const EdgeInsets.all(3)),
                              decoration: BoxDecoration(
                                color: bc.ct,
                                borderRadius: BorderRadius.circular(one ? 8 : Sizes.rBlock),
                                border: Border(
                                  left: BorderSide(color: bc.c, width: one ? 4 : 3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      b.name,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontSize: fs,
                                        height: lh / fs,
                                        fontWeight: FontWeight.w500,
                                        color: bc.ci,
                                      ),
                                    ),
                                  ),
                                  if (one && h > 26 * ts) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      context.l.rangeDash(f.time(b.start), f.time(b.end)),
                                      maxLines: 1,
                                      softWrap: false,
                                      style: timeStyle,
                                    ),
                                  ],
                                  if (!one && h > 40 * ts)
                                    Text(f.time(b.start), maxLines: 1, softWrap: false, style: timeStyle),
                                  if (!one && h > 64 * ts)
                                    Text(f.time(b.end), maxLines: 1, softWrap: false, style: timeStyle),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (showNow)
                    Positioned(
                      top: (nm - startMin) / 60 * Sizes.hour - 1,
                      left: -3,
                      right: 0,
                      child: IgnorePointer(
                        child: SizedBox(
                          height: 2,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(child: ColoredBox(color: tok.err)),
                              Positioned(left: -3, top: -3, child: Dot(tok.err, size: 8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stundenlinien (line) und Rasterlinien (line-soft) sowie der linke Trennstrich.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.line, required this.soft, required this.rasterPx});
  final Color line;
  final Color soft;
  final double rasterPx;

  @override
  void paint(Canvas canvas, Size size) {
    final ps = Paint()..color = soft;
    final pl = Paint()..color = line;
    for (var y = 0.0; y < size.height; y += rasterPx) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), ps);
    }
    for (var y = 0.0; y < size.height; y += Sizes.hour) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), pl);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, 1, size.height), ps);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.line != line || old.soft != soft || old.rasterPx != rasterPx;
}
