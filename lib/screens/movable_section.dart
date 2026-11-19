import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../theme/tokens.dart';

/// Am Handy: ein Abschnitt der Aufgabenliste (Überschrift und Aufgaben), der sich mit langem
/// Druck auf die Überschrift an einen anderen Platz ziehen lässt. Die anderen Abschnitte rücken
/// schon beim Darüberziehen zur Seite – man sieht sofort, was Loslassen ergibt.
class MovableSection extends StatefulWidget {
  const MovableSection({
    super.key,
    required this.id,
    required this.head,
    required this.children,
    required this.onDrop,
    this.onUp,
    this.onDown,
  });
  final String id;
  final Widget head;
  final List<Widget> children;

  /// Ein anderer Abschnitt (seine ID) wurde auf diesen gezogen.
  final ValueChanged<String> onDrop;

  /// Einen Platz nach oben oder unten (für Screenreader).
  final VoidCallback? onUp, onDown;

  @override
  State<MovableSection> createState() => _MovableSectionState();
}

class _MovableSectionState extends State<MovableSection> {
  bool _dragging = false;
  EdgeDraggingAutoScroller? _scroller;

  void _end() {
    _scroller?.stopAutoScroll();
    if (mounted) setState(() => _dragging = false);
  }

  @override
  void dispose() {
    _scroller?.stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    return LayoutBuilder(
      builder: (context, box) {
        // Am Finger hängt der Abschnitt, wie er dasteht – bei vielen Aufgaben nur sein Anfang.
        final feedback = IgnorePointer(
          child: SizedBox(
            width: box.maxWidth,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxHeight: Sizes.dragPreviewMax),
                decoration: BoxDecoration(
                  color: tok.card,
                  borderRadius: BorderRadius.circular(Sizes.rCard),
                  border: Border.all(color: tok.p),
                  boxShadow: tok.cardShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [widget.head, ...widget.children],
                  ),
                ),
              ),
            ),
          ),
        );
        final head = LongPressDraggable<String>(
          data: widget.id,
          feedback: feedback,
          onDragStarted: () => setState(() => _dragging = true),
          // Am oberen oder unteren Rand scrollt die Liste mit, so erreicht man jeden Platz.
          onDragUpdate: (d) {
            final scrollable = Scrollable.maybeOf(context);
            if (scrollable == null) return;
            _scroller ??= EdgeDraggingAutoScroller(scrollable, velocityScalar: 40);
            _scroller!.startAutoScrollIfNecessary(Rect.fromCenter(center: d.globalPosition, width: 1, height: 96));
          },
          onDragEnd: (_) => _end(),
          child: Semantics(
            customSemanticsActions: {
              CustomSemanticsAction(label: l.moveUp): ?widget.onUp,
              CustomSemanticsAction(label: l.moveDown): ?widget.onDown,
            },
            child: widget.head,
          ),
        );
        return DragTarget<String>(
          onWillAcceptWithDetails: (d) {
            if (d.data == widget.id) return false;
            widget.onDrop(d.data);
            return true;
          },
          builder: (context, _, _) => Opacity(
            // Der gezogene Abschnitt steht blass an seinem neuen Platz.
            opacity: _dragging ? 0.35 : 1,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, ...widget.children]),
          ),
        );
      },
    );
  }
}
