import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/screens/widget_config_screen.dart';
import 'package:todo_liste/services/home_widgets.dart';
import 'package:todo_liste/services/widget_config.dart';
import 'package:todo_liste/theme/color_math.dart';
import 'package:todo_liste/theme/tokens.dart';
import 'package:todo_liste/widgets/pickers.dart';
import 'package:todo_liste/widgets/ui.dart';

import 'harness.dart';

/// Einstellungen der Startbildschirm-Widgets: Kategorien, Hintergrund, Form, hell/dunkel,
/// Transparenz, Farbe.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  const cats = <WidgetCategory>[
    (id: 'hu', name: 'Hausübung', color: '#3D9BE9'),
    (id: 'test', name: 'Test', color: '#F0745A'),
    (id: 'termin', name: 'Termin', color: '#9B7FE6'),
  ];

  Future<({List<WidgetConfig> saved, List<int> cancelled})> open(
    WidgetTester tester, {
    WidgetKind kind = WidgetKind.today,
    WidgetConfig? initial,
    String lang = 'de',
    AppMode mode = AppMode.light,
    Size size = const Size(412, 915),
    List<WidgetCategory> categories = cats,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <WidgetConfig>[];
    final cancelled = <int>[];
    await tester.pumpWidget(
      WidgetConfigApp(
        lang: lang,
        themeId: 'himmel',
        mode: mode,
        kind: kind,
        initial: initial ?? WidgetConfig(),
        categories: categories,
        onSave: saved.add,
        onCancel: () => cancelled.add(1),
      ),
    );
    await tester.pumpAndSettle();
    return (saved: saved, cancelled: cancelled);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  BoxDecoration preview(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.byKey(const ValueKey('widget-preview'))).decoration! as BoxDecoration;

  group('Einstellungen speichern und lesen', () {
    test('Standard: alle Kategorien, Hintergrund an, rund, wie das Telefon, deckend, App-Farbe', () {
      final c = WidgetConfig.fromJson(const {});
      expect(c.cats, isEmpty);
      expect(c.background, isTrue);
      expect(c.shape, WidgetShape.round);
      expect(c.mode, AppMode.system);
      expect(c.transparency, 0);
      expect(c.color, isNull);
      expect(c.toJson().containsKey('bgLight'), isFalse, reason: 'ohne eigene Farbe rechnet Android selbst');
    });

    test('hin und zurück bleibt alles gleich; mit Farbe stehen die fertigen Farben dabei', () {
      final c = WidgetConfig(
        cats: {'hu', 'test'},
        background: false,
        shape: WidgetShape.square,
        mode: AppMode.dark,
        transparency: 35,
        color: '#F0745A',
      );
      final json = jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>;
      final back = WidgetConfig.fromJson(json);
      expect(back.cats, {'hu', 'test'});
      expect(back.background, isFalse);
      expect(back.shape, WidgetShape.square);
      expect(back.mode, AppMode.dark);
      expect(back.transparency, 35);
      expect(back.color, '#F0745A');
      for (final key in ['bgLight', 'bgDark', 'accentLight', 'accentDark']) {
        expect(json[key], matches(RegExp(r'^#[0-9A-Fa-f]{6}$')), reason: key);
      }
      expect(json['bgLight'], isNot(json['bgDark']));
      // Der Akzent muss auf dem getönten Hintergrund gut lesbar sein.
      for (final dark in [false, true]) {
        final t = c.tint(dark: dark)!;
        expect(contrast(t.accent, t.bg), greaterThanOrEqualTo(4.5), reason: 'dunkel: $dark');
      }
    });

    test('kaputte Werte fallen auf den Standard zurück', () {
      final c = WidgetConfig.fromJson(const {
        'cats': ['a', 5, null],
        'bg': 'nein',
        'shape': 'stern',
        'mode': 7,
        'alpha': 400,
        'color': 'rot',
      });
      expect(c.cats, {'a'});
      expect(c.background, isTrue);
      expect(c.shape, WidgetShape.round);
      expect(c.mode, AppMode.system);
      expect(c.transparency, 100);
      expect(c.color, isNull);
      expect(WidgetConfig.fromJson(const {'alpha': -3}).transparency, 0);
    });

    test('Kategorien kommen aus der Zusammenfassung der App', () {
      expect(widgetCategories(null), isEmpty);
      expect(widgetCategories('kein json'), isEmpty);
      expect(widgetCategories('{"cats":"x"}'), isEmpty);
      final got = widgetCategories(
        '{"cats":[{"id":"a","n":"Test","c":"#112233"},{"id":7},{"id":"b","n":"Termin","c":"#445566"}]}',
      );
      expect(got.map((c) => c.name), ['Test', 'Termin']);
    });

    testWidgets('die App schreibt Kategorien und die Kategorie jeder Aufgabe mit', (tester) async {
      useFixedClock();
      final l = l10n('de');
      final app = await makeServices();
      seedDemo(app.store, l);
      final snap = jsonDecode(jsonEncode(buildWidgetSnapshot(app.store, l, themeId: 'himmel'))) as Map<String, dynamic>;
      final got = widgetCategories(jsonEncode(snap));
      expect(got.map((c) => c.name), app.store.categories.map((c) => c.name));
      final ids = got.map((c) => c.id).toSet();
      for (final t in (snap['tasks'] as List).cast<Map<String, dynamic>>()) {
        expect(ids, contains(t['k']), reason: '${t['t']}');
      }
      await finishApp(tester, app);
    });

    testWidgets('Fenster fragt Android nach Art und Stand und meldet das Ergebnis', (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('todo_liste/widget_config');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'init' ? {'kind': 'count', 'config': '{"shape":"soft","cats":["hu"]}'} : null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      final start = await WidgetConfigChannel.init();
      expect(start.kind, WidgetKind.count);
      expect(start.config.shape, WidgetShape.soft);
      expect(start.config.cats, {'hu'});
      await WidgetConfigChannel.save(start.config..transparency = 20);
      expect(calls.last.method, 'save');
      expect((jsonDecode(calls.last.arguments as String) as Map)['alpha'], 20);
      await WidgetConfigChannel.cancel();
      expect(calls.last.method, 'cancel');

      // Noch nie eingestellt oder kaputt gespeichert: Standard
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => {'kind': 'unbekannt', 'config': '{kaputt'},
      );
      final fresh = await WidgetConfigChannel.init();
      expect(fresh.kind, WidgetKind.today);
      expect(fresh.config.shape, WidgetShape.round);
    });
  });

  group('Einstellungsfenster', () {
    testWidgets('Kategorien an- und wieder abwählen', (tester) async {
      final l = l10n('de');
      final r = await open(tester);
      bool on(String label) => tester.widget<AppChip>(find.widgetWithText(AppChip, label)).selected;
      expect(on(l.all), isTrue);
      await tap(tester, find.widgetWithText(AppChip, 'Hausübung'));
      await tap(tester, find.widgetWithText(AppChip, 'Test'));
      expect(on(l.all), isFalse);
      expect(on('Hausübung') && on('Test') && !on('Termin'), isTrue);
      await tap(tester, find.widgetWithText(AppChip, 'Hausübung')); // wieder abwählen
      expect(on('Hausübung'), isFalse);
      await tap(tester, find.text(l.save));
      expect(r.saved.single.cats, {'test'});

      // Alles abgewählt = alle; alle einzeln angewählt = alle
      await tap(tester, find.widgetWithText(AppChip, 'Test'));
      expect(on(l.all), isTrue);
      for (final c in cats) {
        await tap(tester, find.widgetWithText(AppChip, c.name));
      }
      expect(on(l.all), isTrue);
      expect(on('Termin'), isFalse);
      await tap(tester, find.widgetWithText(AppChip, 'Termin'));
      await tap(tester, find.widgetWithText(AppChip, l.all));
      await tap(tester, find.text(l.save));
      expect(r.saved.last.cats, isEmpty);
    });

    testWidgets('gelöschte Kategorien werden nicht weiter mitgespeichert', (tester) async {
      final r = await open(tester, initial: WidgetConfig(cats: {'termin', 'gibt-es-nicht-mehr'}));
      await tap(tester, find.text(l10n('de').save));
      expect(r.saved.single.cats, {'termin'});
    });

    testWidgets('Hintergrund, Form, hell/dunkel, Transparenz und Farbe – die Vorschau zeigt es sofort', (tester) async {
      final l = l10n('de');
      final r = await open(tester);
      expect(preview(tester).color, WidgetPalette.light.bg);
      expect(preview(tester).borderRadius, BorderRadius.circular(WidgetShape.round.radius));

      await tap(tester, find.text(l.dark));
      expect(preview(tester).color, WidgetPalette.dark.bg);
      await tap(tester, find.text(l.widgetShapeSquare));
      expect(preview(tester).borderRadius, BorderRadius.circular(0));
      await tap(tester, find.text(l.widgetShapeSoft));
      expect(preview(tester).borderRadius, BorderRadius.circular(WidgetShape.soft.radius));

      // Transparenz: Regler ganz nach rechts
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text(l.widgetTransparency(100)), findsOneWidget);
      expect(preview(tester).color!.a, 0);
      await tester.tapAt(tester.getCenter(slider));
      await tester.pumpAndSettle();
      expect(find.text(l.widgetTransparency(50)), findsOneWidget);
      expect(preview(tester).color!.a, closeTo(0.5, 0.01));

      // Farbe wählen und wieder zurück auf „Wie App-Design“
      await tap(tester, find.bySemanticsLabel(presetName(l, ColorPreset.coral)));
      final coral = WidgetConfig(color: ColorPreset.coral.hex).tint(dark: true)!.bg;
      expect(preview(tester).color!.withValues(alpha: 1), coral);
      expect(tester.widget<AppChip>(find.widgetWithText(AppChip, l.widgetColorApp)).selected, isFalse);
      await tap(tester, find.text(l.save));
      final c = r.saved.single;
      expect(c.mode, AppMode.dark);
      expect(c.shape, WidgetShape.soft);
      expect(c.transparency, 50);
      expect(c.color!.toLowerCase(), ColorPreset.coral.hex.toLowerCase());
      await tap(tester, find.widgetWithText(AppChip, l.widgetColorApp));
      await tap(tester, find.text(l.save));
      expect(r.saved.last.color, isNull);

      // Hintergrund aus: Form und Transparenz verschwinden, die Vorschau ist durchsichtig
      await tap(tester, find.byType(AppSwitch));
      expect(find.byType(Slider), findsNothing);
      expect(find.text(l.widgetShapeSquare), findsNothing);
      expect(preview(tester).color!.a, 0);
      await tap(tester, find.text(l.save));
      expect(r.saved.last.background, isFalse);
      expect(r.saved.last.mode, AppMode.dark, reason: 'hell/dunkel bleibt für die Schriftfarbe');
    });

    testWidgets('Bild der Einstellungsseite', (tester) async {
      await open(
        tester,
        initial: WidgetConfig(cats: {'hu', 'test'}, transparency: 30, color: ColorPreset.lavender.hex),
      );
      await expectLater(
        find.byType(WidgetConfigApp),
        matchesGoldenFile('goldens/widget-einstellungen_412_light_de.png'),
      );
    });

    testWidgets('„System“ folgt dem Telefon', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await open(tester, mode: AppMode.system);
      expect(preview(tester).color, WidgetPalette.dark.bg);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(preview(tester).color, WidgetPalette.light.bg);
    });

    testWidgets('Gewohnheiten-Widget hat keine Kategorien; Abbrechen speichert nichts', (tester) async {
      final l = l10n('de');
      final r = await open(tester, kind: WidgetKind.habits);
      expect(find.widgetWithText(AppChip, 'Hausübung'), findsNothing);
      expect(find.text(l.widgetShowBackground), findsOneWidget);
      await tap(tester, find.text(l.cancel));
      expect(r.saved, isEmpty);
      expect(r.cancelled, hasLength(1));
      await tap(tester, find.bySemanticsLabel(l.cancel).first); // Pfeil oben
      expect(r.cancelled, hasLength(2));
    });

    testWidgets('passt auf kleine Bildschirme, Englisch, dunkel, große Schrift und alle Widget-Arten', (tester) async {
      for (final kind in WidgetKind.values) {
        for (final (lang, mode, size, scale) in [
          ('de', AppMode.light, const Size(320, 568), 1.0),
          ('en', AppMode.dark, const Size(412, 915), 2.0),
          ('de', AppMode.light, const Size(1000, 700), 1.3),
        ]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await open(
            tester,
            kind: kind,
            lang: lang,
            mode: mode,
            size: size,
            categories: [...cats, (id: 'lang', name: 'Ziemlich lange Kategorie Nr. 12', color: '#58C48C')],
          );
          expect(tester.takeException(), isNull, reason: '$kind $lang $size ×$scale');
          expect(find.text(l10n(lang).widgetSettings), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  });
}
