import '../l10n/gen/app_localizations.dart';
import 'dates.dart';

/// Die gesetzlichen Feiertage in Österreich. Sie werden gerechnet, nicht gespeichert.
enum Holiday {
  newYear,
  epiphany,
  easterMonday,
  labourDay,
  ascension,
  whitMonday,
  corpusChristi,
  assumption,
  nationalDay,
  allSaints,
  immaculate,
  christmas,
  stStephen,
}

/// Ostersonntag im gregorianischen Kalender (Gaußsche Osterformel in der Fassung von Butcher).
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(year, month, day);
}

final Map<int, Map<String, Holiday>> _byYear = {};

/// Alle Feiertage eines Jahres, Schlüssel ist der Tag als `JJJJ-MM-TT`.
Map<String, Holiday> holidaysOf(int year) => _byYear[year] ??= () {
  final easter = easterSunday(year);
  return {
    isoDate(DateTime(year, 1, 1)): Holiday.newYear,
    isoDate(DateTime(year, 1, 6)): Holiday.epiphany,
    isoDate(addDays(easter, 1)): Holiday.easterMonday,
    isoDate(DateTime(year, 5, 1)): Holiday.labourDay,
    isoDate(addDays(easter, 39)): Holiday.ascension,
    isoDate(addDays(easter, 50)): Holiday.whitMonday,
    isoDate(addDays(easter, 60)): Holiday.corpusChristi,
    isoDate(DateTime(year, 8, 15)): Holiday.assumption,
    isoDate(DateTime(year, 10, 26)): Holiday.nationalDay,
    isoDate(DateTime(year, 11, 1)): Holiday.allSaints,
    isoDate(DateTime(year, 12, 8)): Holiday.immaculate,
    isoDate(DateTime(year, 12, 25)): Holiday.christmas,
    isoDate(DateTime(year, 12, 26)): Holiday.stStephen,
  };
}();

/// Der Feiertag an diesem Tag oder `null`.
Holiday? holidayOn(DateTime d) => holidaysOf(d.year)[isoDate(d)];

String holidayName(AppLocalizations l, Holiday h) => switch (h) {
  Holiday.newYear => l.hNewYear,
  Holiday.epiphany => l.hEpiphany,
  Holiday.easterMonday => l.hEasterMonday,
  Holiday.labourDay => l.hLabourDay,
  Holiday.ascension => l.hAscension,
  Holiday.whitMonday => l.hWhitMonday,
  Holiday.corpusChristi => l.hCorpusChristi,
  Holiday.assumption => l.hAssumption,
  Holiday.nationalDay => l.hNationalDay,
  Holiday.allSaints => l.hAllSaints,
  Holiday.immaculate => l.hImmaculate,
  Holiday.christmas => l.hChristmas,
  Holiday.stStephen => l.hStStephen,
};
