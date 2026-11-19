// Gegenstück zur Probe-App (tool/probe/update_probe.dart): spielt am PC die Release-Seite.
//
//   dart run tool/probe/serve.dart keygen
//       Legt einen Wegwerf-Schlüssel in build/probe/ an und gibt den öffentlichen Teil aus
//       (für `--dart-define=PROBE_KEY=…`). Hat nichts mit dem echten Signier-Schlüssel zu tun.
//
//   dart run tool/probe/serve.dart serve <neue.apk> <version> [kaputt]
//       Signiert die APK mit dem Wegwerf-Schlüssel und bietet `latest.json` und die APK auf
//       127.0.0.1:8765 an. Mit „kaputt“ kommt eine veränderte APK – die App darf den Installer
//       dann nicht öffnen.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:todo_liste/services/update_manifest.dart';

final _ed = Ed25519();
final _keyFile = File('build/probe/probe.key');

Future<Map<String, String>> _entry(
  String name,
  List<int> bytes,
  String version,
  SimpleKeyPair pair, {
  bool android = false,
}) async {
  final hash = await Sha256().hash(bytes);
  final signature = await _ed.sign(signedMessage(version, hash.bytes, android: android), keyPair: pair);
  return {'url': '${releaseDownloadBase}v$version/$name', 'signature': base64Encode(signature.bytes)};
}

Future<void> _keygen() async {
  final pair = await _ed.newKeyPair();
  _keyFile.parent.createSync(recursive: true);
  _keyFile.writeAsStringSync(base64Encode(await pair.extractPrivateKeyBytes()));
  stdout.writeln(base64Encode((await pair.extractPublicKey()).bytes));
}

Future<void> _serve(String apkPath, String version, {required bool broken}) async {
  final pair = await _ed.newKeyPairFromSeed(base64Decode(_keyFile.readAsStringSync().trim()));
  final apk = File(apkPath).readAsBytesSync();
  final apkName = 'todo-planer-$version.apk';
  // Oben muss ein Windows-Eintrag stehen, sonst ist die Datei ungültig – hier nur ein Platzhalter.
  final manifest = jsonEncode({
    'version': version,
    ...await _entry('todo-planer-$version-setup.exe', const [0], version, pair),
    'android': await _entry(apkName, apk, version, pair, android: true),
  });
  UpdateManifest.parse(manifest);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8765);
  stdout.writeln('Bereit auf 127.0.0.1:8765 – Version $version${broken ? ' (veränderte APK)' : ''}. Ende mit Strg+C.');
  await for (final request in server) {
    final name = request.uri.pathSegments.lastOrNull;
    stdout.writeln('${request.method} ${request.uri.path}');
    if (name == 'latest.json') {
      request.response.write(manifest);
    } else if (name == apkName) {
      request.response.contentLength = apk.length;
      // Ein einziges verändertes Byte reicht, damit die Signatur nicht mehr passt.
      request.response.add(broken ? [apk.first ^ 1, ...apk.skip(1)] : apk);
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }
}

Future<void> main(List<String> args) async {
  switch (args) {
    case ['keygen']:
      await _keygen();
    case ['serve', final apk, final version]:
      await _serve(apk, version, broken: false);
    case ['serve', final apk, final version, 'kaputt']:
      await _serve(apk, version, broken: true);
    default:
      stderr.writeln('Aufruf: serve.dart keygen | serve <neue.apk> <version> [kaputt]');
      exitCode = 64;
  }
}
