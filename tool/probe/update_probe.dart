// Probe-App für das Android-Update: der ganze Weg am Handy – Erlaubnis, Download, Signaturprüfung,
// Installer – ohne die echte App und ohne ein echtes Release. Anleitung: docs/tests.md.
//
// Sie benutzt den echten `Updater` und den echten Android-Teil (`AppUpdate.kt`). Nur zwei Dinge sind
// anders: Statt GitHub antwortet der PC (tool/probe/serve.dart, über `adb reverse` als 127.0.0.1 am
// Handy erreichbar), und geprüft wird mit einem Wegwerf-Schlüssel statt mit dem echten.
// Gebaut wird sie als Debug-Version – also mit der App-ID der Test-Kopie und ohne deren Daten anzufassen.
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:todo_liste/services/update_platform.dart';
import 'package:todo_liste/services/updater.dart';

/// Öffentlicher Wegwerf-Schlüssel aus `serve.dart keygen` (`--dart-define=PROBE_KEY=…`).
const _key = String.fromEnvironment('PROBE_KEY');

/// Schickt jede Anfrage an den PC: Aus `https://github.com/…/latest.json` wird
/// `http://127.0.0.1:8765/latest.json`. Die Adressen in `latest.json` bleiben dabei die echten.
class _ToPc extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(http.Request(request.method, Uri.parse('http://127.0.0.1:8765/${request.url.pathSegments.last}')));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final info = await PackageInfo.fromPlatform();
  final updater = Updater(
    currentVersion: info.version,
    supported: true,
    platform: const AndroidUpdate(),
    client: _ToPc(),
    publicKey: _key,
  );
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ListenableBuilder(
              listenable: updater,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Text('Update-Probe ${info.version}', style: const TextStyle(fontSize: 22)),
                  Text('Zustand: ${updater.state.name} · ${(updater.progress * 100).floor()} %'),
                  if (updater.found case final found?) Text('Gefunden: ${found.version}'),
                  TextButton(onPressed: updater.check, child: const Text('Prüfen')),
                  TextButton(onPressed: updater.install, child: const Text('Installieren')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
