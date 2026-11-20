import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Wo ein blätternder Inhalt gerade steht: Verschiebung, Deckkraft und ob noch der alte
/// Inhalt zu sehen ist.
typedef PageFrame = ({double x, double opacity, bool old});

const PageFrame _rest = (x: 0, opacity: 1, old: false);

/// Bild nach [ms] Millisekunden beim Blättern in Richtung [dir] (+1 = weiter). Der alte Inhalt
/// gleitet von [from] um [distance] hinaus, ab [Motion.pageInAt] kommt der neue von der
/// anderen Seite herein. [title]: Der Titel gleitet nur kurz und blendet ganz aus.
@visibleForTesting
PageFrame pageFrame({
  required double ms,
  required int dir,
  required double distance,
  double from = 0,
  bool title = false,
}) {
  double at(Duration d, double start) => ((ms - start) / d.inMilliseconds).clamp(0.0, 1.0);
  final inAt = Motion.pageInAt.inMilliseconds.toDouble();
  if (ms < inAt) {
    final outDur = title ? Motion.titleOut : Motion.pageOut;
    final t = at(outDur, 0);
    final move = (title ? Curves.easeIn : Motion.pageOutCurve).transform(t);
    final fade = (title ? Curves.easeIn : Curves.ease).transform(t);
    return (
      x: from + (-dir * distance - from) * move,
      opacity: 1 - (1 - (title ? 0 : Motion.pageDim)) * fade,
      old: true,
    );
  }
  final dim = title ? 0.0 : Motion.pageDim;
  final move = Motion.emphasized.transform(at(title ? Motion.titleIn : Motion.pageIn, inAt));
  final fade = Curves.ease.transform(at(title ? Motion.titleIn : Motion.pageInFade, inAt));
  return (x: dir * distance * (1 - move), opacity: dim + (1 - dim) * fade, old: false);
}

/// Gesamtdauer eines Blätter-Schritts.
Duration get _pageTotal => Motion.pageInAt + Motion.pageIn;

/// Gemeinsame Logik: merkt sich beim Wechsel von [page] den alten Inhalt und spielt das
/// Hinaus- und Hereingleiten ab. Ein Wechsel von [group] (Woche ↔ Tag) springt ohne Gleiten.
mixin _PageSwap<T extends StatefulWidget> on State<T>, TickerProvider {
  late final AnimationController _c = AnimationController(vsync: this, value: 1);
  int _dir = 1;
  double _from = 0;
  bool _fade = false;
  Widget? _old;

  DateTime get page;
  Object? get group;

  void swap({required DateTime oldPage, required Object? oldGroup, required Widget oldChild, double from = 0}) {
    if (oldPage == page) return;
    if (oldGroup != group) {
      _c.value = 1;
      _old = null;
      return;
    }
    _dir = page.isAfter(oldPage) ? 1 : -1;
    _from = from;
    _old = oldChild;
    _fade = Motion.reduced(context);
    _c.duration = _fade ? Motion.crossFade : _pageTotal;
    _c.forward(from: 0);
  }

  PageFrame frame(double distance, {bool title = false}) {
    if (!_c.isAnimating) return _rest;
    if (_fade) return (x: 0, opacity: Curves.ease.transform(_c.value), old: false);
    final ms = _c.value * _pageTotal.inMilliseconds;
    return pageFrame(ms: ms, dir: _dir, distance: distance, from: _from, title: title);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}

/// Titel (Monat, Kalenderwoche), der beim Blättern mitgleitet und überblendet.
class PageTitle extends StatefulWidget {
  const PageTitle({super.key, required this.page, this.group, required this.child});
  final DateTime page;
  final Object? group;
  final Widget child;

  @override
  State<PageTitle> createState() => _PageTitleState();
}

class _PageTitleState extends State<PageTitle> with SingleTickerProviderStateMixin, _PageSwap<PageTitle> {
  @override
  DateTime get page => widget.page;
  @override
  Object? get group => widget.group;

  @override
  void didUpdateWidget(PageTitle old) {
    super.didUpdateWidget(old);
    swap(oldPage: old.page, oldGroup: old.group, oldChild: old.child);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final f = frame(Sizes.titleShift, title: true);
      return Transform.translate(
        offset: Offset(f.x, 0),
        child: Opacity(opacity: f.opacity, child: f.old ? _old! : widget.child),
      );
    },
  );
}

/// Wischen nach links/rechts blättert weiter (Monat im Kalender, Woche/Tag im Wochenplan).
///
/// Beim Ziehen folgt der Inhalt dem Finger, dahinter steht der Name der nächsten bzw. vorigen
/// Seite ([peek]). Ab [Sizes.swipeThreshold] (oder schnell gewischt) ruft es [onMove] mit +1
/// (Wisch nach links = weiter) bzw. -1 auf, sonst federt der Inhalt zurück. Ändert sich [page]
/// – auch über Pfeile oder „Heute“ –, gleitet der alte Inhalt hinaus und der neue herein.
class SwipePager extends StatefulWidget {
  const SwipePager({
    super.key,
    required this.page,
    this.group,
    required this.onMove,
    required this.peek,
    required this.child,
  });

  final DateTime page;

  /// Ändert sich die Art der Ansicht (Woche ↔ Tag), wird nicht geblättert.
  final Object? group;
  final void Function(int dir) onMove;
  final String Function(int dir) peek;
  final Widget child;

  @override
  State<SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<SwipePager> with TickerProviderStateMixin, _PageSwap<SwipePager> {
  static const _minVelocity = 300.0;

  /// Ab dieser Verschiebung erscheint der Name der nächsten Seite.
  static const _peekFrom = 8.0;

  /// Verschiebung durch den Finger (bei „Animationen reduzieren“ bleibt sie 0) und die
  /// gewischte Strecke, nach der entschieden wird.
  double _drag = 0;
  double _dist = 0;
  bool _dragging = false;
  late final AnimationController _back = AnimationController(vsync: this, value: 1)..addListener(_onBack);
  double _backFrom = 0;

  @override
  DateTime get page => widget.page;
  @override
  Object? get group => widget.group;

  void _onBack() => setState(() => _drag = _backFrom * (1 - Motion.swipeBack.transform(_back.value)));

  @override
  void didUpdateWidget(SwipePager old) {
    super.didUpdateWidget(old);
    final from = _drag;
    if (old.page != widget.page) {
      _back.stop();
      _drag = 0;
    }
    swap(oldPage: old.page, oldGroup: old.group, oldChild: old.child, from: from);
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _start() {
    _back.stop();
    _dragging = true;
    _dist = _drag;
  }

  void _update(DragUpdateDetails d) {
    _dist += d.delta.dx;
    if (Motion.reduced(context) || _c.isAnimating) return;
    setState(() => _drag += d.delta.dx);
  }

  void _end(DragEndDetails d) {
    _dragging = false;
    final v = d.primaryVelocity ?? 0;
    if (_dist.abs() >= Sizes.swipeThreshold || v.abs() >= _minVelocity) {
      // Bei schnellem Wisch entscheidet die Richtung der Bewegung am Ende.
      final right = v.abs() >= _minVelocity ? v > 0 : _dist > 0;
      widget.onMove(right ? -1 : 1);
      // Blättert die Seite doch nicht weiter, federt der Inhalt zurück.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _drag != 0 && !_dragging) _springBack();
      });
      return;
    }
    _springBack();
  }

  void _springBack() {
    if (_drag == 0) return;
    _backFrom = _drag;
    _back.duration = Motion.swipeBackDur;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true, // Screenreader nutzen die Pfeil-Knöpfe
      onHorizontalDragStart: (_) => _start(),
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () {
        _dragging = false;
        _springBack();
      },
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final f = frame(box.maxWidth);
            final x = f.x + _drag;
            final shown = _drag.abs() > _peekFrom;
            final peek = Positioned(
              top: 0,
              bottom: 0,
              left: x > 0 ? 0 : null,
              right: x < 0 ? 0 : null,
              // Nur der freie Streifen zeigt den Namen – der Inhalt schiebt sich darüber weg.
              width: shown ? x.abs().clamp(0.0, Sizes.swipePeek) : 0,
              child: !shown
                  ? const SizedBox.shrink()
                  : ClipRect(
                      child: OverflowBox(
                        minWidth: Sizes.swipePeek,
                        maxWidth: Sizes.swipePeek,
                        alignment: x < 0 ? Alignment.centerLeft : Alignment.centerRight,
                        child: Opacity(
                          opacity: (_drag.abs() / Sizes.swipeThreshold).clamp(0.0, 1.0),
                          child: Center(child: _PeekLabel(_drag < 0 ? widget.peek(1) : widget.peek(-1), tok: tok)),
                        ),
                      ),
                    ),
            );
            return Stack(
              fit: StackFit.passthrough,
              children: [
                peek,
                Transform.translate(
                  offset: Offset(x, 0),
                  child: Opacity(opacity: f.opacity, child: f.old ? _old! : widget.child),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Name der nächsten bzw. vorigen Seite hinter dem gezogenen Inhalt.
class _PeekLabel extends StatelessWidget {
  const _PeekLabel(this.text, {required this.tok});
  final String text;
  final AppTokens tok;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: tok.surf2, borderRadius: BorderRadius.circular(Sizes.rPop)),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontSize: Fs.base, fontWeight: FontWeight.w500, color: tok.onPc),
      ),
    ),
  );
}
