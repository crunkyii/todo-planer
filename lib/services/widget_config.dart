import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../theme/color_math.dart';
import '../util/dates.dart';

/// Welches Startbildschirm-Widget eingestellt wird.
enum WidgetKind {
  today,
  upcoming,
  habits,
  count;

  /// Was ein Listen-Widget zeigen kann (das Widget „Anzahl“ zeigt nur eine Zahl).
  static const lists = [today, upcoming, habits];
}

/// Wie weit das Widget „Demnächst“ in die Zukunft zeigt. Überfälliges steht immer drin.
enum WidgetRange {
  days3,
  week,
  weeks2,
  month,
  all;

  /// Letzter Tag, der noch gezeigt wird (null = alles). Gleiche Rechnung wie `WidgetData.rangeEnd`
  /// in Kotlin: ein Monat ist derselbe Tag im nächsten Monat (oder dessen letzter).
  DateTime? end(DateTime today) => switch (this) {
    days3 => addDays(today, 3),
    week => addDays(today, 7),
    weeks2 => addDays(today, 14),
    month => DateTime(today.year, today.month + 1, today.day.clamp(1, DateTime(today.year, today.month + 2, 0).day)),
    all => null,
  };
}

/// Form des Hintergrunds: rund wie die Samsung-/System-Widgets, leicht rund oder eckig.
enum WidgetShape {
  round(24),
  soft(10),
  square(0);

  const WidgetShape(this.radius);

  /// Eckenradius der Vorschau (am Handy nimmt „rund“ den Radius des Systems).
  final double radius;
}

/// Eine Kategorie, wie sie in der Zusammenfassung für die Widgets steht.
typedef WidgetCategory = ({String id, String name, String color});

/// Grundfarben der Widgets für die Vorschau im Einstellungsfenster – dieselben wie in
/// `android/app/src/main/res/values(-night)/widget_colors.xml` (dort zeichnet Android damit).
class WidgetPalette {
  const WidgetPalette({required this.bg, required this.text, required this.sub});
  final Color bg;
  final Color text;
  final Color sub;

  static const light = WidgetPalette(bg: Color(0xFFF7FAFD), text: Color(0xFF1A1F25), sub: Color(0xFF5B6672));
  static const dark = WidgetPalette(bg: Color(0xFF1B2026), text: Color(0xFFE8EDF2), sub: Color(0xFFA3AEBA));
  static WidgetPalette of({required bool dark}) => dark ? WidgetPalette.dark : WidgetPalette.light;
}

/// Einstellungen eines einzelnen Widgets (jedes Widget am Startbildschirm hat eigene).
class WidgetConfig {
  WidgetConfig({
    Set<String>? cats,
    this.background = true,
    this.shape = WidgetShape.round,
    this.mode = AppMode.system,
    this.transparency = 0,
    this.color,
    this.content,
    this.range = WidgetRange.all,
  }) : cats = cats ?? {};

  /// Was ein Listen-Widget zeigt (Heute, Demnächst oder Gewohnheiten); null = wie beim
  /// Hinzufügen gewählt. So kann jedes Listen-Widget später umgestellt werden.
  WidgetKind? content;

  /// Was das Widget der Art [kind] mit diesen Einstellungen tatsächlich zeigt.
  WidgetKind shows(WidgetKind kind) => kind == WidgetKind.count ? kind : content ?? kind;

  /// Zeitraum für „Demnächst“; neue Widgets zeigen alles (wie früher).
  WidgetRange range;

  /// Nur diese Kategorien zeigen; leer = alle.
  Set<String> cats;

  /// Hintergrund zeichnen? Ohne steht nur der Text auf dem Hintergrundbild.
  bool background;
  WidgetShape shape;

  /// Hell, dunkel oder wie das Telefon.
  AppMode mode;

  /// Durchsichtigkeit des Hintergrunds in Prozent (0 = deckend).
  int transparency;

  /// Eigene Farbe (#RRGGBB) oder null = Farbe des App-Designs.
  String? color;

  factory WidgetConfig.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    final color = j['color'];
    return WidgetConfig(
      cats: {
        if (j['cats'] case final List list)
          for (final c in list)
            if (c is String) c,
      },
      background: j['bg'] != false,
      shape: pick(WidgetShape.values, j['shape'], WidgetShape.round),
      mode: pick(AppMode.values, j['mode'], AppMode.system),
      transparency: (j['alpha'] is num ? (j['alpha'] as num).round() : 0).clamp(0, 100),
      color: color is String && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color) ? color : null,
      content: WidgetKind.lists.where((k) => k.name == j['content']).firstOrNull,
      range: pick(WidgetRange.values, j['range'], WidgetRange.all),
    );
  }

  /// Hintergrund und Akzent, wenn eine eigene Farbe gewählt ist (sonst null = Standard).
  /// Gleiche Rechnung wie für Kategorien und Blöcke in der App.
  ({Color bg, Color accent})? tint({required bool dark}) {
    final c = color;
    if (c == null) return null;
    final item = ItemColors.of(parseHex(c), dark: dark);
    return (bg: item.ct, accent: item.ci);
  }

  /// So liest es Android (`WidgetConfig.kt`). Die fertigen Farben stehen mit drin, damit
  /// dort nichts nachgerechnet werden muss.
  Map<String, Object?> toJson() {
    final l = tint(dark: false);
    final d = tint(dark: true);
    return {
      'cats': cats.toList(),
      'bg': background,
      'shape': shape.name,
      'mode': mode.name,
      'alpha': transparency,
      'color': color,
      'content': content?.name,
      'range': range.name,
      if (l != null && d != null) ...{
        'bgLight': toHex(l.bg),
        'accentLight': toHex(l.accent),
        'bgDark': toHex(d.bg),
        'accentDark': toHex(d.accent),
      },
    };
  }
}

/// Verbindung zum Android-Einstellungsfenster (`WidgetConfigActivity.kt`).
class WidgetConfigChannel {
  static const _channel = MethodChannel('todo_liste/widget_config');

  /// Welches Widget eingestellt wird und was bisher gespeichert ist.
  static Future<({WidgetKind kind, WidgetConfig config})> init() async {
    final m = await _channel.invokeMapMethod<String, Object?>('init') ?? const {};
    Map<String, dynamic> saved = const {};
    try {
      if (m['config'] case final String raw) {
        if (jsonDecode(raw) case final Map<String, dynamic> json) saved = json;
      }
    } on FormatException {
      // Kaputte Einstellungen: mit dem Standard anfangen.
    }
    return (
      kind: WidgetKind.values.firstWhere((k) => k.name == m['kind'], orElse: () => WidgetKind.today),
      config: WidgetConfig.fromJson(saved),
    );
  }

  static Future<void> save(WidgetConfig config) => _channel.invokeMethod<void>('save', jsonEncode(config.toJson()));
  static Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

/// Liest die Kategorien aus der gespeicherten Zusammenfassung (`HomeWidgets.prefsKey`).
List<WidgetCategory> widgetCategories(String? snapshotJson) {
  try {
    final snap = jsonDecode(snapshotJson ?? '{}');
    return [
      if (snap case {'cats': final List cats})
        for (final c in cats)
          if (c case {'id': final String id, 'n': final String name, 'c': final String color})
            (id: id, name: name, color: color),
    ];
  } on FormatException {
    return const [];
  }
}
