import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../util/dates.dart';
import '../widgets/overlays.dart';
import 'sheets/block_sheet.dart';
import 'sheets/block_view_sheet.dart';
import 'sheets/category_sheet.dart';
import 'sheets/column_sheet.dart';
import 'sheets/columns_sheet.dart';
import 'sheets/export_sheet.dart';
import 'sheets/habit_sheet.dart';
import 'sheets/task_sheet.dart';
import 'ui_state.dart';

/// Öffnet die Sheets (von unten hereinfahrende Formulare) für Aufgabe, Block, Gewohnheit,
/// Kategorie und Export. Die Formulare selbst liegen in `lib/screens/sheets/`.
class Sheets {
  Sheets(this.context, this.ui);
  final BuildContext context;
  final UiState ui;

  /// [title]: Vorgabe für eine neue Aufgabe (z. B. aus einem `todoplaner://add?title=…`-Link).
  void task(Task? t, {DateTime? preset, String? title}) {
    final l = context.l;
    final app = context.app;
    if (app.store.categories.isEmpty) app.ensureCategoriesNow(l);
    showAppSheet<void>(
      context,
      label: t == null ? l.newTask : l.editTask,
      builder: (_) => TaskSheet(task: t, preset: preset, initialTitle: title, ui: ui),
    );
  }

  void newBlock({int? day, int? start}) {
    final l = context.l;
    final s = context.app.settings;
    // Ohne Vorgabe: der gezeigte Tag, in der laufenden Woche heute, sonst der erste Tag der Woche.
    final wd = ui.weekDay;
    final shown = wd != null
        ? addDays(ui.weekStart, wd)
        : (sameDay(ui.weekStart, weekStartOf(clock())) ? clock() : ui.weekStart);
    final d = day ?? wdIndex(shown);
    // Spätestes „Bis“ ist der letzte Raster-Schritt vor Mitternacht; „Von“ muss mindestens
    // einen Schritt davor liegen, sonst wäre der Block leer.
    final last = 24 * 60 - s.raster;
    final from = math.min(start ?? 15 * 60, last - s.raster);
    final to = start == null ? 16 * 60 : (from + 60).clamp(from + s.raster, last);
    showAppSheet<void>(
      context,
      label: l.newBlock,
      builder: (_) => BlockSheet(block: null, day: d, start: from, end: to, ui: ui),
    );
  }

  /// Antippen eines Blocks: erst die Ansicht; Bearbeiten und Löschen stehen dort im ⋮-Menü.
  void block(WeekBlock b) {
    showAppSheet<void>(
      context,
      label: context.l.blockView,
      builder: (_) => BlockViewSheet(blockId: b.id, ui: ui, onEdit: editBlock),
    );
  }

  void editBlock(WeekBlock b) {
    showAppSheet<void>(
      context,
      label: context.l.editBlock,
      builder: (_) => BlockSheet(block: b, day: b.day, start: b.start, end: b.end, ui: ui),
    );
  }

  /// Welche Listen (am PC Spalten, am Handy Abschnitte) es gibt und wie viele nebeneinander stehen.
  void columns({required bool board}) {
    showAppSheet<void>(
      context,
      label: context.l.columns,
      builder: (sheet) => ColumnsSheet(
        board: board,
        // Das Formular ersetzt die Übersicht: Danach sieht man gleich das Ergebnis (und „Rückgängig“).
        onEdit: (c) {
          Navigator.pop(sheet);
          column(c);
        },
      ),
    );
  }

  /// Eigene Spalte anlegen (`null`) oder bearbeiten.
  void column(BoardColumn? c) {
    final l = context.l;
    showAppSheet<void>(
      context,
      label: c == null ? l.newColumn : l.editColumn,
      builder: (_) => ColumnSheet(column: c),
    );
  }

  void habit(Habit? h) {
    final l = context.l;
    showAppSheet<void>(
      context,
      label: h == null ? l.newHabit : l.editHabit,
      builder: (_) => HabitSheet(habit: h),
    );
  }

  /// Alle Daten als PDF, Text oder Tabelle speichern.
  void export() {
    showAppSheet<void>(context, label: context.l.exportData, builder: (_) => const ExportSheet());
  }

  void category(TaskCategory? c) {
    final l = context.l;
    showAppSheet<void>(
      context,
      label: c == null ? l.newCategory : l.editCategory,
      builder: (_) => CategorySheet(cat: c, ui: ui),
    );
  }
}
