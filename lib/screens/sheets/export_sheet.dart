import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../services/export.dart';
import '../../util/fmt.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/ui.dart';
import 'sheet_parts.dart';

/// Auswahl des Dateiformats für den Export; ein Tipp öffnet „Speichern unter“.
class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key});

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _busy = false;

  Future<void> _export(ExportFormat format) async {
    if (_busy) return;
    final app = context.app;
    final l = context.l;
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final f = Fmt.of(context);
      final bytes = await exportBytes(buildExport(app.store, l, f), format, english: f.en);
      final saved = await saveExportFile(exportFileName(format), bytes, format.mime);
      if (!saved) return; // abgebrochen: Auswahl bleibt offen
      if (mounted) nav.pop();
      app.snack.show(l.exportSaved, icon: Ic.check);
    } on Object catch (e) {
      // Auch Programmfehler (z. B. aus der PDF-Bibliothek) melden statt still zu scheitern.
      debugPrint('Export fehlgeschlagen: ${e.runtimeType}');
      app.snack.show(l.exportFailed, icon: Ic.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    Widget row(ExportFormat f, String sub) =>
        SetRow(title: f.ext.toUpperCase(), subtitle: sub, chevron: true, onTap: () => _export(f));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(l.exportData),
        Opacity(
          opacity: _busy ? 0.5 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              row(ExportFormat.pdf, l.exportPdfSub),
              row(ExportFormat.txt, l.exportTxtSub),
              row(ExportFormat.csv, l.exportCsvSub),
            ],
          ),
        ),
      ],
    );
  }
}
