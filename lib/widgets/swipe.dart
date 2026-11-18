import 'package:material_ui/material_ui.dart';

/// Wischen nach links/rechts blättert weiter (Monat im Kalender, Woche/Tag im Wochenplan).
/// [onMove] bekommt +1 (Wisch nach links = weiter) oder -1 (Wisch nach rechts = zurück).
class SwipeStep extends StatefulWidget {
  const SwipeStep({super.key, required this.onMove, required this.child});
  final void Function(int dir) onMove;
  final Widget child;

  @override
  State<SwipeStep> createState() => _SwipeStepState();
}

class _SwipeStepState extends State<SwipeStep> {
  static const _minDistance = 48.0;
  static const _minVelocity = 300.0;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true, // Screenreader nutzen die Pfeil-Knöpfe
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_dx.abs() < _minDistance && v.abs() < _minVelocity) return;
        // Bei schnellem Wisch entscheidet die Richtung der Bewegung am Ende.
        final right = v.abs() >= _minVelocity ? v > 0 : _dx > 0;
        widget.onMove(right ? -1 : 1);
      },
      child: widget.child,
    );
  }
}
