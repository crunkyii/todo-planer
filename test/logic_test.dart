import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_liste/data/cloud.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';
import 'package:todo_liste/screens/stats_tab.dart';
import 'package:todo_liste/screens/week_tab.dart';
import 'package:todo_liste/services/error_messages.dart';
import 'package:todo_liste/services/reminders.dart';
import 'package:todo_liste/theme/color_math.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/task_logic.dart';

Task _task(String title, DateTime due, {int? time, bool done = false, String cat = 'c'}) => Task(
      id: newId(),
      title: title,
      categoryId: cat,
      dueDate: due,
      dueTime: time,
      done: done,
      doneAt: done ? nowUtc() : null,
      createdAt: nowUtc(),
      updatedAt: nowUtc(),
    );

WeekBlock _block(String id, int start, int end) =>
    WeekBlock(id: id, name: id, color: '#3D9BE9', day: 0, start: start, end: end, repeat: true, weekStart: null, updatedAt: nowUtc());

void main() {
  group('Datum', () {
    test('Montag und Kalenderwoche', () {
      expect(monday(DateTime(2026, 11, 18)), DateTime(2026, 11, 16));
      expect(isoWeek(DateTime(2026, 11, 18)), 47);
      expect(isoWeek(DateTime(2027, 1, 1)), 53);
    });

    test('Serie zählt heute nur, wenn erledigt', () {
      final t = DateTime(2026, 11, 18);
      final done = {isoDate(addDays(t, -1)), isoDate(addDays(t, -2))};
      expect(streak((d) => done.contains(isoDate(d)), from: t), 2);
      done.add(isoDate(t));
      expect(streak((d) => done.contains(isoDate(d)), from: t), 3);
      expect(streak((d) => false, from: t), 0);
    });

    test('Fälligkeit stimmt auch am Tag der Zeitumstellung', () {
      // In Mitteleuropa hat der 28.3.2027 nur 23 Stunden, der 31.10.2027 hat 25.
      for (final d in [DateTime(2027, 3, 28), DateTime(2027, 10, 31)]) {
        final due = _task('x', d, time: 8 * 60).due;
        expect((due.day, due.hour, due.minute), (d.day, 8, 0));
      }
    });

    test('Uhrzeit-Text', () {
      expect(hmString(8 * 60 + 5), '08:05');
      expect(parseHm('16:30'), 990);
    });
  });

  group('Abschnitte', () {
    final now = DateTime(2026, 11, 18, 10); // Mittwoch

    test('Vorlauf der Kategorie verschiebt den Erledigen-Tag', () {
      final t = _task('Hausübung', DateTime(2026, 11, 19));
      expect(sectionOf(t, 0, now: now), Section.tomorrow);
      expect(sectionOf(t, 1, now: now), Section.today);
      expect(sectionOf(t, 2, now: now), Section.overdue);
    });

    test('Uhrzeit vorbei = überfällig, Woche bis Sonntag', () {
      expect(sectionOf(_task('a', DateTime(2026, 11, 18), time: 9 * 60), 0, now: now), Section.overdue);
      expect(sectionOf(_task('b', DateTime(2026, 11, 18), time: 11 * 60), 0, now: now), Section.today);
      expect(sectionOf(_task('c', DateTime(2026, 11, 22)), 0, now: now), Section.week);
      expect(sectionOf(_task('d', DateTime(2026, 11, 23)), 0, now: now), Section.later);
      expect(sectionOf(_task('e', DateTime(2026, 11, 1), done: true), 0, now: now), Section.done);
    });

    test('Filter und Suche (auch in Unteraufgaben)', () {
      final a = _task('Mathe', DateTime(2026, 11, 18), cat: 'x');
      final b = _task('Deutsch', DateTime(2026, 11, 18), done: true)
        ..subs = [Subtask(id: 's', taskId: 'b', title: 'Aufsatz lesen', done: false, position: 0, updatedAt: nowUtc())];
      expect(filterTasks([a, b], filter: 'x', hideDone: false), [a]);
      expect(filterTasks([a, b], filter: 'alle', hideDone: true), [a]);
      expect(filterTasks([a, b], filter: 'alle', hideDone: false, search: 'aufsatz'), [b]);
    });
  });

  group('Datenbank-Einrichtung', () {
    const url = 'https://abcdefgh.supabase.co';
    test('gültige Eingaben', () {
      expect(validateSetup(url, 'sb_publishable_1234567890abc'), isNull);
      expect(validateSetup(normalizeUrl('$url//'), 'sb_publishable_1234567890abc'), isNull);
    });

    test('falsche URL und Secret Key werden abgelehnt', () {
      expect(validateSetup('http://abc.supabase.co', 'sb_publishable_1234567890abc'), SetupError.url);
      expect(validateSetup('https://example.com', 'sb_publishable_1234567890abc'), SetupError.url);
      expect(validateSetup(url, 'sb_secret_1234567890abc'), SetupError.secretKey);
      expect(validateSetup(url, 'abc'), SetupError.keyFormat);
    });
  });

  group('Farben', () {
    test('mix und Kontrast', () {
      expect(mix(black, white, 0), black);
      expect(mix(black, white, 1), white);
      expect(contrast(black, white), closeTo(21, 0.01));
      final fg = ensure(const Color(0xFFF5B83D), white, 4.5);
      expect(contrast(fg, white), greaterThanOrEqualTo(4.5));
    });

    test('Hex lesen und schreiben', () {
      expect(toHex(parseHex('#3D9BE9')).toUpperCase(), '#3D9BE9');
      expect(parseHex('kaputt'), const Color(0xFF3D9BE9));
    });
  });

  group('Statistik und Wochenplan', () {
    test('Heatmap-Stufen', () {
      expect([0, 1, 2, 3, 4, 5, 6, 20].map(heatLevel), [0, 1, 2, 2, 3, 3, 4, 4]);
    });

    test('Achsen-Maximum mindestens 4 und gerade', () {
      expect(chartMax([0, 1]), 4);
      expect(chartMax([5]), 6);
      expect(chartMax([8, 2]), 8);
    });

    test('überlappende Blöcke bekommen eigene Spuren', () {
      final r = layoutLanes([_block('a', 480, 600), _block('b', 540, 660), _block('c', 600, 700)]);
      expect(r.lanes, 2);
      expect(r.lane, {'a': 0, 'b': 1, 'c': 0});
    });
  });

  test('Erinnerungen nur für offene Aufgaben mit Uhrzeit in der Zukunft', () {
    final now = DateTime(2026, 11, 18, 10);
    final list = upcomingReminders([
      _task('später', DateTime(2026, 11, 18), time: 12 * 60),
      _task('vorbei', DateTime(2026, 11, 18), time: 9 * 60),
      _task('ohne Zeit', DateTime(2026, 11, 19)),
      _task('erledigt', DateTime(2026, 11, 19), time: 8 * 60, done: true),
    ], (t) => t.title, now: now);
    expect(list.map((r) => r.title), ['später']);
  });

  group('Fehlermeldungen', () {
    final de = lookupAppLocalizations(const Locale('de'));
    test('Netzwerk, Login und unbekannt', () {
      expect(friendlyErrorMessage(de, const SocketException('x')), de.errNetwork);
      expect(friendlyErrorMessage(de, const AuthException('Invalid login credentials', code: 'invalid_credentials')), de.errWrongLogin);
      expect(friendlyErrorMessage(de, StateError('x')), de.errUnexpected);
    });
  });
}
