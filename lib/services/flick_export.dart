import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/gen/app_localizations.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/task_logic.dart';
import 'launch_commands.dart';

/// Die heutigen Aufgaben für den Windows-Launcher Flick (https://github.com/Whiskey-Bravo/flick).
///
/// Flick hat keine Erweiterungen, die Text von einem Programm abholen. Ein Flick-Shortcut mit
/// `pick = "<Ordner>"` zeigt aber die **Unterordner** eines Ordners als Liste in der Leiste.
/// Darum legt die App für jede heutige Aufgabe einen leeren Ordner an, dessen Name die Zeile
/// ist (`08∶00 Mathe lernen`). Flick sortiert die Ordner nach Namen – eine unsichtbare Nummer
/// vorne hält die Reihenfolge der App. Die Datenbank liest Flick nie.
///
/// Nur unter Windows und nur, wenn „Heutige Aufgaben für Flick“ in den Optionen an ist.
class FlickExport {
  FlickExport({String? dir}) : dir = dir ?? defaultDir();

  /// Ohne Ordner: schreibt nie und zeigt keine Zeilen in den Optionen (Tests).
  FlickExport.off() : dir = null;

  /// Der Ordner, den der Flick-Shortcut „Aufgaben“ liest; `null` = nicht Windows.
  final String? dir;

  /// Mehr zeigt Flick in einer Liste nicht an (die Kopfzeile zählt mit).
  static const maxEntries = 50;

  /// Längster Ordnername (Windows erlaubt 255 Zeichen; Flick zeigt ohnehin nur eine Zeile).
  static const maxName = 120;

  /// `%LOCALAPPDATA%\ToDo Planer\Flick\Heute`.
  static String? defaultDir() {
    if (kIsWeb || !Platform.isWindows) return null;
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) return null;
    return '$base\\ToDo Planer\\Flick\\Heute';
  }

  String? _last;
  Future<void> _queue = Future.value();

  /// Schreibt [names] als Unterordner (`null` = Liste ausschalten und den Ordner leeren).
  /// Aufrufe laufen nacheinander; ein unveränderter Stand schreibt nichts.
  Future<void> push(List<String>? names) {
    final sig = names?.join('\n');
    if (dir == null || sig == _last) return _queue;
    _last = sig;
    return _queue = _queue.then((_) => _write(names)).catchError((Object e) {
      // Ordner gesperrt oder ohne Rechte: beim nächsten Mal noch einmal versuchen.
      _last = null;
      debugPrint('Flick-Liste nicht geschrieben: ${e.runtimeType}');
    });
  }

  Future<void> _write(List<String>? names) async {
    final root = Directory(dir!);
    if (names == null) {
      if (!await root.exists()) return;
      await _sync(root, const []);
      // Nur löschen, wenn wirklich leer – sonst liegt dort etwas, das nicht von der App ist.
      try {
        await root.delete();
      } on FileSystemException {
        // nicht leer: stehen lassen
      }
      return;
    }
    await root.create(recursive: true);
    await _sync(root, names);
  }

  /// Gleicht die Unterordner von [root] mit [names] ab. Gelöscht werden nur **leere** Ordner
  /// (`delete` ohne `recursive`) – was jemand selbst hineingelegt hat, bleibt.
  static Future<void> _sync(Directory root, List<String> names) async {
    final want = names.toSet();
    final have = <String>{};
    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      final name = e.path.substring(e.path.lastIndexOf(Platform.pathSeparator) + 1);
      if (want.contains(name)) {
        have.add(name);
      } else {
        try {
          await e.delete();
        } on FileSystemException {
          // nicht leer oder gerade offen: stehen lassen
        }
      }
    }
    for (final n in names) {
      if (!have.contains(n)) await Directory('${root.path}${Platform.pathSeparator}$n').create();
    }
  }
}

/// Die Zeilen für Flick: Kopfzeile mit Datum, dann die offenen Aufgaben von heute und die
/// überfälligen – in derselben Reihenfolge und mit denselben Regeln („In Aufgaben zeigen“
/// der Kategorie) wie der Abschnitt „Heute“ der App.
List<String> flickTodayEntries(Store store, AppLocalizations l, {DateTime? now}) {
  final n = now ?? clock();
  final f = Fmt(l);
  int offset(Task t) => store.catOf(t.categoryId).offset;
  final rows = <String>[];
  final open = store.tasks.where((t) => !t.done).toList()..sort((a, b) => byDo(a, b, offset));
  for (final t in open) {
    final s = sectionOf(t, offset(t), now: n);
    if (s != Section.overdue && s != Section.today) continue;
    if (!shownInList(store.catOf(t.categoryId).listFrom, s)) continue;
    final title = t.hasTime ? l.flickTimed(f.time(t.dueTime!), t.title) : t.title;
    rows.add(s == Section.overdue ? l.flickOverdue(title) : title);
  }
  final shown = rows.take(FlickExport.maxEntries - 1).toList();
  return [
    flickFolderName(0, l.flickHeader(f.longDate(n), rows.length)),
    if (shown.isEmpty) flickFolderName(1, l.nothingDue),
    for (var i = 0; i < shown.length; i++) flickFolderName(i + 1, shown[i]),
  ];
}

/// Zeichen, die in Windows-Ordnernamen verboten sind, durch ähnlich aussehende ersetzt.
const _lookalikes = {':': '∶', '/': '∕', '\\': '∖', '*': '∗', '?': '？', '"': '”', '<': '‹', '>': '›', '|': 'ǀ'};

/// Unsichtbare Zeichen (Unicode „default ignorable“, nach Codepunkt aufsteigend) als Ziffern der
/// Sortiernummer: Flick zeigt sie nicht an, sortiert aber danach.
const _sortDigits = ['​', '‌', '‍', '⁠', '⁡', '⁢', '⁣', '⁤'];

/// Zwei unsichtbare Ziffern (Basis 8) reichen für [FlickExport.maxEntries] Zeilen.
String _sortKey(int index) => _sortDigits[index ~/ 8 % 8] + _sortDigits[index % 8];

/// Ein gültiger Windows-Ordnername für Zeile [index]. Vorne steht unsichtbar ihre Nummer – sie hält
/// die Reihenfolge, weil Flick die Ordner nach Namen sortiert, und macht den Namen eindeutig und nie
/// zu einem reservierten Namen wie `CON`.
String flickFolderName(int index, String text) {
  final clean = text
      .split('')
      .map((c) => _lookalikes[c] ?? (c.codeUnitAt(0) < 0x20 ? ' ' : c))
      .join()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  var name = '${_sortKey(index)}$clean';
  if (name.length > FlickExport.maxName) {
    var cut = FlickExport.maxName - 1;
    // Kein halbes Emoji (UTF-16-Paar) stehen lassen.
    if ((name.codeUnitAt(cut - 1) & 0xFC00) == 0xD800) cut--;
    name = '${name.substring(0, cut)}…';
  }
  // Windows schneidet Punkte und Leerzeichen am Ende ab – dann passte der Name nicht mehr.
  return name.replaceAll(RegExp(r'[. ]+$'), '');
}

/// Die Shortcuts für die `config.toml` von Flick (Optionen → „Flick-Shortcuts kopieren“).
/// [dir] ist der Ordner von [FlickExport]; die Namen der Shortcuts bleiben in jeder Sprache gleich.
String flickShortcuts(AppLocalizations l, String dir) {
  String q(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  String shortcut(String name, String about, List<String> more) =>
      ['[[shortcut]]', 'name = ${q(name)}', 'about = ${q(about)}', ...more, ''].join('\n');
  return [
    '# ToDo Planer → Flick (https://github.com/Whiskey-Bravo/flick)',
    '',
    shortcut('addAufgabe', l.flickAboutAdd, ['open = "$launchScheme://add"']),
    shortcut('aufgabe', l.flickAboutAddTitle, ['open = "$launchScheme://add?title={arg}"']),
    // Flick verlangt bei einer Liste {name} im Ziel – die App öffnet damit einfach „Aufgaben“.
    shortcut('Aufgaben', l.flickAboutToday, [
      'pick = ${q(dir.replaceAll(r'\', '/'))}',
      'open = "$launchScheme://tab/aufgaben?zeile={name}"',
    ]),
    shortcut('todo', l.flickAboutTab, [
      'choices = ["Aufgaben", "Kalender", "Wochenplan", "Statistik", "Optionen"]',
      'open = "$launchScheme://tab/{name}"',
    ]),
  ].join('\n');
}
