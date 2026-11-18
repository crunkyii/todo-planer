import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';

/// Unter den erledigten Aufgaben: Ältere erledigte liegen im Modus „Auf allen Geräten“ nur
/// noch online. Online lädt ein Tipp die nächsten nach, offline steht hier ein kurzer Hinweis.
/// Gibt es keine (oder sind alle nachgeladen), ist nichts zu sehen.
///
/// Muss unter einem `ListenableBuilder` auf Store und Sync stehen, damit es mitzählt.
class OlderDoneHint extends StatelessWidget {
  const OlderDoneHint({super.key, this.categoryId, this.dueDay});

  /// Nur die älteren dieser Kategorie …
  final String? categoryId;

  /// … oder dieses Abgabetags (`JJJJ-MM-TT`).
  final String? dueDay;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final l = context.l;
    final count = app.store.olderWaiting(categoryId: categoryId, dueDay: dueDay);
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Center(
        child: app.sync.canLoadOlder
            ? AppButton(
                kind: BtnKind.text,
                label: l.olderDoneLoad(count),
                loading: app.sync.loadingOlder,
                onTap: () async {
                  final ok = await app.sync.loadOlderDone(categoryId: categoryId, dueDay: dueDay);
                  if (!ok) app.snack.show(l.olderDoneFailed, icon: Ic.alert);
                },
              )
            : Text(
                l.olderDoneOffline(count),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Fs.meta, color: context.tok.sub),
              ),
      ),
    );
  }
}
