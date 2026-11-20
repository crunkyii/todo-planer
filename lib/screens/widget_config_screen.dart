import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/settings_store.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/widget_config.dart';
import '../theme/app_theme.dart';
import '../theme/color_math.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../widgets/pickers.dart';
import '../widgets/select.dart';
import '../widgets/ui.dart';

/// Kleine eigene App für das Einstellungsfenster eines Startbildschirm-Widgets.
///
/// Android öffnet sie, wenn man ein Widget gedrückt hält und „Einstellungen“ wählt
/// (`WidgetConfigActivity.kt`, Einstieg `widgetConfigMain` in `main.dart`). Sie braucht
/// weder Datenbank noch Anmeldung – nur Sprache, Design und die Kategorien.
class WidgetConfigApp extends StatelessWidget {
  const WidgetConfigApp({
    super.key,
    required this.lang,
    required this.themeId,
    required this.mode,
    required this.kind,
    required this.initial,
    required this.categories,
    required this.onSave,
    required this.onCancel,
  });

  final String lang;
  final String themeId;
  final AppMode mode;
  final WidgetKind kind;
  final WidgetConfig initial;
  final List<WidgetCategory> categories;
  final ValueChanged<WidgetConfig> onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).widgetSettings,
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      theme: buildAppTheme(themeId, dark: false),
      darkTheme: buildAppTheme(themeId, dark: true),
      themeMode: themeModeOf(mode),
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: maxTextScale, child: child!),
      home: WidgetConfigScreen(
        themeId: themeId,
        kind: kind,
        initial: initial,
        categories: categories,
        onSave: onSave,
        onCancel: onCancel,
      ),
    );
  }
}

class WidgetConfigScreen extends StatefulWidget {
  const WidgetConfigScreen({
    super.key,
    required this.themeId,
    required this.kind,
    required this.initial,
    required this.categories,
    required this.onSave,
    required this.onCancel,
  });

  final String themeId;
  final WidgetKind kind;
  final WidgetConfig initial;
  final List<WidgetCategory> categories;
  final ValueChanged<WidgetConfig> onSave;
  final VoidCallback onCancel;

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  late final WidgetConfig _cfg = widget.initial;

  @override
  void initState() {
    super.initState();
    // Inzwischen gelöschte Kategorien nicht weiter mitschleppen.
    _cfg.cats.removeWhere((id) => !widget.categories.any((c) => c.id == id));
  }

  void _set(VoidCallback change) => setState(change);

  void _toggleCat(String id) => _set(() {
    if (!_cfg.cats.remove(id)) _cfg.cats.add(id);
    // Alle einzeln angewählt ist dasselbe wie „Alle“.
    if (_cfg.cats.length == widget.categories.length) _cfg.cats.clear();
  });

  /// Chip nur so breit wie sein Text (sonst füllt er die ganze Zeile).
  Widget _chip(AppChip chip) => IntrinsicWidth(child: chip);

  /// Was das Widget mit den gewählten Einstellungen zeigt.
  WidgetKind get _shows => _cfg.shows(widget.kind);

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final withCats = _shows != WidgetKind.habits && widget.categories.isNotEmpty;
    return Scaffold(
      backgroundColor: tok.bg,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: l.widgetSettings, onBack: widget.onCancel, backLabel: l.cancel),
            // Die Vorschau bleibt oben stehen, damit man jede Änderung sofort sieht.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: WidgetPreview(config: _cfg, kind: _shows, themeId: widget.themeId, categories: widget.categories),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (widget.kind != WidgetKind.count)
                    SelectRow<WidgetKind>(
                      title: l.widgetContent,
                      options: [
                        (WidgetKind.today, l.today),
                        (WidgetKind.upcoming, l.widgetUpcoming),
                        (WidgetKind.habits, l.habits),
                      ],
                      value: _shows,
                      onChanged: (v) => _set(() => _cfg.content = v),
                    ),
                  if (withCats) ...[
                    CapsHeading(l.categories),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(AppChip(label: l.all, selected: _cfg.cats.isEmpty, onTap: () => _set(_cfg.cats.clear))),
                          for (final c in widget.categories)
                            _chip(
                              AppChip(
                                label: c.name,
                                selected: _cfg.cats.contains(c.id),
                                colors: tok.item(c.color),
                                onTap: () => _toggleCat(c.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  CapsHeading(l.widgetBackground),
                  SetRow(
                    title: l.widgetShowBackground,
                    inline: true,
                    trailing: AppSwitch(
                      value: _cfg.background,
                      label: l.widgetShowBackground,
                      onChanged: (v) => _set(() => _cfg.background = v),
                    ),
                  ),
                  SelectRow<AppMode>(
                    title: l.widgetBgColor,
                    options: [(AppMode.light, l.light), (AppMode.dark, l.dark), (AppMode.system, l.system)],
                    value: _cfg.mode,
                    onChanged: (v) => _set(() => _cfg.mode = v),
                  ),
                  if (_cfg.background) ...[
                    SelectRow<WidgetShape>(
                      title: l.widgetShape,
                      options: [
                        (WidgetShape.round, l.widgetShapeRound),
                        (WidgetShape.soft, l.widgetShapeSoft),
                        (WidgetShape.square, l.widgetShapeSquare),
                      ],
                      value: _cfg.shape,
                      onChanged: (v) => _set(() => _cfg.shape = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        l.widgetTransparency(_cfg.transparency),
                        style: TextStyle(fontSize: Fs.base, color: tok.text),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Slider(
                        value: _cfg.transparency.toDouble(),
                        max: 100,
                        divisions: 20,
                        label: l.widgetTransparency(_cfg.transparency),
                        onChanged: (v) => _set(() => _cfg.transparency = v.round()),
                      ),
                    ),
                  ],
                  CapsHeading(l.color),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _chip(
                          AppChip(
                            label: l.widgetColorApp,
                            selected: _cfg.color == null,
                            onTap: () => _set(() => _cfg.color = null),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ColorChoice(value: _cfg.color, onChanged: (c) => _set(() => _cfg.color = c)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      l.widgetHint,
                      style: TextStyle(fontSize: Fs.small, color: tok.sub),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(label: l.cancel, kind: BtnKind.text, onTap: widget.onCancel),
                  const SizedBox(width: 8),
                  AppButton(label: l.save, onTap: () => widget.onSave(_cfg)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vorschau: so sieht das Widget mit den gewählten Einstellungen ungefähr aus.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.config,
    required this.kind,
    required this.themeId,
    required this.categories,
  });

  final WidgetConfig config;
  final WidgetKind kind;
  final String themeId;
  final List<WidgetCategory> categories;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    final l = context.l;
    final f = Fmt.of(context);
    final dark = switch (config.mode) {
      AppMode.light => false,
      AppMode.dark => true,
      AppMode.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final pal = WidgetPalette.of(dark: dark);
    final tint = config.tint(dark: dark);
    final accent = tint?.accent ?? AppTokens.build(themeOf(themeId), dark: dark).p;
    final bg = (tint?.bg ?? pal.bg).withValues(alpha: 1 - config.transparency / 100);
    final shown = [
      for (final c in categories)
        if (config.cats.isEmpty || config.cats.contains(c.id)) c,
    ];
    final base = switch (kind) {
      WidgetKind.upcoming => l.widgetUpcoming,
      WidgetKind.habits => l.habits,
      _ => l.today,
    };
    // Wie am Handy: die gewählten Kategorien stehen hinter dem Titel („Heute · Test, Termin“).
    final title = config.cats.isEmpty || kind == WidgetKind.habits || kind == WidgetKind.count
        ? base
        : '$base · ${shown.map((c) => c.name).join(', ')}';

    Widget row(String text, String sub, Color bar) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: pal.text),
                ),
                Text(sub, maxLines: 1, style: TextStyle(fontSize: 12, color: pal.sub)),
              ],
            ),
          ),
        ],
      ),
    );

    // Zweite Zeile wie am Handy: heute Fälliges nur mit Uhrzeit, sonst der Tag – immer mit „bis:“.
    String due(int i) => l.widgetUntil(i == 0 ? f.time(14 * 60) : l.tomorrow);
    String sub(int i) => kind == WidgetKind.habits ? (i == 0 ? l.today : l.tomorrow) : due(i);

    final Widget content;
    if (kind == WidgetKind.count) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '3',
            style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.bold, color: accent),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: pal.text)),
        ],
      );
    } else {
      final samples = kind == WidgetKind.habits ? const <WidgetCategory>[] : shown.take(2).toList();
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // Wie am Handy: im Widget „Heute“ steht das Datum kleiner neben dem Titel.
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: base),
                      if (kind == WidgetKind.today)
                        TextSpan(
                          text: ' ${f.widgetDate(today())}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                        ),
                      TextSpan(text: title.substring(base.length)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pal.text),
                ),
              ),
              Text(
                kind == WidgetKind.habits ? '1/2' : '${samples.isEmpty ? 2 : samples.length}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent),
              ),
            ],
          ),
          if (samples.isEmpty) ...[
            row(title, sub(0), accent),
            row(title, sub(1), accent),
          ] else
            for (final (i, c) in samples.indexed) row(c.name, due(i), parseHex(c.color)),
        ],
      );
    }

    return Semantics(
      label: l.widgetPreview,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('widget-preview-wallpaper'),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          alignment: Alignment.center,
          // „Hintergrundbild“, damit man Transparenz und Form erkennt.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Sizes.rCardLarge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tok.p, tok.item(ColorPreset.lavender.hex).c, tok.item(ColorPreset.coral.hex).c],
            ),
          ),
          child: AnimatedContainer(
            key: const ValueKey('widget-preview'),
            duration: Motion.of(context, Motion.fast),
            width: kind == WidgetKind.count ? 96 : 240,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: config.background ? bg : bg.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(config.shape.radius),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
