import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

/// Die Strich-Icons des Prototyps (24×24-Raster, runde Enden), als eigene Zeichnung.
enum Ic {
  tasks,
  calendar,
  week,
  settings,
  plus,
  back,
  down,
  left,
  right,
  more,
  logout,
  check,
  clock,
  trash,
  eye,
  eyeoff,
  alert,
  send,
  subtasks,
  notes,
  edit,
  search,
  sort,
  tag,
  hide,
  sweep,
  cloudoff,
  cloudok,
  sync,
  database,
  phone,
  copy,
  ext,
  stats,
  flame,
  x,
}

sealed class _Shape {
  const _Shape();
}

class _P extends _Shape {
  const _P(this.d);
  final String d;
}

class _C extends _Shape {
  const _C(this.cx, this.cy, this.r, {this.fill = false});
  final double cx, cy, r;
  final bool fill;
}

class _R extends _Shape {
  const _R(this.x, this.y, this.w, this.h, this.rx);
  final double x, y, w, h, rx;
}

class _E extends _Shape {
  const _E(this.cx, this.cy, this.rx, this.ry);
  final double cx, cy, rx, ry;
}

const Map<Ic, List<_Shape>> _shapes = {
  Ic.tasks: [
    _P('M3 6.5l2 2 3.5-3.5'),
    _P('M3 13.5l2 2 3.5-3.5'),
    _P('M12 7h9'),
    _P('M12 14h9'),
    _P('M12 20h9'),
    _P('M4 20h4'),
  ],
  Ic.calendar: [_R(3.5, 5, 17, 15, 2), _P('M3.5 10h17'), _P('M8 3v4'), _P('M16 3v4')],
  Ic.week: [_R(3.5, 4, 17, 16, 2), _P('M3.5 9h17'), _P('M9 9v11'), _P('M15 9v11')],
  Ic.settings: [_P('M4 7h10'), _P('M18 7h2'), _C(16, 7, 2), _P('M4 17h4'), _P('M12 17h8'), _C(10, 17, 2)],
  Ic.plus: [_P('M12 5v14'), _P('M5 12h14')],
  Ic.back: [_P('M19 12H5'), _P('M11 6l-6 6 6 6')],
  Ic.down: [_P('M6 9l6 6 6-6')],
  Ic.left: [_P('M15 6l-6 6 6 6')],
  Ic.right: [_P('M9 6l6 6-6 6')],
  Ic.more: [_C(12, 5, 1.3, fill: true), _C(12, 12, 1.3, fill: true), _C(12, 19, 1.3, fill: true)],
  Ic.logout: [_P('M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4'), _P('M16 17l5-5-5-5'), _P('M21 12H9')],
  Ic.check: [_P('M5 12.5l4.5 4.5L19 7.5')],
  Ic.clock: [_C(12, 12, 8.5), _P('M12 7.5V12l3 2')],
  Ic.trash: [_P('M4 7h16'), _P('M10 11v6'), _P('M14 11v6'), _P('M6 7l1 13h10l1-13'), _P('M9 7V4h6v3')],
  Ic.eye: [_P('M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z'), _C(12, 12, 3)],
  Ic.eyeoff: [
    _P('M3 3l18 18'),
    _P('M10.6 5.1A10 10 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.2 4.1'),
    _P('M6.6 6.6A17 17 0 0 0 2 12s3.5 7 10 7a9.6 9.6 0 0 0 5.4-1.6'),
    _P('M9.9 9.9a3 3 0 0 0 4.2 4.2'),
  ],
  Ic.alert: [_C(12, 12, 9), _P('M12 7.5v5.5'), _P('M12 16.5v.01')],
  Ic.send: [_P('M5 12h13'), _P('M12 5l7 7-7 7')],
  Ic.subtasks: [_P('M5 4v12a2 2 0 0 0 2 2h4'), _P('M5 9h6'), _R(13, 6, 7, 6, 1.5), _R(13, 15, 7, 6, 1.5)],
  Ic.notes: [_R(4.5, 3.5, 15, 17, 2), _P('M8 8.5h8'), _P('M8 12.5h8'), _P('M8 16.5h5')],
  Ic.edit: [_P('M4 20h4L18.5 9.5a2.1 2.1 0 0 0-3-3L5 17v3'), _P('M13.5 8.5l3 3')],
  Ic.search: [_C(11, 11, 6.5), _P('M16 16l4.5 4.5')],
  Ic.sort: [_P('M7 4v16'), _P('M3.5 16.5L7 20l3.5-3.5'), _P('M13 6h8'), _P('M13 11h6'), _P('M13 16h4')],
  Ic.tag: [_P('M3 12V4h8l10 10-8 8z'), _C(7.5, 8.5, 1.3)],
  Ic.hide: [_P('M3 3l18 18'), _P('M9 5h11'), _P('M4 12h10'), _P('M4 19h7')],
  Ic.sweep: [_P('M4 7h16'), _P('M6 7l1 13h10l1-13'), _P('M9.5 12l2 2 3.5-3.5')],
  Ic.cloudoff: [_P('M3 3l18 18'), _P('M8.5 6.4A6 6 0 0 1 17.7 10 4 4 0 0 1 20 17.3'), _P('M17 18H7a5 5 0 0 1-1.3-9.8')],
  Ic.cloudok: [_P('M7 18.5a5 5 0 0 1-.6-10A6 6 0 0 1 17.7 10.5 4 4 0 0 1 17 18.5z'), _P('M9.5 13.5l2 2 3.5-3.5')],
  Ic.sync: [
    _P('M20 11a8 8 0 0 0-14.3-4.3L4 9'),
    _P('M4 4v5h5'),
    _P('M4 13a8 8 0 0 0 14.3 4.3L20 15'),
    _P('M20 20v-5h-5'),
  ],
  Ic.database: [
    _E(12, 6, 7.5, 3),
    _P('M4.5 6v12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3V6'),
    _P('M4.5 12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3'),
  ],
  Ic.phone: [_R(7, 3, 10, 18, 2.5), _P('M11 18h2')],
  Ic.copy: [_R(8, 8, 12, 12, 2), _P('M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3')],
  Ic.ext: [_P('M14 4h6v6'), _P('M20 4l-9 9'), _P('M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5')],
  Ic.stats: [_P('M5 20v-6'), _P('M12 20V5'), _P('M19 20v-10')],
  Ic.flame: [
    _P('M12 3c.8 3.6 5 5.6 5 10.2a5 5 0 0 1-10 0c0-2.4 1.3-3.9 2.4-5 .3 1.6 1.1 2.6 2.4 3C11.3 8.4 11 5.6 12 3z'),
  ],
  Ic.x: [_P('M6 6l12 12'), _P('M18 6L6 18')],
};

/// Zeichnet ein Prototyp-Icon in [size] mit Strichstärke [stroke] (bezogen auf 24 px).
/// [drawn] < 1 zeichnet die Linien nur bis zu diesem Anteil (Haken, der sich zeichnet).
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 24, this.stroke = 1.9, this.color, this.drawn = 1});

  final Ic icon;
  final double size;
  final double stroke;
  final Color? color;
  final double drawn;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color!;
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _IconPainter(icon, stroke, c, drawn)),
    );
  }
}

final Map<String, Path> _pathCache = {};

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.stroke, this.color, this.drawn);
  final Ic icon;
  final double stroke;
  final Color color;
  final double drawn;

  // Ein Pinsel für alle Icons: Farbe und Stärke werden je Bild gesetzt, gezeichnet wird sofort.
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _fill = Paint();

  /// Vermessene Pfade für [drawn] < 1 – der Haken zeichnet sich über viele Bilder.
  static final _metrics = Expando<List<PathMetric>>();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final line = _line
      ..color = color
      ..strokeWidth = stroke;
    for (final s in _shapes[icon]!) {
      switch (s) {
        case _P(:final d):
          final path = _pathCache.putIfAbsent(d, () => parseSvgPath(d));
          canvas.drawPath(drawn >= 1 ? path : _partOf(path, drawn), line);
        case _C(:final cx, :final cy, :final r, :final fill):
          canvas.drawCircle(Offset(cx, cy), r, fill ? (_fill..color = color) : line);
        case _R(:final x, :final y, :final w, :final h, :final rx):
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx)), line);
        case _E(:final cx, :final cy, :final rx, :final ry):
          canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), line);
      }
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.stroke != stroke || old.color != color || old.drawn != drawn;

  /// Der Anfang von [path] bis zum Anteil [t] seiner Länge.
  static Path _partOf(Path path, double t) {
    final out = Path();
    for (final m in _metrics[path] ??= path.computeMetrics().toList()) {
      out.addPath(m.extractPath(0, m.length * t.clamp(0.0, 1.0)), Offset.zero);
    }
    return out;
  }
}

/// Kleiner SVG-Pfad-Parser für die Befehle M L H V C S A Z (groß = absolut, klein = relativ).
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  var cur = Offset.zero, start = Offset.zero, lastCtrl = Offset.zero;
  var lastWasCubic = false;
  double n() => double.parse(tokens[i++]);
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final base = rel ? cur : Offset.zero;
    switch (cmd.toUpperCase()) {
      case 'M':
        cur = base + Offset(n(), n());
        start = cur;
        path.moveTo(cur.dx, cur.dy);
        cmd = rel ? 'l' : 'L'; // weitere Zahlenpaare sind Linien
        lastWasCubic = false;
      case 'L':
        cur = base + Offset(n(), n());
        path.lineTo(cur.dx, cur.dy);
        lastWasCubic = false;
      case 'H':
        cur = Offset((rel ? cur.dx : 0) + n(), cur.dy);
        path.lineTo(cur.dx, cur.dy);
        lastWasCubic = false;
      case 'V':
        cur = Offset(cur.dx, (rel ? cur.dy : 0) + n());
        path.lineTo(cur.dx, cur.dy);
        lastWasCubic = false;
      case 'C':
        final c1 = base + Offset(n(), n()), c2 = base + Offset(n(), n()), e = base + Offset(n(), n());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
        lastWasCubic = true;
      case 'S':
        final c1 = lastWasCubic ? cur * 2 - lastCtrl : cur;
        final c2 = base + Offset(n(), n()), e = base + Offset(n(), n());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
        lastWasCubic = true;
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
        final e = base + Offset(n(), n());
        path.arcToPoint(e, radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
        cur = e;
        lastWasCubic = false;
      case 'Z':
        path.close();
        cur = start;
        lastWasCubic = false;
    }
  }
  return path;
}
