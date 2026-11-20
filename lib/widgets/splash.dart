import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';

/// Ein Tropfen des Splashs: Breite, Richtung (Grad, 0 = oben, im Uhrzeigersinn), Abstand
/// vom Kreis und Verzögerung (ms).
typedef SplashDrop = ({int w, int angle, int dist, int delay});

/// Ein kleiner Spritzer: Durchmesser, Richtung, Abstand und Verzögerung (ms).
typedef SplashDot = ({int s, int angle, int dist, int delay});

/// Eine der [count] festen Splash-Varianten beim Abhaken: 3 bis 6 Tropfen – immer einer groß,
/// die anderen klein bis mittel – und 0 bis 3 Spritzer. Dieselbe Nummer ergibt immer denselben
/// Splash (fester Zufall aus der Nummer, wie `variant(nr)` im Entwurf).
class SplashVariant {
  SplashVariant._(this.drops, this.dots);

  static const count = 50;

  final List<SplashDrop> drops;
  final List<SplashDot> dots;

  static final _cache = <int, SplashVariant>{};

  factory SplashVariant.of(int nr) => _cache.putIfAbsent(nr, () => _make(nr));

  static SplashVariant _make(int nr) {
    final rnd = _Mulberry32(nr * 7919 + 17);
    final n = 3 + (rnd.next() * 4).floor();
    final step = 360 / n, start = rnd.next() * 360;
    final drops = <SplashDrop>[];
    for (var i = 0; i < n; i++) {
      final w = i == 0 ? 11 + _round(rnd.next() * 4) : 4 + _round(rnd.next() * 8);
      final angle = _round(start + i * step + (rnd.next() - 0.5) * step * 0.6);
      final dist = 10 + _round(w * 0.35 + rnd.next() * 3);
      drops.add((w: w, angle: angle, dist: dist, delay: _round(rnd.next() * 50)));
    }
    final dots = <SplashDot>[];
    final m = (rnd.next() * 4).floor();
    for (var i = 0; i < m; i++) {
      final s = 2 + _round(rnd.next() * 4);
      final angle = _round(rnd.next() * 360);
      final dist = 15 + _round(rnd.next() * 5);
      dots.add((s: s, angle: angle, dist: dist, delay: 30 + _round(rnd.next() * 60)));
    }
    return SplashVariant._(drops, dots);
  }
}

/// `Math.round` aus JavaScript: .5 rundet immer nach oben (auch bei negativen Zahlen).
int _round(double x) => (x + 0.5).floor();

/// Der Zufallsgenerator aus dem Entwurf (mulberry32) mit 32-Bit-Ganzzahlen.
class _Mulberry32 {
  _Mulberry32(int seed) : _t = seed & _mask;
  static const _mask = 0xFFFFFFFF;
  int _t;

  static int _imul(int a, int b) => (a * b) & _mask;

  double next() {
    _t = (_t + 0x6D2B79F5) & _mask;
    var r = _imul(_t ^ (_t >> 15), 1 | _t);
    r = (r ^ ((r + _imul(r ^ (r >> 7), 61 | r)) & _mask)) & _mask;
    return ((r ^ (r >> 14)) & _mask) / 4294967296;
  }
}

/// Wert einer CSS-Transition, die bei [startMs] beginnt und [dur] dauert.
double _ease(double ms, double startMs, Duration dur, Curve curve) =>
    curve.transform(((ms - startMs) / dur.inMilliseconds).clamp(0.0, 1.0));

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Zeichnet den Splash von oben gesehen: Tropfen fliegen knapp über den Kreis hinaus, ziehen
/// sich ab [Motion.checkSettleAt] zusammen und verschwinden. Mitte der Zeichenfläche = Mitte
/// des Kreises; [ms] = Zeit seit dem Abhaken.
class SplashPainter extends CustomPainter {
  SplashPainter({required this.variant, required this.color, required this.ms});

  final SplashVariant variant;
  final Color color;
  final double ms;

  static final Path _drop = parseSvgPath('M5 0.5C7.6 0.5 10 3.8 10 8A5 5 0 0 1 0 8C0 3.8 2.4 0.5 5 0.5Z');

  /// Glanzlicht `M7.2 6.6q.9 1.2.5 2.6` (der Pfad-Parser kennt kein `q`).
  static final Path _shine = Path()
    ..moveTo(7.2, 6.6)
    ..quadraticBezierTo(8.1, 7.8, 7.7, 9.2);

  static double get _flyAt => Motion.checkGrowAt.inMilliseconds.toDouble();
  static double get _settleAt => Motion.checkSettleAt.inMilliseconds.toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    for (final d in variant.drops) {
      _paintDrop(canvas, d);
    }
    for (final p in variant.dots) {
      _paintDot(canvas, p);
    }
  }

  /// Weg eines Teils: Start (Phase 0) → hinaus (Phase 1) → zusammenziehen (Phase 2).
  ({double y, double sx, double sy, double op}) _path({
    required double y0,
    required double sx0,
    required double sy0,
    required double op0,
    required double y1,
    required double y2,
    required double s2,
    required int delay,
    required Duration fly,
    Duration? fadeIn,
  }) {
    double phase1(double at) => _ease(at, _flyAt + delay, fly, Motion.splashOut);
    double fade1(double at) => fadeIn == null ? 1 : _ease(at, _flyAt + delay, fadeIn, Curves.ease);
    if (ms < _settleAt) {
      final t = phase1(ms);
      return (y: _lerp(y0, y1, t), sx: _lerp(sx0, 1, t), sy: _lerp(sy0, 1, t), op: _lerp(op0, 1, fade1(ms)));
    }
    // Phase 2 setzt dort an, wo Phase 1 gerade war (wie eine unterbrochene CSS-Transition).
    final t1 = phase1(_settleAt), f1 = fade1(_settleAt);
    final y = _lerp(y0, y1, t1), sx = _lerp(sx0, 1, t1), sy = _lerp(sy0, 1, t1), op = _lerp(op0, 1, f1);
    final t = _ease(ms, _settleAt, Motion.splashFade, Curves.easeIn);
    return (y: _lerp(y, y2, t), sx: _lerp(sx, s2, t), sy: _lerp(sy, s2, t), op: _lerp(op, 0, t));
  }

  void _paintDrop(Canvas canvas, SplashDrop d) {
    final w = d.w.toDouble(), h = _round(w * 1.3).toDouble();
    final s = _path(
      y0: -2,
      sx0: 0.4,
      sy0: 0.3,
      op0: 1,
      y1: -d.dist.toDouble(),
      y2: -_round(d.dist * 1.08).toDouble(),
      s2: 0.2,
      delay: d.delay,
      fly: Motion.splashFly,
    );
    if (s.op <= 0) return;
    // SVG mit viewBox 10×13, unten mittig am Kreis verankert (transform-origin 50 % 100 %).
    final k = math.min(w / 10, h / 13);
    canvas
      ..save()
      ..rotate(d.angle * math.pi / 180)
      ..translate(0, s.y)
      ..scale(s.sx, s.sy)
      ..translate(-w / 2 + (w - 10 * k) / 2, -h + (h - 13 * k) / 2)
      ..scale(k);
    final a = s.op.clamp(0.0, 1.0);
    canvas.drawPath(_drop, Paint()..color = color.withValues(alpha: color.a * a));
    canvas.drawPath(
      _shine,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _paintDot(Canvas canvas, SplashDot p) {
    final s = _path(
      y0: 0,
      sx0: 0.3,
      sy0: 0.3,
      op0: 0,
      y1: -p.dist.toDouble(),
      y2: -_round(p.dist * 1.1).toDouble(),
      s2: 0,
      delay: p.delay,
      fly: Motion.splashDotFly,
      fadeIn: Motion.splashDotFade,
    );
    if (s.op <= 0 || s.sx <= 0) return;
    canvas
      ..save()
      ..rotate(p.angle * math.pi / 180);
    canvas.drawCircle(
      Offset(0, s.y),
      p.s / 2 * s.sx,
      Paint()..color = color.withValues(alpha: color.a * s.op.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashPainter old) => old.ms != ms || old.variant != variant || old.color != color;
}

/// Funken, wenn alle Gewohnheiten des Tages erledigt sind: [Sizes.sparkCount] bunte Punkte
/// fliegen aus der Mitte und vergehen.
class SparkPainter extends CustomPainter {
  SparkPainter({required this.colors, required this.ms});

  final List<Color> colors;
  final double ms;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    const n = Sizes.sparkCount;
    for (var i = 0; i < n; i++) {
      final start = Motion.checkGrowAt.inMilliseconds + (i % 3) * Motion.sparkStagger.inMilliseconds.toDouble();
      final move = _ease(ms, start, Motion.sparks, Motion.emphasized);
      final fade = _ease(ms, start, Motion.sparks, Curves.easeIn);
      if (fade >= 1) continue;
      canvas
        ..save()
        ..rotate(_round(i * (360 / n)) * math.pi / 180);
      final c = colors[i % colors.length];
      canvas.drawCircle(
        Offset(0, -Sizes.sparkDistance * move),
        Sizes.spark / 2 * _lerp(1, 0.3, move),
        Paint()..color = c.withValues(alpha: c.a * (1 - fade)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SparkPainter old) => old.ms != ms || old.colors != colors;
}

/// Spielt eine kurze Zeichnung ([painter], abhängig von der Zeit in ms) über allem anderen ab
/// – also auch über den Nachbarzeilen – und entfernt sie danach wieder.
///
/// Mittelpunkt ist die Mitte von [context]. Mit [link] folgt sie dem Ziel, solange es da ist
/// (z. B. wenn die abgehakte Gewohnheit nach unten rutscht); verschwindet es, bleibt sie an
/// der alten Stelle stehen.
void showBurst(
  BuildContext context, {
  required Duration duration,
  required CustomPainter Function(double ms) painter,
  LayerLink? link,
}) {
  final overlay = Overlay.maybeOf(context);
  final box = context.findRenderObject() as RenderBox?;
  final ob = overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null || box == null || ob == null || !box.hasSize) return;
  final at = ob.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BurstLayer(
      at: at,
      link: link,
      duration: duration,
      painter: painter,
      onDone: () {
        if (entry.mounted) entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

/// Der Splash in den Farben eines abgehakten Kreises – eine zufällige der 50 Varianten.
void showSplash(BuildContext context, {required Color color, LayerLink? link, int? variant}) {
  final v = SplashVariant.of(variant ?? math.Random().nextInt(SplashVariant.count));
  showBurst(
    context,
    link: link,
    duration: Motion.splashTotal,
    painter: (ms) => SplashPainter(variant: v, color: color, ms: ms),
  );
}

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({
    required this.at,
    required this.link,
    required this.duration,
    required this.painter,
    required this.onDone,
  });

  final Offset at;
  final LayerLink? link;
  final Duration duration;
  final CustomPainter Function(double ms) painter;
  final VoidCallback onDone;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer> with SingleTickerProviderStateMixin {
  // Nur nach dem Ablauf entfernen – wird die Overlay-Ebene vorher abgebaut, ist es schon weg.
  late final _c = AnimationController(vsync: this, duration: widget.duration)..forward().then((_) => widget.onDone());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget paint = AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          CustomPaint(size: Size.zero, painter: widget.painter(_c.value * widget.duration.inMilliseconds)),
    );
    final link = widget.link;
    if (link != null) {
      paint = CompositedTransformFollower(
        link: link,
        targetAnchor: Alignment.center,
        followerAnchor: Alignment.center,
        child: paint,
      );
    }
    return Positioned(
      left: widget.at.dx,
      top: widget.at.dy,
      child: IgnorePointer(child: ExcludeSemantics(child: paint)),
    );
  }
}
