import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show Drag;
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Milchglas-Fläche (backdrop-filter: blur + saturate).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
    this.blur = 22,
    this.border,
    this.shadow = const [],
  });
  final Widget child;
  final Color color;
  final BorderRadius radius;
  final double blur;
  final BoxBorder? border;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: radius, border: border),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bottom-Sheet aus dem Prototyp: Milchglas, federt von unten hoch, Scrim dahinter.
/// Esc und Tipp auf den Scrim schließen es.
class AppSheetRoute<T> extends PopupRoute<T> {
  AppSheetRoute({required this.builder, required this.label, required this.scrim});

  final WidgetBuilder builder;
  final String label;
  final Color scrim;

  @override
  Color? get barrierColor => scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration => Motion.sheet;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final tok = context.tok;
    final mq = MediaQuery.of(context);
    // Der Abstand für die Tastatur liegt AUSSEN: Innerhalb der Höhenbegrenzung würde er dem
    // Sheet den Platz wegnehmen (auf kleinen Handys bliebe Höhe 0 – das Sheet wäre unsichtbar).
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Sizes.maxWidth,
            maxHeight: (mq.size.height - mq.viewInsets.bottom) * 0.88,
          ),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: label,
            child: Glass(
              color: tok.glassStrong,
              blur: 28,
              radius: const BorderRadius.vertical(top: Radius.circular(Sizes.rSheet)),
              border: Border(top: BorderSide(color: tok.glassEdge)),
              shadow: tok.sheetShadow,
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 14 + (mq.viewInsets.bottom > 0 ? 0 : mq.padding.bottom)),
                  child: builder(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: Motion.sheetUp, reverseCurve: Curves.easeIn);
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
      child: child,
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, {required String label, required WidgetBuilder builder}) =>
    Navigator.of(context).push(AppSheetRoute<T>(builder: builder, label: label, scrim: context.tok.scrim));

/// Bildschirm-Rechteck eines Knopfs – dort klappt das Menü auf.
Rect? anchorRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

/// Eintrag im ⋮-Menü.
class MenuEntry {
  const MenuEntry({required this.label, this.icon, required this.onTap, this.checked = false, this.radio = false});
  final String label;
  final Ic? icon;
  final VoidCallback onTap;
  final bool checked;
  final bool radio;
}

/// ⋮-Menü: Milchglas-Kärtchen oben rechts, springt aus der Ecke auf.
class AppMenuRoute extends PopupRoute<void> {
  AppMenuRoute({required this.anchor, required this.builder, required this.label, this.scrollBehind});

  /// Position des ⋮-Knopfs (global).
  final Rect anchor;
  final List<Widget> Function(BuildContext context) builder;
  final String label;

  /// Die Liste hinter dem Menü. Wer neben dem Menü wischt, scrollt sie – das Menü geht dabei zu.
  final ScrollPosition? scrollBehind;

  /// Unter dieser Höhe klappt das Menü nach oben auf, wenn dort mehr Platz ist.
  static const _minBelow = 220.0;

  final _hidden = ValueNotifier(false);
  Drag? _drag;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration => Motion.menu;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  void _close() {
    if (isActive) navigator?.removeRoute(this);
  }

  void _endDrag(void Function(Drag d) finish) {
    final d = _drag;
    _drag = null;
    if (d != null) finish(d);
    _close();
  }

  /// Fläche neben dem Menü: Tippen schließt; senkrecht Wischen blendet das Menü aus
  /// und reicht die Bewegung an die Liste dahinter weiter.
  @override
  Widget buildModalBarrier() {
    return Semantics(
      label: label,
      onDismiss: _close,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () {
          if (isCurrent) navigator?.pop();
        },
        onVerticalDragStart: (d) {
          _hidden.value = true;
          _drag = scrollBehind?.drag(d, () => _drag = null);
        },
        onVerticalDragUpdate: (d) => _drag?.update(d),
        onVerticalDragEnd: (d) => _endDrag((x) => x.end(d)),
        onVerticalDragCancel: () => _endDrag((x) => x.cancel()),
      ),
    );
  }

  @override
  void dispose() {
    _drag?.cancel();
    _hidden.dispose();
    super.dispose();
  }

  ({double below, double above, bool up}) _space(BuildContext context) {
    final mq = MediaQuery.of(context);
    final below = mq.size.height - mq.padding.bottom - mq.viewInsets.bottom - anchor.bottom - 8;
    final above = anchor.top - mq.padding.top - 8;
    return (below: below, above: above, up: below < _minBelow && above > below);
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final tok = context.tok;
    final size = MediaQuery.sizeOf(context);
    final sp = _space(context);
    return Stack(
      children: [
        Positioned(
          top: sp.up ? null : anchor.bottom - 2,
          bottom: sp.up ? size.height - anchor.top - 2 : null,
          right: (size.width - anchor.right).clamp(8, size.width),
          child: ValueListenableBuilder(
            valueListenable: _hidden,
            builder: (context, hidden, child) => IgnorePointer(
              ignoring: hidden,
              child: AnimatedOpacity(opacity: hidden ? 0 : 1, duration: Motion.press, child: child),
            ),
            child: ConstrainedBox(
              // Nie höher als der freie Platz – längere Listen scrollen im Menü.
              constraints: BoxConstraints(
                minWidth: 188,
                maxWidth: 240,
                maxHeight: (sp.up ? sp.above : sp.below).clamp(96, 2000),
              ),
              child: Glass(
                color: tok.glassStrong,
                blur: 24,
                radius: BorderRadius.circular(Sizes.rMenu),
                border: Border.all(color: tok.glassEdge),
                shadow: tok.popShadow,
                child: Material(
                  type: MaterialType.transparency,
                  child: IntrinsicWidth(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: builder(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: Motion.spring, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.4)),
      child: ScaleTransition(
        alignment: Alignment(1 - 2 * 8 / MediaQuery.sizeOf(context).width, _space(context).up ? 1 : -1),
        scale: Tween(begin: 0.82, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

/// Eine Zeile im Menü.
class MenuItemRow extends StatelessWidget {
  const MenuItemRow({super.key, required this.entry});
  final MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Pressable(
      onTap: entry.onTap,
      pressScale: 0.97,
      glow: false,
      radius: BorderRadius.zero,
      semanticLabel: entry.label,
      selected: entry.radio ? entry.checked : null,
      excludeChildSemantics: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (entry.icon != null) ...[AppIcon(entry.icon!, size: 20, color: tok.sub), const SizedBox(width: 12)],
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: tok.text),
              ),
            ),
            if (entry.checked) ...[const SizedBox(width: 12), AppIcon(Ic.check, size: 18, stroke: 2.4, color: tok.p)],
          ],
        ),
      ),
    );
  }
}

class MenuSep extends StatelessWidget {
  const MenuSep({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: context.tok.lineSoft);
}
