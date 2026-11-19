import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Eine Spalte, deren Einträge an ihren neuen Platz **gleiten**, wenn sich die Reihenfolge
/// ändert (z. B. eine abgehakte Gewohnheit rutscht nach unten), statt dorthin zu springen.
///
/// Jedes Kind braucht einen [Key], der am Eintrag hängt (nicht an der Position) – nur so
/// erkennt Flutter, dass derselbe Eintrag gewandert ist. Das Layout ändert sich sofort;
/// verschoben wird nur das Bild, und das kurz verzögert ([delay]), damit man zuerst das
/// Abhaken sieht. Die Kinder sind so breit wie die Spalte.
class FlipColumn extends StatefulWidget {
  const FlipColumn({super.key, required this.children, this.delay = 0.25});
  final List<Widget> children;

  /// Anteil der Dauer (0–1), den ein Eintrag noch am alten Platz stehen bleibt.
  final double delay;

  static const duration = Duration(milliseconds: 700);

  @override
  State<FlipColumn> createState() => _FlipColumnState();
}

class _FlipColumnState extends State<FlipColumn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: FlipColumn.duration, value: 1);
  late final _curve = CurvedAnimation(
    parent: _c,
    curve: Interval(widget.delay, 1, curve: Motion.springSoft),
  );

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _c.duration = Motion.of(context, FlipColumn.duration);
    return _FlipFlex(controller: _c, curve: _curve, children: widget.children);
  }
}

class _FlipFlex extends MultiChildRenderObjectWidget {
  const _FlipFlex({required this.controller, required this.curve, required super.children});
  final AnimationController controller;
  final Animation<double> curve;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFlip(controller, curve);
}

class _FlipData extends ContainerBoxParentData<RenderBox> {
  /// Platz nach dem letzten Layout – `null`, solange der Eintrag neu ist.
  Offset? last;

  /// Von hier (relativ zum neuen Platz) gleitet der Eintrag gerade los.
  Offset from = Offset.zero;
}

class _RenderFlip extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FlipData>, RenderBoxContainerDefaultsMixin<RenderBox, _FlipData> {
  _RenderFlip(this._controller, this._curve);
  final AnimationController _controller;
  final Animation<double> _curve;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FlipData) child.parentData = _FlipData();
  }

  /// Reihenfolge der Kinder nach dem letzten Layout.
  List<RenderBox> _order = const [];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _curve.addListener(markNeedsPaint);
    _controller.addStatusListener(_arrived);
  }

  @override
  void detach() {
    _curve.removeListener(markNeedsPaint);
    _controller.removeStatusListener(_arrived);
    super.detach();
  }

  /// Angekommen: Der Screenreader soll den Eintrag am neuen Platz finden, nicht am alten.
  void _arrived(AnimationStatus status) {
    if (status == AnimationStatus.completed) markNeedsSemanticsUpdate();
  }

  /// Wie weit [d] gerade noch von seinem Platz entfernt gezeichnet wird.
  Offset _shift(_FlipData d) => d.from * (1 - _curve.value);

  @override
  void performLayout() {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    final inner = BoxConstraints.tightFor(width: width);
    final places = <RenderBox, Offset>{};
    var y = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      child.layout(inner, parentUsesSize: true);
      places[child] = Offset(0, y);
      y += child.size.height;
    }
    // Gleiten nur, wenn Einträge die Plätze getauscht haben – nicht, wenn sich bloß Höhen
    // ändern (Fenstergröße, Schriftgröße) oder ein Eintrag dazukommt bzw. wegfällt.
    final order = places.keys.toList();
    final before = [
      for (final c in _order)
        if (places.containsKey(c)) c,
    ];
    final after = [
      for (final c in order)
        if (_order.contains(c)) c,
    ];
    var moved = false;
    for (var i = 0; i < before.length && !moved; i++) {
      moved = before[i] != after[i];
    }
    _order = order;
    for (final MapEntry(key: child, value: place) in places.entries) {
      final d = child.parentData! as _FlipData;
      // Neu losgleiten: vom Platz, an dem der Eintrag gerade zu sehen ist (auch mitten im Gleiten).
      if (moved) d.from = (d.last ?? place) + _shift(d) - place;
      d
        ..offset = place
        ..last = place;
    }
    size = constraints.constrain(Size(width, y));
    if (moved) _controller.forward(from: 0);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    final inner = BoxConstraints.tightFor(width: width);
    return constraints.constrain(Size(width, _sum((c) => c.getDryLayout(inner).height)));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _max((c) => c.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) => _max((c) => c.getMaxIntrinsicWidth(double.infinity));

  double _max(double Function(RenderBox) of) {
    var w = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final v = of(child);
      if (v > w) w = v;
    }
    return w;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _sum((c) => c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _sum((c) => c.getMaxIntrinsicHeight(width));

  double _sum(double Function(RenderBox) of) {
    var h = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      h += of(child);
    }
    return h;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final d = child.parentData! as _FlipData;
      context.paintChild(child, offset + d.offset + _shift(d));
    }
  }

  // Tippen und Vorlesen folgen dem Bild, nicht dem Layout-Platz.
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final d = child.parentData! as _FlipData;
    final at = d.offset + _shift(d);
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (var child = lastChild; child != null; child = childBefore(child)) {
      final d = child.parentData! as _FlipData;
      final hit = result.addWithPaintOffset(
        offset: d.offset + _shift(d),
        position: position,
        hitTest: (result, at) => child!.hitTest(result, position: at),
      );
      if (hit) return true;
    }
    return false;
  }
}
