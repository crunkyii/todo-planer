import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/color_math.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import 'app_icon.dart';
import 'pressable.dart';
import 'ui.dart';

// ---------------------------------------------------------------------------
// Uhrzeit-Rad
// ---------------------------------------------------------------------------

/// Schnellwahl über dem Rad: Wert in Minuten (oder `null` = ohne Uhrzeit) + Text.
typedef QuickTime = ({int? minutes, String label});

/// Zwei Räder (Stunde : Minute), drehen mit Schwung und rasten ein (.wheels).
/// [step] = Minutenschritt (5 für Aufgaben, das Raster für Blöcke).
class TimeWheel extends StatefulWidget {
  const TimeWheel({
    super.key,
    required this.value,
    required this.step,
    required this.onChanged,
    this.quick = const [],
    this.onQuick,
    this.isSelected,
  });

  /// Aktuelle Zeit in Minuten; `null` = keine Uhrzeit (Rad zeigt 08:00).
  final int? value;
  final int step;
  final ValueChanged<int> onChanged;
  final List<QuickTime> quick;
  final ValueChanged<QuickTime>? onQuick;

  /// Wann ein Schnellwahl-Chip markiert ist (Standard: gleiche Uhrzeit).
  final bool Function(QuickTime)? isSelected;

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late FixedExtentScrollController _h;
  late FixedExtentScrollController _m;
  bool _lock = false;

  int get _mCount => 60 ~/ widget.step;
  int _hIdx(int v) => v ~/ 60;
  int _mIdx(int v) => ((v % 60) / widget.step).round() % _mCount;

  @override
  void initState() {
    super.initState();
    final v = widget.value ?? 8 * 60;
    _h = FixedExtentScrollController(initialItem: _hIdx(v));
    _m = FixedExtentScrollController(initialItem: _mIdx(v));
  }

  @override
  void didUpdateWidget(TimeWheel old) {
    super.didUpdateWidget(old);
    final v = widget.value;
    if (v == null || v == _current) return;
    // Wert kam von außen (Schnellwahl, „Bis“ rutscht mit): Räder sanft nachdrehen
    _lock = true;
    final d = Motion.of(context, const Duration(milliseconds: 400));
    Future.wait([
      if (_h.hasClients)
        _h.animateToItem(_hIdx(v), duration: d + const Duration(milliseconds: 1), curve: Curves.easeOutCubic),
      if (_m.hasClients)
        _m.animateToItem(_mIdx(v), duration: d + const Duration(milliseconds: 1), curve: Curves.easeOutCubic),
    ]).whenComplete(() => _lock = false);
  }

  @override
  void dispose() {
    _h.dispose();
    _m.dispose();
    super.dispose();
  }

  int get _current {
    final h = _h.hasClients ? _h.selectedItem.clamp(0, 23) : 8;
    final m = _m.hasClients ? (_m.selectedItem % _mCount) * widget.step : 0;
    return h * 60 + m;
  }

  void _commit() {
    if (_lock) return;
    final v = _current;
    if (v != widget.value) {
      buzz();
      widget.onChanged(v);
    }
  }

  Widget _col(FixedExtentScrollController c, int count, int mult, String label) {
    final tok = context.tok;
    return Focus(
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
        final dir = e.logicalKey == LogicalKeyboardKey.arrowDown
            ? 1
            : e.logicalKey == LogicalKeyboardKey.arrowUp
            ? -1
            : 0;
        if (dir == 0) return KeyEventResult.ignored;
        c.animateToItem(
          (c.selectedItem + dir).clamp(0, count - 1),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
        return KeyEventResult.handled;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Semantics(
            label: label,
            value: pad2(c.hasClients ? c.selectedItem * mult : 0),
            child: Container(
              width: 72,
              height: Sizes.wheelH,
              decoration: focused
                  ? BoxDecoration(
                      border: Border.all(color: tok.p, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                  stops: [0, 0.3, 0.7, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: (_) {
                    Future.delayed(const Duration(milliseconds: 90), () {
                      if (mounted) _commit();
                    });
                    return false;
                  },
                  child: ListWheelScrollView.useDelegate(
                    controller: c,
                    itemExtent: Sizes.wheelItem,
                    diameterRatio: 1000,
                    physics: const FixedExtentScrollPhysics(),
                    overAndUnderCenterOpacity: 1,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: count,
                      builder: (context, i) => Center(
                        child: Text(
                          pad2(i * mult),
                          style: TextStyle(
                            fontSize: Fs.wheel,
                            color: tok.text,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.quick.isNotEmpty)
          QuickRow(
            label: l.quickTime,
            children: [
              for (final q in widget.quick)
                AppChip(
                  label: q.label,
                  selected: widget.isSelected?.call(q) ?? (widget.value == q.minutes && q.minutes != null),
                  height: 32,
                  padding: 12,
                  fontSize: 13,
                  onTap: () => widget.onQuick?.call(q),
                ),
            ],
          ),
        SizedBox(
          height: Sizes.wheelH,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 16,
                right: 16,
                top: 80,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: tok.pc, borderRadius: BorderRadius.circular(12)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _col(_h, 24, 1, l.hour),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Text(
                      ':',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: tok.onPc),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _col(_m, _mCount, widget.step, l.minute),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontale Reihe kleiner Chips (.quick).
class QuickRow extends StatelessWidget {
  const QuickRow({super.key, required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 6), children[i]],
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Monats-Raster (Kalender-Tab und Mini-Kalender)
// ---------------------------------------------------------------------------

/// 7 Spalten, Montag zuerst; die 6. Zeile nur, wenn sie noch Tage des Monats enthält.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.cell,
    this.wdFontSize = 12,
    this.wdPadding = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });
  final DateTime month;
  final Widget Function(DateTime day, bool otherMonth) cell;
  final double wdFontSize;
  final double wdPadding;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final f = Fmt.of(context);
    final tok = context.tok;
    final first = monday(DateTime(month.year, month.month));
    final days = <DateTime>[];
    for (var i = 0; i < 42; i++) {
      final d = addDays(first, i);
      if (i == 35 && d.month != month.month) break;
      days.add(d);
    }
    return Padding(
      padding: padding,
      child: Column(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: wdPadding),
                      child: Text(
                        f.wd(i),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: wdFontSize, color: tok.sub),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var r = 0; r < days.length; r += 7)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [for (final d in days.sublist(r, r + 7)) Expanded(child: cell(d, d.month != month.month))],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ein Tag im Raster (.cal-day): Zahl im Kreis, heute umrandet, gewählt gefüllt.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.other,
    required this.selected,
    required this.onTap,
    this.height = 48,
    this.circle = 34,
    this.below,
    this.semanticLabel,
  });
  final DateTime day;
  final bool other;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double circle;
  final Widget? below;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final isToday = sameDay(day, DateTime.now());
    final numColor = selected ? tok.onP : (isToday ? tok.p : tok.text);
    final cellBody = SizedBox(
      height: height,
      child: Opacity(
        opacity: other ? 0.5 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.fast,
              width: circle,
              height: circle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? tok.p : Colors.transparent,
                border: isToday || selected ? Border.all(color: tok.p, width: 1.5) : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  color: other && !selected ? tok.sub : numColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (below != null) ...[const SizedBox(height: 3), below!],
          ],
        ),
      ),
    );
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      radius: BorderRadius.circular(Sizes.rCalDay),
      child: cellBody,
    );
  }
}

/// Mini-Kalender im Aufgaben-Sheet mit Schnellwahl Heute / Morgen / In 1 Woche.
class MiniCalendar extends StatefulWidget {
  const MiniCalendar({super.key, required this.selected, required this.onPick});
  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  @override
  void didUpdateWidget(MiniCalendar old) {
    super.didUpdateWidget(old);
    if (!sameDay(old.selected, widget.selected)) _month = DateTime(widget.selected.year, widget.selected.month);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = Fmt.of(context);
    final tok = context.tok;
    final t = today();
    final quick = [(t, l.today), (addDays(t, 1), l.tomorrow), (addDays(t, 7), l.inOneWeek)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuickRow(
          label: l.quickDate,
          children: [
            for (final q in quick)
              AppChip(
                label: q.$2,
                selected: sameDay(q.$1, widget.selected),
                height: 32,
                padding: 12,
                fontSize: 13,
                onTap: () => _pick(q.$1),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  f.monthYear(_month),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tok.text),
                ),
              ),
              IconBtn(
                Ic.left,
                size: 20,
                label: l.prevMonth,
                onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              IconBtn(
                Ic.right,
                size: 20,
                label: l.nextMonth,
                onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
        ),
        MonthGrid(
          month: _month,
          padding: EdgeInsets.zero,
          wdFontSize: 11,
          wdPadding: 2,
          cell: (d, other) => DayCell(
            day: d,
            other: other,
            selected: sameDay(d, widget.selected),
            height: 38,
            circle: 32,
            semanticLabel: f.longDate(d),
            onTap: () => _pick(d),
          ),
        ),
      ],
    );
  }

  void _pick(DateTime d) {
    buzz();
    setState(() => _month = DateTime(d.year, d.month));
    widget.onPick(d);
  }
}

// ---------------------------------------------------------------------------
// Farbauswahl: 5 Vorgaben + Farbrad
// ---------------------------------------------------------------------------

String presetName(AppLocalizations l, ColorPreset p) => switch (p) {
  ColorPreset.skyBlue => l.colorSkyBlue,
  ColorPreset.mintGreen => l.colorMintGreen,
  ColorPreset.sunYellow => l.colorSunYellow,
  ColorPreset.coral => l.colorCoral,
  ColorPreset.lavender => l.colorLavender,
};

class ColorChoice extends StatelessWidget {
  const ColorChoice({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = AppLocalizations.of(context);
    final isPreset = ColorPreset.values.any((p) => p.hex.toLowerCase() == value.toLowerCase());
    BoxDecoration ring(bool on, {Color? color, Gradient? gradient}) => BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      gradient: gradient,
      boxShadow: on ? [BoxShadow(color: tok.surf, spreadRadius: 2), BoxShadow(color: tok.text, spreadRadius: 4)] : null,
    );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in ColorPreset.values)
          Pressable(
            onTap: () => onChanged(p.hex),
            semanticLabel: presetName(l, p),
            selected: p.hex.toLowerCase() == value.toLowerCase(),
            glow: false,
            child: Container(
              width: 38,
              height: 38,
              decoration: ring(p.hex.toLowerCase() == value.toLowerCase(), color: parseHex(p.hex)),
            ),
          ),
        Pressable(
          onTap: () async {
            final c = await showColorDialog(context, value);
            if (c != null) onChanged(c);
          },
          semanticLabel: l.chooseCustomColor,
          selected: !isPreset,
          tooltip: l.customColor,
          glow: false,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: ring(
              !isPreset,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFFF3B30),
                  Color(0xFFFF9500),
                  Color(0xFFFFCC00),
                  Color(0xFF34C759),
                  Color(0xFF00C7BE),
                  Color(0xFF007AFF),
                  Color(0xFF5856D6),
                  Color(0xFFAF52DE),
                  Color(0xFFFF2D55),
                  Color(0xFFFF3B30),
                ],
              ),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPreset ? tok.surf : parseHex(value),
                border: Border.all(color: tok.surf, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Eigene Farbe wählen: Farbton, Sättigung, Helligkeit (ersetzt das Browser-Farbfeld).
Future<String?> showColorDialog(BuildContext context, String initial) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ColorDialog(initial: initial),
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial});
  final String initial;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor _c = HSVColor.fromColor(parseHex(widget.initial));

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = AppLocalizations.of(context);
    Widget slider(String label, double value, double max, ValueChanged<double> on, List<Color> colors) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: tok.sub),
        ),
        Container(
          height: 14,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: LinearGradient(colors: colors),
          ),
        ),
        Slider(value: value, max: max, label: label, onChanged: (v) => setState(() => on(v))),
      ],
    );
    final hues = [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()];
    return AlertDialog(
      backgroundColor: tok.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sizes.rSheet)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _c.toColor()),
          ),
          const SizedBox(width: 12),
          Text(l.customColor, style: TextStyle(fontSize: 20, color: tok.text)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            slider(l.hue, _c.hue, 360, (v) => _c = _c.withHue(v), hues),
            slider(l.saturation, _c.saturation, 1, (v) => _c = _c.withSaturation(v), [
              _c.withSaturation(0).toColor(),
              _c.withSaturation(1).toColor(),
            ]),
            slider(l.brightness, _c.value, 1, (v) => _c = _c.withValue(v), [black, _c.withValue(1).toColor()]),
          ],
        ),
      ),
      actions: [
        AppButton(label: l.cancel, kind: BtnKind.text, onTap: () => Navigator.pop(context)),
        AppButton(label: l.apply, onTap: () => Navigator.pop(context, toHex(_c.toColor()))),
      ],
    );
  }
}
