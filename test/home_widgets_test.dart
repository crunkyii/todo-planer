import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_liste/services/home_widgets.dart';
import 'package:todo_liste/util/dates.dart';
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

  test('„+“ im Widget wird nachgereicht, sobald die App zuhört', () async {
    final w = HomeWidgets();
    var opened = 0;
    await w.listen(() => opened++);
    expect(opened, 0);
  });
}
