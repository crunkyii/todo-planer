import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_liste/data/cloud.dart';
import 'package:todo_liste/data/models.dart';
import 'package:todo_liste/l10n/gen/app_localizations.dart';
import 'package:todo_liste/services/error_messages.dart';
import 'package:todo_liste/services/reminders.dart';
import 'package:todo_liste/theme/color_math.dart';
import 'package:todo_liste/util/dates.dart';
import 'package:todo_liste/util/fmt.dart';
import 'package:todo_liste/util/stats.dart';
import 'package:todo_liste/util/task_logic.dart';
import 'package:todo_liste/util/week_layout.dart';

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

WeekBlock _block(String id, int start, int end) => WeekBlock(
  id: id,
  name: id,
  color: '#3D9BE9',
  day: 0,
  start: start,
  end: end,
  repeat: true,
  weekStart: null,
  updatedAt: nowUtc(),
);

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

  group('Kalender-Grenzen', () {
    test('Schaltjahr, Monats- und Jahreswechsel', () {
      expect(addDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
      expect(addDays(DateTime(2027, 2, 28), 1), DateTime(2027, 3, 1));
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 31));
      expect(dayDiff(DateTime(2028, 3, 1), DateTime(2028, 2, 1)), 29);
      expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(parseIsoDate('2028-02-29T10:00:00'), DateTime(2028, 2, 29));
    });

    test('Woche beginnt am Montag, auch über Monat und Jahr hinweg', () {
      expect(monday(DateTime(2026, 11, 22)), DateTime(2026, 11, 16)); // Sonntag gehört zur Woche davor
      expect(monday(DateTime(2026, 12, 1)), DateTime(2026, 11, 30));
      expect(monday(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
      expect(wdIndex(DateTime(2026, 11, 16)), 0);
      expect(wdIndex(DateTime(2026, 11, 22)), 6);
      expect(isoWeek(DateTime(2026, 12, 28)), 53);
      expect(isoWeek(DateTime(2027, 1, 4)), 1);
      expect(isoWeek(DateTime(2024, 12, 30)), 1);
    });

    test('Tage zählen über die Zeitumstellung hinweg', () {
      expect(dayDiff(DateTime(2027, 3, 29), DateTime(2027, 3, 27)), 2);
      expect(addDays(DateTime(2027, 3, 27), 2), DateTime(2027, 3, 29));
      expect(addDays(DateTime(2027, 10, 30), 2), DateTime(2027, 11, 1));
    });

    test('Serie über den Monatswechsel', () {
      final t = DateTime(2026, 12, 2);
      final done = {'2026-12-02', '2026-12-01', '2026-11-30', '2026-11-29'};
      expect(streak((d) => done.contains(isoDate(d)), from: t), 4);
    });
  });

  group('Formate je Sprache', () {
    setUpAll(() => initializeDateFormatting());
    final d = DateTime(2026, 11, 20);

    test('Deutsch', () {
      final f = Fmt(lookupAppLocalizations(const Locale('de')));
      expect(f.dayMonth(d), '20. November');
      expect(f.dayNum(d), '20.');
      expect(f.wd(0), 'Mo');
      expect(f.oneDecimal(1.9), '1,9');
      expect(f.duration(90), contains('1'));
      expect(f.time(8 * 60 + 5), '08:05');
    });

    test('Englisch', () {
      final f = Fmt(lookupAppLocalizations(const Locale('en')));
      expect(f.dayMonth(d), 'November 20');
      expect(f.dayNum(d), '20');
      expect([f.wd(0), f.wd(1), f.wd(6)], ['Mo', 'Tu', 'Su']); // zwei Buchstaben wie im Prototyp
      expect(f.oneDecimal(1.9), '1.9');
    });

    test('Monatskürzel wie im Prototyp (Deutsch mit Punkt, Englisch ohne)', () {
      List<String> all(String lang) => [
        for (var m = 1; m <= 12; m++) Fmt(lookupAppLocalizations(Locale(lang))).monShort(DateTime(2026, m, 5)),
      ];
      expect(all('de'), [
        'Jän.',
        'Feb.',
        'März',
        'Apr.',
        'Mai',
        'Juni',
        'Juli',
        'Aug.',
        'Sep.',
        'Okt.',
        'Nov.',
        'Dez.',
      ]);
      expect(all('en'), ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']);
      final de = Fmt(lookupAppLocalizations(const Locale('de')));
      expect(de.weekRange(DateTime(2026, 11, 16)), '16.–22. Nov.');
      expect(de.weekRange(DateTime(2026, 12, 28)), '28. Dez. – 3. Jän.');
    });
  });

  group('Abschnitte', () {
    test('Am Sonntag ist „Diese Woche“ leer; Mitternacht trennt die Tage', () {
      final sunday = DateTime(2026, 11, 22, 23, 59);
      expect(sectionOf(_task('a', DateTime(2026, 11, 23)), 0, now: sunday), Section.tomorrow);
      expect(sectionOf(_task('b', DateTime(2026, 11, 24)), 0, now: sunday), Section.later);
      expect(sectionOf(_task('c', DateTime(2026, 11, 22)), 0, now: sunday), Section.today);
      final justAfter = DateTime(2026, 11, 23, 0, 0, 1);
      expect(sectionOf(_task('c', DateTime(2026, 11, 22)), 0, now: justAfter), Section.overdue);
      expect(sectionOf(_task('d', DateTime(2026, 11, 23), time: 0), 0, now: justAfter), Section.overdue);
      expect(sectionOf(_task('e', DateTime(2026, 11, 23)), 0, now: justAfter), Section.today);
    });

    test('Vorlauf „1 Woche vorher“ über den Monatswechsel', () {
      final t = _task('Test', DateTime(2026, 12, 3));
      expect(doDate(t, 7), DateTime(2026, 11, 26));
      expect(sectionOf(t, 7, now: DateTime(2026, 11, 26, 8)), Section.today);
    });

    final now = DateTime(2026, 11, 18, 10); // Mittwoch

    test('Vorlauf der Kategorie verschiebt den Erledigen-Tag', () {
      final t = _task('Hausübung', DateTime(2026, 11, 19));
      expect(sectionOf(t, 0, now: now), Section.tomorrow);
      expect(sectionOf(t, 1, now: now), Section.today);
      expect(sectionOf(t, 2, now: now), Section.today, reason: 'Vorlauf macht nie überfällig');
    });

    test('Überfällig erst nach der Abgabe: mit Uhrzeit danach, ohne Uhrzeit nach 23:59', () {
      // Abgabe heute 23:00, Kategorie mit einem Tag Vorlauf („in der Liste ab gestern“)
      final timed = _task('tvvvv', DateTime(2026, 11, 18), time: 23 * 60);
      expect(isLate(timed, now: now), isFalse);
      expect(sectionOf(timed, 1, now: now), Section.today);
      expect(sectionOf(timed, 1, now: DateTime(2026, 11, 18, 23)), Section.today, reason: 'genau zur Abgabezeit');
      expect(sectionOf(timed, 1, now: DateTime(2026, 11, 18, 23, 0, 1)), Section.overdue);
      // ohne Uhrzeit zählt der ganze Abgabetag
      final allDay = _task('hhj', DateTime(2026, 11, 18));
      expect(sectionOf(allDay, 3, now: DateTime(2026, 11, 18, 23, 59, 59)), Section.today);
      expect(sectionOf(allDay, 3, now: DateTime(2026, 11, 19)), Section.overdue);
      expect(isLate(_task('fertig', DateTime(2026, 11, 1), done: true), now: now), isFalse);
    });

    test('Kategorie-Vorschlag: die zuletzt am häufigsten benutzte', () {
      Task at(String cat, int minutesAgo) => Task(
        id: newId(),
        title: 't',
        categoryId: cat,
        dueDate: DateTime(2026, 11, 18),
        dueTime: null,
        done: minutesAgo.isEven,
        doneAt: null,
        createdAt: DateTime.utc(2026, 11, 18, 10).subtract(Duration(minutes: minutesAgo)),
        updatedAt: nowUtc(),
      );
      const cats = ['hu', 'test', 'termin'];
      expect(suggestCategory(const [], cats), 'hu', reason: 'ohne Aufgaben die erste Kategorie');
      expect(suggestCategory(const [], const []), isNull);
      // Termin 3×, Test 2× → Termin (erledigte zählen mit)
      final some = [at('termin', 5), at('test', 4), at('termin', 3), at('test', 2), at('termin', 1)];
      expect(suggestCategory(some, cats), 'termin');
      // Gleichstand: die zuletzt benutzte
      expect(suggestCategory([at('test', 9), at('termin', 8), at('termin', 2), at('test', 1)], cats), 'test');
      // Passt sich an: früher 30× Hausübung, die letzten 20 aber meist Test
      final changed = [
        for (var i = 0; i < 30; i++) at('hu', 100 + i),
        for (var i = 0; i < 12; i++) at('test', 20 + i),
        for (var i = 0; i < 8; i++) at('hu', i),
      ];
      expect(suggestCategory(changed, cats), 'test');
      // Aufgaben gelöschter Kategorien zählen nicht
      expect(suggestCategory([at('weg', 1), at('weg', 2), at('termin', 3)], cats), 'termin');
    });

    test('Liste ändert sich von selbst: zur nächsten Abgabe-Uhrzeit, sonst um Mitternacht', () {
      final midnight = DateTime(2026, 11, 19);
      expect(nextListChange(const [], now), midnight);
      final tasks = [
        _task('vorbei', DateTime(2026, 11, 18), time: 9 * 60),
        _task('ohne Uhrzeit', DateTime(2026, 11, 18)),
        _task('abends', DateTime(2026, 11, 18), time: 23 * 60),
        _task('erledigt', DateTime(2026, 11, 18), time: 11 * 60, done: true),
        _task('morgen', DateTime(2026, 11, 19), time: 8 * 60),
      ];
      expect(nextListChange(tasks, now), DateTime(2026, 11, 18, 23));
      expect(
        nextListChange([_task('nachmittags', DateTime(2026, 11, 18), time: 14 * 60), ...tasks], now),
        DateTime(2026, 11, 18, 14),
      );
      // Genau zur Uhrzeit ist die Aufgabe noch nicht überfällig, eine Sekunde später schon
      final abends = tasks[2];
      expect(isLate(abends, now: DateTime(2026, 11, 18, 23)), isFalse);
      expect(isLate(abends, now: DateTime(2026, 11, 18, 23, 0, 1)), isTrue);
      expect(nextListChange(tasks, DateTime(2026, 11, 18, 23, 0, 1)), midnight);
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
      // Unerreichbares Verhältnis: geht bis ganz ans Ziel (früher blieb es durch Rundung bei 95 %).
      expect(ensure(const Color(0xFF808080), white, 99), black);
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
    final list = upcomingReminders(
      [
        _task('später', DateTime(2026, 11, 18), time: 12 * 60),
        _task('vorbei', DateTime(2026, 11, 18), time: 9 * 60),
        _task('ohne Zeit', DateTime(2026, 11, 19)),
        _task('erledigt', DateTime(2026, 11, 19), time: 8 * 60, done: true),
      ],
      (t) => t.title,
      now: now,
    );
    expect(list.map((r) => r.title), ['später']);
  });

  group('Fehlermeldungen', () {
    final de = lookupAppLocalizations(const Locale('de'));
    test('Netzwerk, Login und unbekannt', () {
      expect(friendlyErrorMessage(de, const SocketException('x')), de.errNetwork);
      expect(
        friendlyErrorMessage(de, const AuthException('Invalid login credentials', code: 'invalid_credentials')),
        de.errWrongLogin,
      );
      expect(friendlyErrorMessage(de, StateError('x')), de.errUnexpected);
      // Lehnt der Server eine richtig geschriebene Adresse ab, zeigt die App seine Meldung
      // und behauptet nicht „ungültige E-Mail“.
      for (final code in ['validation_failed', 'email_address_invalid', 'email_address_not_authorized']) {
        final msg = friendlyErrorMessage(de, AuthException('Grund vom Server', code: code));
        expect(msg, isNot(de.errEmail), reason: code);
        expect(msg, contains('Grund vom Server'), reason: code);
      }
    });
  });
}
