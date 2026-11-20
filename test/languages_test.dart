import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_liste/data/settings_store.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';
import 'package:todo_liste/screens/language_page.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';

import 'harness.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

/// Namen der Platzhalter in einem Text („{count}“, „{count, plural, …}“).
Set<String> _placeholders(String s) => RegExp(r'\{(\w+)[,}]').allMatches(s).map((m) => m[1]!).toSet();

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    await initializeDateFormatting();
    await loadTestFonts();
  });

  group('Sprachdateien', () {
    test('alle Sprachen haben dieselben Texte mit denselben Platzhaltern', () {
      final de = _arb('de');
      final keys = de.keys.where((k) => !k.startsWith('@')).toSet();
      expect(SettingsStore.languages, ['de', 'en', 'es', 'fr', 'it']);
      for (final lang in SettingsStore.languages) {
        final arb = _arb(lang);
        expect(arb['@@locale'], lang);
        expect(arb.keys.where((k) => !k.startsWith('@')).toSet(), keys, reason: lang);
        for (final k in keys) {
          expect(_placeholders(arb[k] as String), _placeholders(de[k] as String), reason: '$lang: $k');
          expect((arb[k] as String).trim(), isNotEmpty, reason: '$lang: $k');
        }
      }
      expect(AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(), SettingsStore.languages.toSet());
    });

    test('Sprachnamen stehen überall in der eigenen Schreibweise', () {
      for (final lang in SettingsStore.languages) {
        final l = l10n(lang);
        expect(
          [for (final c in SettingsStore.languages) nativeLangName(l, c)],
          ['Deutsch', 'English', 'Español', 'Français', 'Italiano'],
        );
      }
      expect(langNameIn(l10n('de'), 'es'), 'Spanisch');
      expect(langNameIn(l10n('fr'), 'de'), 'Allemand');
    });

    test('Einzahl stimmt, „Alle“ passt zu den Kategorien', () {
      final es = l10n('es'), fr = l10n('fr'), it = l10n('it');
      expect(es.tileStreak(1), 'día de racha');
      expect(it.tileStreak(1), 'giorno di fila');
      expect(es.todayOpen(1), 'Pendientes: 1');
      expect(it.todayOpenLate(1, 1), 'Aperte: 1 · in ritardo: 1');
      expect([es.all, fr.all, it.all], ['Todas', 'Toutes', 'Tutte']);
    });
  });

  group('Datumsformate', () {
    test('Tag vor dem Monat, ohne Punkt; Wochentage und Monat groß', () {
      useFixedClock(DateTime(2026, 11, 20, 9));
      final d = DateTime(2026, 11, 27);
      final de = Fmt(l10n('de')), en = Fmt(l10n('en')), es = Fmt(l10n('es')), fr = Fmt(l10n('fr'));
      final it = Fmt(l10n('it'));
      expect(de.dayMon(d), '27. Nov.');
      expect(en.dayMon(d), 'Nov 27');
      expect(es.dayMon(d), startsWith('27 nov'));
      expect(fr.dayMon(d), '27 nov.');
      expect(it.dayMon(d), '27 nov');
      expect(es.dayMonth(d), '27 de noviembre');
      expect(it.wdLong(0), 'Lunedì');
      expect(fr.monthYear(d), 'Novembre 2026');
      expect(it.month(d), 'Novembre');
      expect(es.day(addDays(d, 3)), endsWith('30/11'));
      expect(de.day(addDays(d, 3)), endsWith('30.11.'));
      expect(it.weekRange(DateTime(2026, 11, 16)), '16–22 nov');
      expect(fr.fullDate(d), '27/11/2026');
      expect(es.dayNum(d), '27');
      expect(de.dayNum(d), '27.');
    });
  });

  group('Einstellung', () {
    test('Spanisch, Französisch, Italienisch werden gespeichert; Unbekanntes nicht', () async {
      for (final lang in ['es', 'fr', 'it']) {
        SharedPreferences.setMockInitialValues({
          'settings.v1': jsonEncode({'lang': lang}),
        });
        expect(SettingsStore(await SharedPreferences.getInstance()).lang, lang);
      }
      SharedPreferences.setMockInitialValues({
        'settings.v1': jsonEncode({'lang': 'xx'}),
      });
      expect(SettingsStore(await SharedPreferences.getInstance()).lang, SettingsStore.deviceLang());
    });

    test('Gerätesprache, sonst Englisch', () {
      expect(SettingsStore.deviceLang('it'), 'it');
      expect(SettingsStore.deviceLang('pt'), 'en');
    });
  });

  group('Seite „Sprache“', () {
    testWidgets('Antippen wechselt sofort, die Seite übersetzt sich mit; Fertig geht zurück', (tester) async {
      final de = l10n('de'), es = l10n('es');
      final app = await makeServices();
      await pumpApp(tester, app);
      await goTab(tester, de.navSettings);
      expect(find.text('Deutsch'), findsOneWidget, reason: 'Zeile zeigt die Sprache');
      await tester.tap(find.text(de.language).last);
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePage), findsOneWidget);
      expect(find.text('(${de.langNameEs})'), findsOneWidget);

      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();
      expect(app.settings.lang, 'es');
      expect(find.text(es.language), findsOneWidget, reason: 'Titel jetzt auf Spanisch');
      expect(find.text('(${es.langNameDe})'), findsOneWidget);

      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp('^Español'))), isSemantics(isSelected: true));
      handle.dispose();

      await tester.tap(find.bySemanticsLabel(es.finish));
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePage), findsNothing);
      expect(find.text(es.appearance), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('„Wie das Gerät“ nimmt die Sprache des Geräts', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final de = l10n('de');
      final app = await makeServices();
      await pumpApp(tester, app);
      await goTab(tester, de.navSettings);
      await tester.tap(find.text(de.language).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(de.langSameAsDevice));
      await tester.pumpAndSettle();
      expect(app.settings.lang, 'fr');
      await finishApp(tester, app);
    });
  });
}
