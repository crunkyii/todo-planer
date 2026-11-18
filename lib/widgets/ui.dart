import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/color_math.dart';
import '../theme/tokens.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Kleine Bausteine aus dem Prototyp (.chip, .seg, .switch, .btn, .icon-btn, .input …).

/// Text mit `<b>…</b>`-Markierungen (aus den ARB-Dateien) fett darstellen.
class RichB extends StatelessWidget {
  const RichB(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp(r'<b>(.*?)</b>');
    var i = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      spans.add(
        TextSpan(
          text: m.group(1),
          style: TextStyle(fontWeight: FontWeight.w500, color: style?.color),
        ),
      );
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}

/// Runder Icon-Knopf 44×44 (.icon-btn).
class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, required this.label, required this.onTap, this.pressed, this.size = 24});
  final Ic icon;
  final String label;
  final VoidCallback? onTap;
  final bool? pressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final on = pressed == true;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      toggled: pressed,
      glow: false,
      tooltip: label,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: Sizes.iconBtn,
        height: Sizes.iconBtn,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? tok.pc : Colors.transparent),
        alignment: Alignment.center,
        child: AppIcon(icon, size: size, color: on ? tok.p : tok.sub),
      ),
    );
  }
}

/// Filter-/Auswahl-Chip (.chip, .chip.cat).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.colors,
    this.height = Sizes.chipH,
    this.padding = 16,
    this.fontSize = 14,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ItemColors? colors;
  final double height;
  final double padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final c = colors;
    final bg = selected ? (c?.c ?? tok.p) : (c?.ct ?? tok.surf2);
    final fg = selected ? (c?.cs ?? tok.onP) : (c?.ci ?? tok.sub);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: padding),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 2)),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Segment-Knöpfe (.seg) – eine Auswahl aus wenigen Optionen.
class Seg<T> extends StatelessWidget {
  const Seg({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.mini = false,
    this.label,
    this.wrap = false,
  });
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool mini;
  final String? label;

  /// Zwei Zeilen wie `.seg.wrap` (Kategorie-Vorlauf).
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final h = mini ? 32.0 : 38.0;
    Widget btn((T, String) o, {required bool last, bool expand = false}) {
      final on = o.$1 == value;
      return Pressable(
        onTap: () => onChanged(o.$1),
        selected: on,
        semanticLabel: o.$2,
        excludeChildSemantics: true,
        radius: BorderRadius.zero,
        pressScale: 0.95,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? tok.pc : Colors.transparent,
            border: last ? null : Border(right: BorderSide(color: tok.line)),
          ),
          child: Text(
            o.$2,
            maxLines: 1,
            style: TextStyle(fontSize: mini ? 12.5 : 13, fontWeight: FontWeight.w500, color: on ? tok.onPc : tok.text),
          ),
        ),
      );
    }

    final Widget body;
    if (wrap) {
      final rows = <Widget>[];
      for (var i = 0; i < options.length; i += 2) {
        rows.add(
          Row(
            children: [
              for (var j = i; j < i + 2 && j < options.length; j++)
                Expanded(child: btn(options[j], last: j == i + 1 || j == options.length - 1)),
            ],
          ),
        );
        if (i + 2 < options.length) rows.add(Divider(height: 1, thickness: 1, color: tok.line));
      }
      body = Column(mainAxisSize: MainAxisSize.min, children: rows);
    } else {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < options.length; i++) btn(options[i], last: i == options.length - 1)],
      );
    }
    return Semantics(
      container: true,
      label: label,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: tok.line),
          borderRadius: BorderRadius.circular(wrap ? 12 : Sizes.rSeg),
        ),
        child: body,
      ),
    );
  }
}

/// Schalter (.switch).
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final d = Motion.of(context, Motion.fast);
    return Pressable(
      onTap: () => onChanged(!value),
      semanticLabel: label,
      toggled: value,
      glow: false,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: d,
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          color: value ? tok.p : tok.surf2,
          border: Border.all(color: value ? tok.p : tok.line, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: d,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: d,
            margin: EdgeInsets.symmetric(horizontal: value ? 2 : 6),
            width: value ? 24 : 16,
            height: value ? 24 : 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: value ? tok.onP : tok.sub),
          ),
        ),
      ),
    );
  }
}

enum BtnKind { filled, text, tonal, danger }

/// Knopf (.btn filled/text/tonal/danger, .btn.big).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = BtnKind.filled,
    this.icon,
    this.big = false,
    this.loading = false,
    this.height,
    this.fontSize,
    this.color,
    this.fontWeight = FontWeight.w500,
    this.padding,
  });

  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final Ic? icon;
  final bool big;
  final bool loading;
  final double? height;
  final double? fontSize;
  final Color? color;
  final FontWeight fontWeight;
  final double? padding;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final (bg, fg) = switch (kind) {
      BtnKind.filled => (tok.p, tok.onP),
      BtnKind.text => (Colors.transparent, tok.p),
      BtnKind.tonal => (tok.pc, tok.onPc),
      BtnKind.danger => (Colors.transparent, tok.err),
    };
    final h = height ?? (big ? 48.0 : 40.0);
    final fgc = color ?? fg;
    final content = Row(
      mainAxisSize: big ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: fgc)),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          AppIcon(icon!, size: 18, color: fgc),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fgc, fontSize: fontSize ?? 14, fontWeight: fontWeight),
          ),
        ),
      ],
    );
    return Pressable(
      onTap: loading ? null : onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: padding ?? (kind == BtnKind.danger ? 12 : 20)),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(h / 2)),
        child: content,
      ),
    );
  }
}

/// Eingabefeld (.input) mit Label darüber (.field/.lbl).
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLength,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
    this.autofocus = false,
    this.focusNode,
    this.onSubmitted,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      child: AppInput(
        controller: controller,
        hint: hint,
        semanticLabel: label,
        maxLength: maxLength,
        obscure: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        suffix: suffix,
        autofocus: autofocus,
        focusNode: focusNode,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
      ),
    );
  }
}

/// Kleine Beschriftung über einem Eingabe-Element (.field) – für alles, was kein Textfeld ist
/// (Farbauswahl, Wochentage …); Textfelder nehmen gleich [AppField].
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: context.tok.sub),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

/// Das reine Eingabefeld (.input): 46 hoch, Rahmen, beim Fokus 2 px in der Hauptfarbe.
class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.controller,
    this.hint,
    this.semanticLabel,
    this.maxLength,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
    this.autofocus = false,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction,
    this.height = 46,
    this.fontSize = Fs.input,
    this.filled = false,
    this.multiline = false,
  });

  final TextEditingController controller;
  final String? hint;
  final String? semanticLabel;
  final int? maxLength;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final double height;
  final double fontSize;

  /// `true` = Fläche ohne Rahmen (.slim-input, Suche).
  final bool filled;

  /// Mehrere Zeilen (Notiz): Enter macht eine neue Zeile, das Feld wächst bis [maxLinesMultiline]
  /// mit und scrollt danach; [height] gilt dann als Mindesthöhe.
  final bool multiline;

  static const maxLinesMultiline = 8;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    OutlineInputBorder b(Color c, double w, double r) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(r),
      borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
    );
    final r = filled ? (height >= 50 ? Sizes.rSlim : height / 2) : Sizes.rInput;
    final plainText = !obscure && keyboardType == null;
    final pad = multiline ? 10.0 : (height - fontSize * 1.3) / 2;
    return SizedBox(
      height: multiline ? null : height,
      child: TextField(
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? maxLinesMultiline : 1,
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        obscureText: obscure,
        keyboardType: multiline ? TextInputType.multiline : keyboardType,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        textInputAction: multiline ? TextInputAction.newline : textInputAction,
        // Tippen neben das Feld (anderer Knopf, freie Fläche, Scrollen): Fokus und Tastatur weg.
        // Standard am Handy wäre „bleibt offen“ – dann blieb der Cursor im Namensfeld stehen,
        // während man z. B. schon die Uhrzeit einstellte. Was zum Feld gehört (z. B. der Knopf
        // „+ Unteraufgabe“), wird mit TextFieldTapRegion ausgenommen.
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        // Normale Textfelder (Titel, Namen): Wortvorschläge der Tastatur, Autokorrektur und
        // großer Satzanfang. Nicht bei Passwort, E-Mail, Adressen oder Schlüsseln.
        autocorrect: plainText,
        enableSuggestions: plainText,
        textCapitalization: plainText ? TextCapitalization.sentences : TextCapitalization.none,
        style: TextStyle(fontSize: fontSize, color: tok.text),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          semanticCounterText: '',
          hintStyle: TextStyle(color: tok.sub.withValues(alpha: 0.75), fontSize: fontSize),
          filled: true,
          fillColor: filled ? tok.surf2 : tok.bg,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: filled ? 16 : 12, vertical: pad),
          enabledBorder: b(tok.line, filled ? 0 : 1, r),
          border: b(tok.line, filled ? 0 : 1, r),
          focusedBorder: b(tok.p, 2, r),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

/// Großer Überschrift-Abschnitt in Großbuchstaben (.set-h, .section-h).
class CapsHeading extends StatelessWidget {
  const CapsHeading(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 8)});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: context.tok.sub),
      ),
    ),
  );
}

/// Opake Karte (.card): Fläche, Radius 22, weicher Schatten.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 12),
    this.margin = const EdgeInsets.fromLTRB(12, 10, 12, 0),
    this.radius = Sizes.rCardLarge,
  });
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: tok.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: tok.cardShadow,
      ),
      child: child,
    );
  }
}

/// Kopfzeile mit Titel (.topbar), optional mit Zurück-Pfeil.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.onBack, this.backLabel, this.trailing});
  final String title;
  final VoidCallback? onBack;
  final String? backLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: EdgeInsets.fromLTRB(onBack != null ? 4 : 20, 8, 8, 0),
      child: Row(
        children: [
          if (onBack != null) IconBtn(Ic.back, label: backLabel ?? '', onTap: onBack),
          if (onBack != null) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(fontSize: Fs.title, height: 28 / 22, color: context.tok.text),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Fehlermeldung im Kasten (.msg).
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: tok.errC, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            AppIcon(Ic.alert, size: 22, color: tok.onErrC),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: tok.onErrC, fontSize: 14, height: 20 / 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Einstellungs-Zeile (.set-row): Titel (+ Untertitel) links, Bedienelement rechts.
class SetRow extends StatelessWidget {
  const SetRow({super.key, required this.title, this.subtitle, this.trailing, this.onTap, this.leading});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        spacing: 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16)],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, color: tok.text)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!, style: TextStyle(fontSize: 13, color: tok.sub)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return Pressable(
      onTap: onTap,
      pressScale: 0.97,
      radius: BorderRadius.zero,
      semanticLabel: subtitle == null ? title : '$title, $subtitle',
      excludeChildSemantics: true,
      child: row,
    );
  }
}

/// Farbpunkt (.cat-dot, .section-h i, .legend i).
class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 10});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Abhak-Kreis (.check) bzw. kleines Kästchen (.check.small).
class CheckMark extends StatelessWidget {
  const CheckMark({
    super.key,
    required this.on,
    required this.colors,
    required this.label,
    required this.onTap,
    this.small = false,
  });
  final bool on;
  final ItemColors colors;
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final s = small ? 16.0 : 22.0;
    final box = AnimatedContainer(
      duration: Motion.fast,
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: on ? colors.c : Colors.transparent,
        border: Border.all(color: on ? colors.c : tok.sub, width: small ? 1.5 : 2),
        borderRadius: BorderRadius.circular(small ? 4 : s / 2),
      ),
      alignment: Alignment.center,
      child: on ? AppIcon(Ic.check, size: small ? 11 : 14, stroke: 3, color: colors.cs) : null,
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      toggled: on,
      glow: false,
      pressScale: 0.85,
      excludeChildSemantics: true,
      child: SizedBox(
        width: small ? 36 : 44,
        height: small ? 32 : 44,
        child: Center(
          child: _PopIn(key: ValueKey(on), child: box),
        ),
      ),
    );
  }
}

/// Häkchen springt beim Umschalten kurz auf (Keyframes `pop-check`).
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: Motion.springBack,
      curve: Motion.check,
      builder: (context, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}

/// Weicher Farbverlauf links oben im Hintergrund (radial-gradient blob1). Den zweiten Fleck
/// rechts aus dem Prototyp gibt es bewusst nicht – er sah am Handy wie ein Displayfehler aus.
class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return DecoratedBox(
      decoration: BoxDecoration(color: tok.bg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1, -1),
            radius: 0.9,
            colors: [tok.blob1, tok.blob1.withValues(alpha: 0)],
            stops: const [0, 0.7],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Leerer Zustand (.empty).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});
  final Ic icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        children: [
          AppIcon(icon, size: 44, stroke: 1.5, color: tok.sub),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: tok.sub, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
