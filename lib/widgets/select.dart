import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'overlays.dart';
import 'pressable.dart';

/// Auswahl statt Segment-Balken: zeigt den gewählten Wert in der Hauptfarbe und öffnet beim
/// Antippen ein Menü mit allen Möglichkeiten; der gewählte Wert hat einen Haken.
///
/// Mit [title] ist es eine ganze Zeile (Titel links, Wert und Pfeil rechts), ohne nur Wert
/// und Pfeil – z. B. in einer Kopfleiste. [label] nennt die Auswahl für Screenreader und das
/// Menü (Standard: [title]).
class SelectRow<T> extends StatefulWidget {
  const SelectRow({
    super.key,
    this.title,
    this.subtitle,
    String? label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  }) : label = label ?? title ?? '';

  final String? title;

  /// Kleine Erklärung unter dem Titel (nur mit [title]).
  final String? subtitle;
  final String label;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Innenabstand der Zeile; in Formularen ohne seitlichen Rand.
  final EdgeInsetsGeometry padding;

  @override
  State<SelectRow<T>> createState() => _SelectRowState<T>();
}

class _SelectRowState<T> extends State<SelectRow<T>> {
  /// Das Menü ist offen – der Pfeil zeigt dann nach oben.
  bool _open = false;

  String get _text => widget.options.firstWhere((o) => o.$1 == widget.value, orElse: () => widget.options.first).$2;

  Future<void> _openMenu() async {
    final rect = anchorRect(context);
    if (rect == null) return;
    setState(() => _open = true);
    await Navigator.of(context).push(
      AppMenuRoute(
        // Als Zeile: Menü rechts eingerückt und knapp unter der Zeile, wie im Entwurf.
        anchor: widget.title == null
            ? rect
            : Rect.fromLTRB(rect.left, rect.top, rect.right - Sizes.selectInset, rect.bottom - Sizes.selectOverlap),
        label: widget.label,
        minWidth: Sizes.selectMenuW,
        scrollBehind: Scrollable.maybeOf(context)?.position,
        builder: (menuContext) => [
          for (final o in widget.options)
            SelectOption(
              label: o.$2,
              selected: o.$1 == widget.value,
              onTap: () {
                Navigator.pop(menuContext);
                if (o.$1 != widget.value) widget.onChanged(o.$1);
              },
            ),
        ],
      ),
    );
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final title = widget.title;
    final end = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            _text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: Fs.base, fontWeight: FontWeight.w500, color: tok.p),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedRotation(
          turns: _open ? 0.5 : 0,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.emphasized,
          child: AppIcon(Ic.down, size: 18, color: tok.sub),
        ),
      ],
    );
    final Widget child = title == null
        ? Container(
            height: Sizes.selectCompactH,
            padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
            child: end,
          )
        : Container(
            constraints: const BoxConstraints(minHeight: Sizes.setRowH),
            padding: widget.padding,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, color: tok.text)),
                      if (widget.subtitle case final sub?)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(sub, style: TextStyle(fontSize: 13, color: tok.sub)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Wert rechtsbündig; lange Werte kürzen statt den Titel zu verdrängen.
                Flexible(
                  flex: 2,
                  child: Align(alignment: AlignmentDirectional.centerEnd, child: end),
                ),
              ],
            ),
          );
    return Pressable(
      onTap: _openMenu,
      pressScale: title == null ? 0.95 : 0.97,
      radius: title == null ? const BorderRadius.all(Radius.circular(999)) : BorderRadius.zero,
      semanticLabel: '${widget.label}: $_text',
      excludeChildSemantics: true,
      child: child,
    );
  }
}

/// Eine Möglichkeit im Auswahl-Menü: Haken links, der gewählte Wert hinterlegt.
class SelectOption extends StatelessWidget {
  const SelectOption({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    const radius = BorderRadius.all(Radius.circular(Sizes.rOption));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Pressable(
        onTap: onTap,
        pressScale: 0.97,
        glow: false,
        radius: radius,
        semanticLabel: label,
        selected: selected,
        excludeChildSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: Sizes.optionH),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: selected ? tok.pc : null, borderRadius: radius),
          child: Row(
            children: [
              SizedBox(width: 20, child: selected ? AppIcon(Ic.check, size: 18, stroke: 2.4, color: tok.p) : null),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: Fs.body, color: selected ? tok.onPc : tok.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
