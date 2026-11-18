import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_liste/services/home_widgets.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';
import 'package:todo_liste/util/task_logic.dart';

import 'harness.dart';

/// Die Zusammenfassung, die die App für die Startbildschirm-Widgets schreibt.
void main() {
  setUpAll(() => initializeDateFormatting());

  testWidgets('enthält offene Aufgaben nach Fälligkeit, Gewohnheiten und Texte in der App-Sprache', (tester) async {
    useFixedClock(); // Mi, 18.11.2026
    for (final lang in ['de', 'en']) {
      final l = l10n(lang);
      final app = await makeServices(lang: lang);
      seedDemo(app.store, l);
      final snap = buildWidgetSnapshot(app.store, l, themeId: 'wald');
      final again = jsonDecode(jsonEncode(snap)) as Map<String, dynamic>; // muss als JSON speicherbar sein

      final tasks = (again['tasks'] as List).cast<Map<String, dynamic>>();
      expect(tasks.map((t) => t['t']), isNot(contains('Zimmer aufräumen')), reason: 'erledigte Aufgaben fehlen');
      expect(tasks.first['t'], 'Mathe S. 42 Nr. 3–7', reason: 'überfällige zuerst');
      expect(tasks.first['d'], '2026-11-17');
      // Reihenfolge und „heute“ wie in der App: nach dem Tag, ab dem die Aufgabe in der Liste steht
      // (Abgabe minus Vorlauf der Kategorie), nicht nach dem Abgabetag.
      final starts = tasks.map((t) => t['s'] as String).toList();
      expect(starts, [...starts]..sort(), reason: 'nach Listen-Tag sortiert');
      for (final t in app.store.tasks.where((t) => !t.done)) {
        final row = tasks.firstWhere((r) => r['t'] == t.title);
        expect(row['s'], isoDate(doDate(t, app.store.catOf(t.categoryId).offset)), reason: t.title);
        expect(row['d'], isoDate(t.dueDate), reason: t.title);
      }
      expect(tasks.any((t) => t['s'] != t['d']), isTrue, reason: 'die Demo hat Aufgaben mit Vorlauf');
      final trash = tasks.firstWhere((t) => t['t'] == 'Müll rausbringen');
      expect(trash['m'], 18 * 60);
      expect(trash['c'], startsWith('#'));

      final habits = (again['habits'] as List).cast<Map<String, dynamic>>();
      expect(habits.map((h) => h['n']), ['Wasser', 'Lesen', 'Sport']);
      expect(habits[0]['days'], contains(isoDate(today())), reason: 'Wasser ist heute erledigt');
      expect(habits[2]['days'], isEmpty);

      final labels = again['labels'] as Map<String, dynamic>;
      expect(labels['today'], l.today);
      expect(labels['upcoming'], l.widgetUpcoming);
      // „bis: {}“ – das Widget setzt Tag/Uhrzeit selbst ein
      expect(labels['until'], lang == 'en' ? 'by: {}' : 'bis: {}');
      // Monate für das Datum neben „Heute“ (das Widget rechnet den Tag selbst)
      expect(again['mon'], hasLength(12));
      expect((again['mon'] as List)[10], lang == 'en' ? 'Nov' : 'Nov.');
      expect(Fmt(l).widgetDate(DateTime(2026, 11, 18)), lang == 'en' ? 'NOV 18' : '18. NOV.');
      expect(again['en'], lang == 'en');
      expect(again['wd'], hasLength(7));
      expect(again['accent'], isNot(again['accentDark']));
      await finishApp(tester, app);
    }
  });

  testWidgets('höchstens ${HomeWidgets.maxTasks} Aufgaben', (tester) async {
    final l = l10n('de');
    final app = await makeServices();
    seedDemo(app.store, l);
    for (var i = 0; i < 100; i++) {
      app.store.addTask(
        title: 'Viele $i',
        categoryId: app.store.categories.first.id,
        dueDate: addDays(today(), i),
        dueTime: null,
        subs: const [],
      );
    }
    final snap = buildWidgetSnapshot(app.store, l, themeId: 'himmel');
    expect(snap['tasks'], hasLength(HomeWidgets.maxTasks));
    await finishApp(tester, app);
  });

  testWidgets('im Widget abgehakte Gewohnheiten landen in den Daten der App', (tester) async {
    useFixedClock();
    final l = l10n('de');
    final app = await makeServices();
    seedDemo(app.store, l);
    final day = isoDate(today());
    final [wasser, lesen, sport] = app.store.habits;
    expect(app.store.habitDone(wasser.id, day), isTrue);
    expect(app.store.habitDone(sport.id, day), isFalse);

    // Die Zusammenfassung nennt die Gewohnheit, damit das Widget sagen kann, welche gemeint ist
    final snap = buildWidgetSnapshot(app.store, l, themeId: 'himmel');
    expect((snap['habits'] as List).map((h) => (h as Map)['id']), [wasser.id, lesen.id, sport.id]);

    // Merkzettel von Android: Sport abgehakt, Wasser wieder geöffnet, Lesen unverändert (ist schon offen)
    final changed = applyWidgetHabitToggles(
      app.store,
      jsonEncode({'${sport.id}|$day': true, '${wasser.id}|$day': false, '${lesen.id}|$day': false}),
    );
    expect(changed, 2);
    expect(app.store.habitDone(sport.id, day), isTrue);
    expect(app.store.habitDone(wasser.id, day), isFalse);
    expect(app.store.habitDone(lesen.id, day), isFalse);
    // Dasselbe noch einmal ändert nichts (kein Hin-und-her)
    expect(applyWidgetHabitToggles(app.store, jsonEncode({'${sport.id}|$day': true})), 0);

    // Kaputtes und Unbekanntes wird übersprungen, nichts stürzt ab
    for (final bad in [null, '', 'kein json', '[1,2]', '{"x":true}', '{"gibts-nicht|$day":true}']) {
      expect(applyWidgetHabitToggles(app.store, bad), 0, reason: '$bad');
    }
    expect(applyWidgetHabitToggles(app.store, jsonEncode({'${lesen.id}|morgen': true, '${lesen.id}|$day': 'ja'})), 0);
    expect(app.store.habitDone(lesen.id, day), isFalse);
    await finishApp(tester, app);
  });

  test('„+“ im Widget wird nachgereicht, sobald die App zuhört', () async {
    final w = HomeWidgets();
    var opened = 0;
    await w.listen(() => opened++);
    expect(opened, 0);
  });
}
