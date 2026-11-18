import 'dart:math' as math;
import 'dart:ui' show Color;

/// Farb-Rechnungen aus dem Prototyp (mix, lum, contrast, ensure).
/// Damit werden alle Theme-Farben aus einer einzigen Designfarbe abgeleitet.

const Color black = Color(0xFF000000);
const Color white = Color(0xFFFFFFFF);

/// Liest `#RRGGBB` (mit oder ohne #). Ungültige Werte ergeben [fallback].
Color parseHex(String hex, {Color fallback = const Color(0xFF3D9BE9)}) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (h.length != 6) return fallback;
  final n = int.tryParse(h, radix: 16);
  return n == null ? fallback : Color(0xFF000000 | n);
}

/// `#RRGGBB` in Großbuchstaben.
String toHex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int _ch(double v) => (v * 255).round().clamp(0, 255);

/// Mischt [a] und [b]: t = 0 → a, t = 1 → b (wie `mix()` im Prototyp).
Color mix(Color a, Color b, double t) {
  int m(double x, double y) => (_ch(x) + (_ch(y) - _ch(x)) * t).round();
  return Color.fromARGB(255, m(a.r, b.r), m(a.g, b.g), m(a.b, b.b));
}

/// Relative Leuchtdichte nach WCAG.
double luminance(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = _ch(c.r) / 255, g = _ch(c.g) / 255, b = _ch(c.b) / 255;
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}

double contrast(Color a, Color b) {
  final x = luminance(a), y = luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Verschiebt [fg] Richtung Schwarz/Weiß, bis der Kontrast zu [bg] reicht.
Color ensure(Color fg, Color bg, double ratio) {
  final target = luminance(bg) > 0.4 ? black : white;
  var c = fg;
  for (var t = 0.0; t <= 1 && contrast(c, bg) < ratio; t += 0.05) {
    c = mix(fg, target, t);
  }
  return c;
}

/// Farbe mit Deckkraft (wie `alpha()` im Prototyp).
Color alpha(Color c, double a) => c.withValues(alpha: a);

/// Hintergrund im Dunkelmodus.
const Color darkBase = Color(0xFF15181C);

/// Die vier abgeleiteten Farben einer Kategorie/Gewohnheit/eines Blocks:
/// c = Farbe, ct = Tönung (Hintergrund), ci = Schrift auf Tönung, cs = Schrift auf Farbe.
class ItemColors {
  const ItemColors(this.c, this.ct, this.ci, this.cs);

  factory ItemColors.of(Color hex, {required bool dark}) {
    final cs = luminance(hex) > 0.4 ? const Color(0xFF14161A) : white;
    if (dark) {
      final tint = mix(hex, darkBase, 0.62);
      return ItemColors(hex, tint, ensure(mix(hex, white, 0.7), tint, 7), cs);
    }
    final tint = mix(hex, white, 0.8);
    return ItemColors(hex, tint, ensure(mix(hex, black, 0.55), tint, 6), cs);
  }

  final Color c;
  final Color ct;
  final Color ci;
  final Color cs;
}
