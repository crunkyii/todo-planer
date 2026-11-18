// Signiert den Windows-Installer für das Auto-Update und schreibt `latest.json`.
//
//   dart run tool/release/sign.dart keygen
//       Erzeugt einmalig das Schlüsselpaar. Der private Schlüssel landet außerhalb des Repos
//       (siehe [keyFile]), der öffentliche wird ausgegeben und gehört in `lib/services/update_manifest.dart`.
//
//   dart run tool/release/sign.dart sign <installer.exe> <version>
//       Schreibt `latest.json` neben den Installer.
//
// Der private Schlüssel darf nie ins Repo, in ein Log oder in eine Ausgabe.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:todo_liste/services/update_manifest.dart';

final _ed = Ed25519();

/// Ablageort des privaten Schlüssels: `TODO_PLANER_SIGNING_KEY` oder `~/.todo-planer/update-signing.key`.
File keyFile() {
  final env = Platform.environment;
  final custom = env['TODO_PLANER_SIGNING_KEY'];
  if (custom != null && custom.isNotEmpty) return File(custom);
  final home = env['USERPROFILE'] ?? env['HOME'];
  if (home == null) throw StateError('Kein Benutzerordner gefunden – TODO_PLANER_SIGNING_KEY setzen.');
  return File('$home${Platform.pathSeparator}.todo-planer${Platform.pathSeparator}update-signing.key');
}

Future<void> _keygen() async {
  final file = keyFile();
  if (file.existsSync()) {
    stderr.writeln('Es gibt schon einen Schlüssel: ${file.path}\nNicht überschrieben.');
    exitCode = 1;
    return;
  }
  final pair = await _ed.newKeyPair();
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(base64Encode(await pair.extractPrivateKeyBytes()), flush: true);
  stdout.writeln('Privater Schlüssel gespeichert: ${file.path}');
  stdout.writeln(
    'Öffentlicher Schlüssel (für updatePublicKey): ${base64Encode((await pair.extractPublicKey()).bytes)}',
  );
}

Future<SimpleKeyPair> _loadKey() async {
  final file = keyFile();
  if (!file.existsSync()) throw StateError('Kein Schlüssel unter ${file.path} – zuerst „keygen“ ausführen.');
  return _ed.newKeyPairFromSeed(base64Decode(file.readAsStringSync().trim()));
}

Future<void> _sign(String installerPath, String version) async {
  if (parseVersion(version) == null) throw ArgumentError('Ungültige Version: $version');
  final installer = File(installerPath);
  final name = installer.uri.pathSegments.last;
  final hash = await Sha256().hash(installer.readAsBytesSync());
  final pair = await _loadKey();
  // Mit einem anderen Schlüssel als dem in der App würde jede installierte App das Update ablehnen.
  final public = base64Encode((await pair.extractPublicKey()).bytes);
  if (public != updatePublicKey) {
    throw StateError('Der Schlüssel passt nicht zu updatePublicKey in lib/services/update_manifest.dart.');
  }
  final signature = await _ed.sign(signedMessage(version, hash.bytes), keyPair: pair);
  final manifest = {
    'version': version,
    'url': '${releaseDownloadBase}v$version/$name',
    'signature': base64Encode(signature.bytes),
  };
  final out = File('${installer.parent.path}${Platform.pathSeparator}latest.json');
  final body = '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
  // So liest sie auch die App – was hier nicht durchgeht, käme dort nie an.
  UpdateManifest.parse(body);
  out.writeAsStringSync(body);
  stdout.writeln('Geschrieben: ${out.path}');
}

Future<void> main(List<String> args) async {
  switch (args) {
    case ['keygen']:
      await _keygen();
    case ['sign', final installer, final version]:
      await _sign(installer, version);
    default:
      stderr.writeln('Aufruf: sign.dart keygen | sign <installer.exe> <version>');
      exitCode = 64;
  }
}
