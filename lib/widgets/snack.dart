import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Eine Meldung unten: mit „Rückgängig“ als Snackbar (4 s), sonst als kurzer Toast.
class SnackMsg {
  SnackMsg(this.text, {this.undo, this.icon}) : duration = _durationFor(undo, icon);

  final String text;
  final VoidCallback? undo;
  final Ic? icon;
  final Duration duration;

  static Duration _durationFor(VoidCallback? undo, Ic? icon) {
    // Mit „Rückgängig“ bleibt es 4 s stehen, damit man den Knopf erreicht.
    if (undo != null) return const Duration(milliseconds: 4000);
    // Hinweise zum Konto (ganzer Satz zum Lesen) am längsten …
    if (icon == Ic.database) return const Duration(milliseconds: 4500);
    // … Meldungen zum Abgleich (offline, wieder online) mittellang …
    if (icon == Ic.cloudoff || icon == Ic.sync) return const Duration(milliseconds: 2600);
    // … und reine Bestätigungen („Gespeichert“) nur als kurzer Sprung.
    return const Duration(milliseconds: 1300);
  }
}

class SnackController extends ChangeNotifier {
  SnackMsg? current;
  Timer? _timer;

  void show(String text, {VoidCallback? undo, Ic? icon}) {
    _timer?.cancel();
    final m = SnackMsg(text, undo: undo, icon: icon);
    current = m;
    notifyListeners();
    _timer = Timer(m.duration, () {
      if (current == m) {
        current = null;
        notifyListeners();
      }
    });
  }

  void undo() {
    final u = current?.undo;
    _timer?.cancel();
    current = null;
    notifyListeners();
    u?.call();
  }

  void clear() {
    _timer?.cancel();
    current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Zeigt die aktuelle Meldung über allem anderen an (.snack / .snack.toast).
class SnackHost extends StatelessWidget {
  const SnackHost({super.key, required this.controller, required this.undoLabel, this.bottom = Sizes.fabBottom});
  final SnackController controller;
  final String undoLabel;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final m = controller.current;
        return Positioned(
          left: 12,
          right: 12,
          bottom: bottom + MediaQuery.paddingOf(context).bottom,
          child: m == null
              ? const SizedBox.shrink()
              // Eigenes Material: Am Anmelde-Bildschirm liegt die Meldung außerhalb jedes Scaffolds;
              // ohne Material zeichnet Flutter Text in der Notfall-Schrift (gelb unterstrichen).
              : Material(
                  type: MaterialType.transparency,
                  child: _Snack(key: ObjectKey(m), msg: m, undoLabel: undoLabel, onUndo: controller.undo),
                ),
        );
      },
    );
  }
}

class _Snack extends StatefulWidget {
  const _Snack({super.key, required this.msg, required this.undoLabel, required this.onUndo});
  final SnackMsg msg;
  final String undoLabel;
  final VoidCallback onUndo;

  @override
  State<_Snack> createState() => _SnackState();
}

class _SnackState extends State<_Snack> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  Timer? _outTimer;

  bool get _toast => widget.msg.undo == null;

  @override
  void initState() {
    super.initState();
    _in.forward();
    if (_toast) {
      // Toast: springt hoch und verschwindet gleich wieder (toastIn + toastOut)
      _outTimer = Timer(widget.msg.duration - const Duration(milliseconds: 250), () {
        if (mounted) _out.forward();
      });
    }
  }

  @override
  void dispose() {
    _outTimer?.cancel();
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final reduced = Motion.reduced(context);
    final m = widget.msg;
    final icon = m.icon == null ? null : AppIcon(m.icon!, size: _toast ? 18 : 20, color: tok.onInv);
    final Widget box;
    if (_toast) {
      box = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: tok.inv,
              borderRadius: BorderRadius.circular(Sizes.rToast),
              boxShadow: tok.snackShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon, const SizedBox(width: 6)],
                Flexible(
                  child: Text(m.text, style: TextStyle(color: tok.onInv, fontSize: 13.5)),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      box = Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        decoration: BoxDecoration(
          color: tok.inv,
          borderRadius: BorderRadius.circular(Sizes.rSnack),
          boxShadow: tok.snackShadow,
        ),
        child: Row(
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 8)],
            Expanded(
              child: Text(m.text, style: TextStyle(color: tok.onInv, fontSize: 14)),
            ),
            Pressable(
              onTap: widget.onUndo,
              semanticLabel: widget.undoLabel,
              excludeChildSemantics: true,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Text(
                  widget.undoLabel,
                  style: TextStyle(color: tok.invP, fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final semantic = Semantics(liveRegion: true, container: true, child: box);
    if (reduced) return semantic;
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      builder: (context, child) {
        final double dy, scale, opacity;
        if (_toast) {
          final i = Motion.toastIn.transform(_in.value);
          final o = Curves.easeIn.transform(_out.value);
          dy = 18 * (1 - i) + 8 * o;
          scale = (0.6 + 0.4 * i) * (1 - 0.15 * o);
          opacity = (_in.value * 2).clamp(0.0, 1.0) * (1 - o);
        } else {
          final i = Motion.snackUp.transform(_in.value);
          dy = 80 * (1 - i);
          scale = 1;
          opacity = 1;
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: semantic,
    );
  }
}
