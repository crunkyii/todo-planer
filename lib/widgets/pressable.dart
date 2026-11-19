import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Kurzes Haptik-Feedback (wie `buzz()` im Prototyp).
void buzz() => HapticFeedback.selectionClick();

/// „Gewichtiger“ Knopf: gibt beim Drücken elastisch nach, schwingt beim Loslassen
/// federnd zurück (Überschwingen = Trägheit) und zeigt ein Fingerlicht.
/// Respektiert „Animationen reduzieren“. Bedienbar mit Tastatur (Enter/Leertaste).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.selected,
    this.toggled,
    this.glow = true,
    this.pressScale = 0.92,
    this.overshoot = 0.045,
    this.radius = const BorderRadius.all(Radius.circular(999)),
    this.tooltip,
    this.excludeChildSemantics = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool? selected;
  final bool? toggled;
  final bool glow;

  /// 0.92 für Knöpfe, 0.97 für ganze Zeilen/Karten.
  final double pressScale;

  /// Wie weit der Inhalt beim Loslassen über seine Größe hinausfedert. Breite Zeilen brauchen
  /// weniger: Dieselben Prozent verschieben dort die Schrift um viel mehr Pixel.
  final double overshoot;
  final BorderRadius radius;
  final String? tooltip;
  final bool excludeChildSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _Glow {
  _Glow(this.at, this.ctrl);
  final Offset at;
  final AnimationController ctrl;
}

class _PressableState extends State<Pressable> with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(vsync: this, value: 1, lowerBound: 0.8, upperBound: 1.1);
  final List<_Glow> _glows = [];
  bool _focus = false;
  bool _hasFocus = false; // für Screenreader, auch wenn kein Fokus-Rahmen gezeigt wird

  bool get _reduced => Motion.reduced(context);

  @override
  void dispose() {
    _scale.dispose();
    for (final g in _glows) {
      g.ctrl.dispose();
    }
    super.dispose();
  }

  void _down(TapDownDetails d) {
    if (widget.onTap == null || _reduced) return;
    _scale.animateTo(widget.pressScale, duration: Motion.press, curve: Curves.easeOut);
    if (widget.glow) _addGlow(d.localPosition);
  }

  void _addGlow(Offset at) {
    final c = AnimationController(vsync: this, duration: Motion.glow);
    final g = _Glow(at, c);
    setState(() => _glows.add(g));
    c.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _glows.remove(g));
      c.dispose();
    });
  }

  void _release() {
    if (_reduced) {
      _scale.value = 1;
      return;
    }
    // 0 % → 0.92, 40 % → 1.045, 70 % → 0.99, 100 % → 1 (Keyframes `release` aus dem CSS)
    _scale
        .animateTo(1 + widget.overshoot, duration: Motion.releaseDur * 0.4, curve: Motion.release)
        // Die Schritte laufen nacheinander – ist der Knopf inzwischen weg (z. B. Seite gewechselt),
        // nicht weiter animieren.
        .then((_) {
          if (mounted) {
            return _scale.animateTo(
              1 - widget.overshoot * 0.22,
              duration: Motion.releaseDur * 0.3,
              curve: Curves.easeInOut,
            );
          }
        })
        .then((_) {
          if (mounted) _scale.animateTo(1, duration: Motion.releaseDur * 0.3, curve: Curves.easeOut);
        });
  }

  void _activate() {
    if (widget.onTap == null) return;
    _release();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    Widget child = AnimatedBuilder(
      animation: _scale,
      builder: (context, c) => Transform.scale(scale: _scale.value, child: c),
      child: _glows.isEmpty
          ? widget.child
          : Stack(
              clipBehavior: Clip.none,
              // Der Inhalt bekommt dieselben Maße wie ohne Schimmer – sonst schrumpft er beim Klick
              // auf seine eigene Größe und springt (z. B. die Schrift in der Navigation links).
              fit: StackFit.passthrough,
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: widget.radius,
                      child: CustomPaint(painter: _GlowPainter(_glows, tok.glowStrong)),
                    ),
                  ),
                ),
              ],
            ),
    );
    if (_focus) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          border: Border.all(color: tok.p, width: 2),
        ),
        child: child,
      );
    }
    // Tippen und Fokus meldet nur das Semantics-Widget unten. Sonst entsteht für
    // Screenreader ein zweiter antippbarer Knoten ohne Beschriftung.
    child = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: widget.onTap == null ? null : (_) => _release(),
      onTapCancel: widget.onTap == null ? null : _release,
      onTap: widget.onTap,
      child: child,
    );
    child = FocusableActionDetector(
      enabled: widget.onTap != null,
      includeFocusSemantics: false,
      mouseCursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      onFocusChange: (v) => setState(() => _hasFocus = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
      child: child,
    );
    child = Semantics(
      button: true,
      enabled: widget.onTap != null,
      focusable: widget.onTap != null,
      focused: widget.onTap != null && _hasFocus,
      label: widget.semanticLabel,
      selected: widget.selected,
      toggled: widget.toggled,
      excludeSemantics: widget.excludeChildSemantics,
      onTap: widget.onTap,
      child: child,
    );
    // Der Name steht schon im Semantics-Label; der Tooltip ist nur für Maus/Langdruck.
    if (widget.tooltip != null) child = Tooltip(message: widget.tooltip!, excludeFromSemantics: true, child: child);
    return child;
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.glows, this.color) : super(repaint: Listenable.merge([for (final g in glows) g.ctrl]));
  final List<_Glow> glows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in glows) {
      final t = Curves.easeOut.transform(g.ctrl.value);
      final r = 90 * (0.25 + 1.25 * t);
      final opacity = 1 - t;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: color.a * opacity),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.62],
        ).createShader(Rect.fromCircle(center: g.at, radius: r));
      canvas.drawCircle(g.at, r, paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => true;
}
