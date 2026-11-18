import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/store.dart';
import '../l10n/gen/app_localizations.dart';
import '../util/dates.dart';
import '../util/fmt.dart';
import '../util/task_logic.dart';

/// Die drei Dateiformate des Exports.
enum ExportFormat {
  pdf('pdf', 'application/pdf'),
  txt('txt', 'text/plain'),
  csv('csv', 'text/csv');

  const ExportFormat(this.ext, this.mime);
  final String ext;
  final String mime;
}

/// Eine Tabelle des Exports (Aufgaben, Gewohnheiten …) als fertige Texte.
class ExportTable {
  const ExportTable(this.title, this.head, this.rows, {this.main = 0, this.wide = const {}});
  final String title;
  final List<String> head;
  final List<List<String>> rows;

  /// Spalte mit dem Namen des Eintrags (im Text-Export die Überschrift der Zeile).
  final int main;

  /// Weitere breite Spalten im PDF (Unteraufgaben, Notiz).
  final Set<int> wide;
}

/// Alles, was exportiert wird – in der Sprache der App, unabhängig vom Dateiformat.
class ExportData {
  const ExportData({required this.title, required this.stamp, required this.tables, this.note});
  final String title;

  /// Hinweis unter dem Stand – z. B. dass ältere erledigte Aufgaben fehlen (offline).
  final String? note;

  /// „Stand: 18.11.2026“
  final String stamp;
  final List<ExportTable> tables;
}

/// Sammelt alle Daten der App für den Export: Aufgaben (offene zuerst, nach Abgabe),
/// Gewohnheiten, Wochenplan und Kategorien.
///
/// Ältere erledigte Aufgaben liegen im Modus „Auf allen Geräten“ nur online: Der Aufrufer
/// lädt sie vorher nach. Was dabei fehlt (offline), steht als Hinweis im Export.
ExportData buildExport(Store store, AppLocalizations l, Fmt f) {
  String yesNo(bool v) => v ? l.yes : l.no;

  final missing = store.olderWaiting();
  final tasks = store.tasksWithOlder..sort((a, b) => doneLast(a, b) ?? a.due.compareTo(b.due));
  final blocks = store.blocks..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.start.compareTo(b.start));

  return ExportData(
    title: l.appTitle,
    stamp: l.exportStamp(f.fullDate(today())),
    note: missing > 0 ? l.exportOlderMissing(missing) : null,
    tables: [
      ExportTable(
        l.navTasks,
        [l.colTitle, l.colCategory, l.colDue, l.time, l.done, l.yearly, l.subtasks, l.notes],
        [
          for (final t in tasks)
            [
              t.title,
              store.catOf(t.categoryId).name,
              f.fullDate(t.dueDate),
              t.dueTime == null ? '' : f.time(t.dueTime!),
              yesNo(t.done),
              yesNo(isYearly(t.title)),
              [for (final s in t.subs) '${s.done ? '[x]' : '[ ]'} ${s.title}'].join(', '),
              t.notes,
            ],
        ],
        wide: const {6, 7},
      ),
      ExportTable(
        l.habits,
        [l.name, l.colDaysDone, l.colLastDone],
        [
          for (final h in store.habits)
            () {
              final days = store.habitDoneDays(h.id);
              return [h.name, '${days.length}', days.isEmpty ? '' : f.fullDate(parseIsoDate(days.last))];
            }(),
        ],
      ),
      ExportTable(
        l.weeklyPlan,
        [l.colDay, l.colFrom, l.colTo, l.name, l.everyWeek],
        [
          for (final b in blocks)
            [
              f.wdLong(b.day),
              f.time(b.start),
              f.time(b.end),
              b.name,
              b.repeat || b.weekStart == null ? l.yes : l.exportWeekOf(f.fullDate(parseIsoDate(b.weekStart!))),
            ],
        ],
        main: 3,
      ),
      ExportTable(
        l.categories,
        [l.name, l.colLeadDays],
        [
          for (final c in store.categories) [c.name, '${c.offset}'],
        ],
      ),
    ],
  );
}

/// Dateiname wie `todo-liste-2026-11-18.pdf`.
String exportFileName(ExportFormat format) => 'todo-liste-${isoDate(today())}.${format.ext}';

Future<Uint8List> exportBytes(ExportData data, ExportFormat format, {bool english = false}) async => switch (format) {
  // Das PDF entsteht in einem eigenen Isolate: Bei vielen Aufgaben dauert das Setzen der
  // Tabellen spürbar, und die Oberfläche soll dabei nicht stehen bleiben.
  ExportFormat.pdf => await Isolate.run(() => exportPdf(data)),
  ExportFormat.txt => utf8.encode(exportTxt(data)),
  // Mit BOM, damit Excel die Umlaute richtig liest.
  ExportFormat.csv => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(exportCsv(data, sep: english ? ',' : ';'))]),
};

/// Text zum Lesen: je Eintrag eine Zeile mit dem Namen, darunter die übrigen Angaben.
String exportTxt(ExportData data) {
  final out = StringBuffer()
    ..writeln(data.title)
    ..writeln(data.stamp);
  if (data.note != null) out.writeln(data.note);
  for (final t in data.tables) {
    final heading = '${t.title.toUpperCase()} (${t.rows.length})';
    out
      ..writeln()
      ..writeln(heading)
      ..writeln('=' * heading.length);
    for (final r in t.rows) {
      out.writeln('- ${r[t.main]}');
      final rest = [
        for (var i = 0; i < r.length; i++)
          if (i != t.main && r[i].isNotEmpty) '${t.head[i]}: ${r[i]}',
      ];
      if (rest.isNotEmpty) out.writeln('  ${rest.join(' | ')}');
    }
  }
  return out.toString().replaceAll('\n', '\r\n');
}

/// Tabelle für Excel & Co.: je Bereich eine Überschrift, eine Kopfzeile und die Einträge.
/// Trennzeichen ist der Strichpunkt (wie Excel auf Deutsch), auf Englisch das Komma.
String exportCsv(ExportData data, {String sep = ';'}) {
  String cell(String v) {
    // Beginnt eine Zelle mit = + - @, würde Excel sie als Formel ausführen: entschärfen.
    final s = RegExp(r'^[=+\-@\t\r]').hasMatch(v) ? "'$v" : v;
    return RegExp('[;,"\\r\\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final lines = <String>[if (data.note != null) cell(data.note!)];
  for (final t in data.tables) {
    if (lines.isNotEmpty) lines.add('');
    lines
      ..add(cell(t.title))
      ..add(t.head.map(cell).join(sep));
    for (final r in t.rows) {
      lines.add(r.map(cell).join(sep));
    }
  }
  return '${lines.join('\r\n')}\r\n';
}

/// Die eingebaute PDF-Schrift kennt nur westeuropäische Zeichen (Umlaute ja, Emojis nein).
/// Typografische Zeichen werden ersetzt, alles andere Unbekannte wird zu „?“.
String pdfSafe(String s) {
  const map = {
    '„': '"',
    '“': '"',
    '”': '"',
    '‚': "'",
    '‘': "'",
    '’': "'",
    '–': '-',
    '—': '-',
    '…': '...',
    '€': 'EUR',
    '•': '-',
  };
  final out = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    out.write(map[ch] ?? (r < 0x20 && r != 0x0A ? ' ' : (r <= 0xFF && (r < 0x7F || r > 0x9F) ? ch : '?')));
  }
  return out.toString();
}

/// Längster Text einer Zelle im PDF. Eine Tabellenzeile kann nicht über zwei Seiten gehen –
/// wäre sie höher als eine Seite, würde die PDF-Bibliothek endlos neue Seiten anlegen.
const pdfCellMax = 400;

/// In den schmalen Spalten (Datum, Kategorie …) passt weniger Text in eine Seitenhöhe.
const pdfNarrowCellMax = 120;

String _pdfCell(String v, {required bool wide}) {
  final max = wide ? pdfCellMax : pdfNarrowCellMax;
  return pdfSafe(v.length > max ? '${v.substring(0, max)}...' : v);
}

/// PDF zum Lesen und Drucken: Titel, Stand und je Bereich eine Tabelle.
Future<Uint8List> exportPdf(ExportData data) {
  final doc = pw.Document(title: pdfSafe(data.title), creator: pdfSafe(data.title));
  const ink = PdfColor.fromInt(0xFF1F2933);
  const soft = PdfColor.fromInt(0xFF6B7785);
  const head = PdfColor.fromInt(0xFF2F6FB0);
  const stripe = PdfColor.fromInt(0xFFF2F6FA);
  const line = PdfColor.fromInt(0xFFD5DDE5);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      // Eine lange Tabelle darf viele Seiten füllen (Vorgabe der Bibliothek wären 20).
      maxPages: 2000,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: soft)),
      ),
      build: (c) => [
        pw.Text(
          pdfSafe(data.title),
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: ink),
        ),
        pw.SizedBox(height: 2),
        pw.Text(pdfSafe(data.stamp), style: const pw.TextStyle(fontSize: 10, color: soft)),
        if (data.note != null) pw.Text(pdfSafe(data.note!), style: const pw.TextStyle(fontSize: 10, color: soft)),
        for (final t in data.tables) ...[
          pw.SizedBox(height: 18),
          pw.Text(
            pdfSafe('${t.title} (${t.rows.length})'),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: ink),
          ),
          pw.SizedBox(height: 6),
          if (t.rows.isEmpty)
            pw.Text('-', style: const pw.TextStyle(fontSize: 10, color: soft))
          else
            pw.TableHelper.fromTextArray(
              headers: [for (final h in t.head) pdfSafe(h)],
              data: [
                for (final r in t.rows)
                  [for (final (i, v) in r.indexed) _pdfCell(v, wide: i == t.main || t.wide.contains(i))],
              ],
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: line, width: 0.5),
                bottom: pw.BorderSide(color: line, width: 0.5),
              ),
              headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: head),
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9.5, color: ink),
              cellAlignment: pw.Alignment.topLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              oddRowDecoration: const pw.BoxDecoration(color: stripe),
              // Schmale Spalten (Datum, Ja/Nein …) so breit wie ihr Inhalt; Name, Unteraufgaben und
              // Notiz teilen sich den Rest.
              columnWidths: {
                t.main: const pw.FlexColumnWidth(3),
                for (final w in t.wide) w: const pw.FlexColumnWidth(2),
              },
              defaultColumnWidth: const pw.IntrinsicColumnWidth(),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Öffnet „Speichern unter“ und schreibt die Datei. `false`, wenn abgebrochen wurde.
/// Tests ersetzen das, damit kein Dialog aufgeht.
Future<bool> Function(String name, Uint8List bytes, String mime) saveExportFile = (name, bytes, mime) async =>
    await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime) != null;
