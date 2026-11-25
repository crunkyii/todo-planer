import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../util/fmt.dart';
import '../../widgets/select.dart';
import '../../widgets/ui.dart';
import 'sheet_parts.dart';

/// Zeile „Benachrichtigung“ in Aufgabe und Block: keine, zum Zeitpunkt, fertige Vorlaufzeiten
/// oder eine eigene Zeit in Minuten.
class RemindField extends StatefulWidget {
  const RemindField({super.key, required this.value, required this.onChanged, this.hasTime = true, this.error});

  /// Minuten vorher, [remindNone] oder `null` = die eigene Zeit ist (noch) keine gültige Zahl.
  final int? value;
  final ValueChanged<int?> onChanged;

  /// `false` = noch keine Uhrzeit, es käme also keine Benachrichtigung.
  final bool hasTime;

  /// Fehlermeldung unter dem Feld für die eigene Zeit.
  final String? error;

  @override
  State<RemindField> createState() => _RemindFieldState();
}

class _RemindFieldState extends State<RemindField> {
  static const _presets = [remindNone, 0, 5, 10, 15, 30, 60, 24 * 60];

  /// Der Menüpunkt „Eigene Zeit“ – kein Wert, der gespeichert wird.
  static const _customOption = remindMax + 1;

  final _minutes = TextEditingController();

  /// Das Feld für die eigene Zeit ist offen – auch, wenn die Zeile mit einer noch ungültigen
  /// eigenen Zeit zu- und wieder aufgeklappt wurde.
  late bool _custom = widget.value == null;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _pick(int v) {
    setState(() => _custom = v == _customOption);
    if (!_custom) return widget.onChanged(v);
    final now = widget.value;
    _minutes.text = now != null && now > 0 ? '$now' : '';
    _typed(_minutes.text);
  }

  void _typed(String text) {
    final v = int.tryParse(text.trim());
    widget.onChanged(v != null && v >= 1 && v <= remindMax ? v : null);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final f = Fmt.of(context);
    final value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectRow<int>(
          title: l.notification,
          subtitle: !context.app.settings.remind
              ? l.remindOff
              : widget.hasTime
              ? null
              : l.remindNeedsTime,
          padding: const EdgeInsets.symmetric(vertical: 8),
          options: [
            // Eine andere Zeit (z. B. schon selbst eingetragen) bleibt sichtbar und wählbar.
            for (final m in ({..._presets, if (!_custom) ?value}.toList()..sort())) (m, f.remindLabel(m)),
            (_customOption, l.remindCustom),
          ],
          value: _custom ? _customOption : value ?? remindNone,
          onChanged: _pick,
        ),
        if (_custom)
          AppField(
            label: l.remindMinutes,
            controller: _minutes,
            hint: '20',
            maxLength: 5,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: _typed,
          ),
        if (widget.error case final e?) SheetError(e),
      ],
    );
  }
}
