import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/selected.dart';
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
    final store = app.store;
    return ListenableBuilder(
      // Der Upload-Stand (wartende Zeilen, Wolken) spielt im Wochenplan keine Rolle.
      listenable: Listenable.merge([Selected(store, () => store.revision), app.settings]),
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
                child: SwipePager(
                  page: one ? addDays(ui.weekStart, ui.weekDay!) : ui.weekStart,
                  group: one,
                  onMove: ui.weekStep,
                  peek: (dir) {
                    final f = Fmt.of(context);
                    return one
                        ? f.day(addDays(ui.weekStart, ui.weekDay! + dir))
                        : f.weekLabel(addDays(ui.weekStart, 7 * dir));
                  },
                  child: body,
                ),
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
            child: ClipRect(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: PageTitle(
                  page: one ? sel! : ws,
                  group: one,
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
                  final wd = wdIndex(d);
                  final label = Text(
                    one ? f.wdLong(wd) : f.wd(wd),
                    style: TextStyle(fontSize: one ? 13 : 11, color: one ? tok.text : tok.sub),
                  );
                  return Pressable(
                    onTap: () => ui.toggleWeekDay(i),
                    semanticLabel: one ? l.backToWeek : l.showDay(f.wdLong(wd)),
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
                  label: f.wdLong(wdAt(i)),
                  blockLabel: (b) => l.a11yBlock(b.name, f.wdLong(wdAt(i)), f.time(b.start), f.time(b.end)),
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

  /// Stelle des Tags in der gezeigten Woche (0–6).
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
    final startMin = s.dayStart * 60;
    final d = addDays(ui.weekStart, day);
    final blocks = app.store.blocksOn(d);
    final lay = layoutLanes(blocks);
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
            Sheets(context, ui).newBlock(day: wdIndex(d), start: m);
          },
          child: Semantics(
            label: label,
            child: CustomPaint(
              painter: _GridPainter(line: tok.line, soft: tok.lineSoft, rasterPx: Sizes.hour * s.raster / 60),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final b in blocks)
                    _BlockTile(
                      key: ValueKey(b.id),
                      block: b,
                      ui: ui,
                      one: one,
                      narrow: narrow,
                      height: height,
                      left: lay.lane[b.id]! * box.maxWidth / lay.lanes[b.id]!,
                      width: box.maxWidth / lay.lanes[b.id]!,
                      semanticLabel: blockLabel(b),
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

/// Ein Block im Raster. Antippen öffnet ihn; lange drücken und nach oben/unten ziehen legt ihn
/// auf eine andere Uhrzeit (in Schritten des Rasters aus den Einstellungen, Dauer bleibt gleich).
class _BlockTile extends StatefulWidget {
  const _BlockTile({
    super.key,
    required this.block,
    required this.ui,
    required this.one,
    required this.narrow,
    required this.height,
    required this.left,
    required this.width,
    required this.semanticLabel,
  });
  final WeekBlock block;
  final UiState ui;
  final bool one;
  final bool narrow;

  /// Höhe des ganzen Tages im Raster.
  final double height;
  final double left;
  final double width;
  final String semanticLabel;

  @override
  State<_BlockTile> createState() => _BlockTileState();
}

class _BlockTileState extends State<_BlockTile> {
  /// Beim Ziehen: der neue Beginn in Minuten; sonst `null`.
  int? _drag;

  void _start() {
    buzz();
    setState(() => _drag = widget.block.start);
  }

  void _move(LongPressMoveUpdateDetails e) {
    final s = context.app.settings;
    final t = dragTarget(widget.block, e.offsetFromOrigin.dy / Sizes.hour * 60, s.raster, s.dayStart, s.dayEnd);
    if (t == _drag) return;
    buzz();
    setState(() => _drag = t);
  }

  void _drop() {
    final t = _drag;
    setState(() => _drag = null);
    final app = context.app;
    final b = app.store.blockById(widget.block.id);
    if (t == null || b == null || t == b.start) return;
    final from = b.start, to = b.end;
    // Die Woche von jetzt merken – das Rückgängig soll auch nach dem Blättern dieselbe treffen.
    final week = widget.ui.weekStart;
    void put(int start, int end) => app.store.updateBlock(
      b,
      name: b.name,
      color: b.color,
      day: b.day,
      start: start,
      end: end,
      repeat: b.repeat,
      weekStart: week,
    );
    put(t, t + to - from);
    app.snack.show(context.l.blockMoved(Fmt.of(context).time(t)), undo: () => put(from, to));
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final f = Fmt.of(context);
    final startMin = context.app.settings.dayStart * 60;
    final b = widget.block;
    final one = widget.one, narrow = widget.narrow;
    final dragging = _drag != null;
    final bs = _drag ?? b.start, be = bs + b.end - b.start;
    final top = math.max(0.0, (bs - startMin) / 60 * Sizes.hour);
    final bottom = math.min(widget.height, (be - startMin) / 60 * Sizes.hour);
    if (bottom <= 0 || top >= widget.height) return const SizedBox.shrink();
    final h = math.max(14.0, bottom - top - 2);
    final bc = tok.item(b.color);
    final fs = one ? 13.0 : (narrow ? 9.5 : 10.0);
    final lh = one ? 16.0 : (narrow ? 11.0 : 12.0);
    // Die Zeilen mit der Uhrzeit wachsen mit der Systemschrift – also auch
    // die Höhe, ab der sie Platz haben.
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final timeStyle = TextStyle(
      fontSize: one ? 12 : fs,
      height: lh / fs,
      color: bc.ci.withValues(alpha: 0.85),
      fontFeatures: Fs.tabular,
    );
    final radius = BorderRadius.circular(one ? 8 : Sizes.rBlock);
    Widget tile = Container(
      clipBehavior: Clip.hardEdge,
      padding: one
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : (narrow ? const EdgeInsets.fromLTRB(2, 2, 1, 2) : const EdgeInsets.all(3)),
      decoration: BoxDecoration(
        color: bc.ct,
        borderRadius: radius,
        border: Border(
          left: BorderSide(color: bc.c, width: one ? 4 : 3),
        ),
        boxShadow: dragging ? tok.popShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              b.name,
              overflow: TextOverflow.clip,
              style: TextStyle(fontSize: fs, height: lh / fs, fontWeight: FontWeight.w500, color: bc.ci),
            ),
          ),
          if (one && h > 26 * ts) ...[
            const SizedBox(height: 2),
            Text(context.l.rangeDash(f.time(bs), f.time(be)), maxLines: 1, softWrap: false, style: timeStyle),
          ],
          if (!one && h > 40 * ts) Text(f.time(bs), maxLines: 1, softWrap: false, style: timeStyle),
          if (!one && h > 64 * ts) Text(f.time(be), maxLines: 1, softWrap: false, style: timeStyle),
        ],
      ),
    );
    if (dragging) {
      // Beim Ziehen steht die neue Uhrzeit über dem Block – auch wenn er zu klein dafür ist.
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: tile),
          Positioned(
            left: 0,
            bottom: h + 2,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: bc.c, borderRadius: BorderRadius.circular(Sizes.rBlock)),
                child: Text(
                  f.time(bs),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontSize: Fs.tiny, color: bc.ct, fontFeatures: Fs.tabular),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Positioned(
      top: top,
      height: h,
      left: widget.left + 2,
      width: widget.width - 4,
      // Langdruck gewinnt gegen Tippen und Scrollen erst, wenn man den Finger kurz still hält.
      child: GestureDetector(
        excludeFromSemantics: true,
        onLongPressStart: (_) => _start(),
        onLongPressMoveUpdate: _move,
        onLongPressEnd: (_) => _drop(),
        onLongPressCancel: () => setState(() => _drag = null),
        child: Pressable(
          onTap: () => Sheets(context, widget.ui).block(b),
          pressScale: 0.95,
          radius: radius,
          semanticLabel: widget.semanticLabel,
          excludeChildSemantics: true,
          child: AnimatedScale(scale: dragging ? 1.03 : 1, duration: Motion.fast, child: tile),
        ),
      ),
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
