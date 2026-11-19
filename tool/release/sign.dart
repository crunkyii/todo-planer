// Signiert den Windows-Installer und die Android-APK für das Auto-Update und schreibt `latest.json`.
//
//   dart run tool/release/sign.dart keygen
//       Erzeugt einmalig das Schlüsselpaar. Der private Schlüssel landet außerhalb des Repos
//       (siehe [keyFile]), der öffentliche wird ausgegeben und gehört in `lib/services/update_manifest.dart`.
//
//   dart run tool/release/sign.dart sign <installer.exe> <version> [<app.apk>]
//       Schreibt `latest.json` neben den Installer. Mit APK bekommt die Datei zusätzlich den Eintrag
//       `android`; ohne ihn finden Android-Apps in diesem Release kein Update.
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

/// Adresse und Signatur von [file] im Release [version] – so, wie sie in `latest.json` stehen.
Future<Map<String, String>> _entry(File file, String version, SimpleKeyPair pair, {bool android = false}) async {
  final hash = await Sha256().hash(file.readAsBytesSync());
  final signature = await _ed.sign(signedMessage(version, hash.bytes, android: android), keyPair: pair);
  return {
    'url': '${releaseDownloadBase}v$version/${file.uri.pathSegments.last}',
    'signature': base64Encode(signature.bytes),
  };
}

/// Prüft [entry] gegen [file], wie es die App nach dem Download macht: mit dem eingebauten Schlüssel.
Future<void> _verify(UpdateFile? entry, File file, String version, {bool android = false}) async {
  final hash = await Sha256().hash(file.readAsBytesSync());
  final ok =
      entry != null &&
      await _ed.verify(
        signedMessage(version, hash.bytes, android: android),
        signature: Signature(
          entry.signature,
          publicKey: SimplePublicKey(base64Decode(updatePublicKey), type: KeyPairType.ed25519),
        ),
      );
  if (!ok) throw StateError('Die Signatur für ${file.path} würde in der App durchfallen.');
}

File _existing(String path, String ending) {
  final file = File(path);
  if (!path.toLowerCase().endsWith(ending)) throw ArgumentError('Erwartet eine $ending-Datei: $path');
  if (!file.existsSync()) throw ArgumentError('Datei fehlt: $path');
  return file;
}

Future<void> _sign(String installerPath, String version, String? apkPath) async {
  if (parseVersion(version) == null) throw ArgumentError('Ungültige Version: $version');
  final installer = _existing(installerPath, '.exe');
  final apk = apkPath == null ? null : _existing(apkPath, '.apk');
  final pair = await _loadKey();
  // Mit einem anderen Schlüssel als dem in der App würde jede installierte App das Update ablehnen.
  final public = base64Encode((await pair.extractPublicKey()).bytes);
  if (public != updatePublicKey) {
    throw StateError('Der Schlüssel passt nicht zu updatePublicKey in lib/services/update_manifest.dart.');
  }
  // Version, url und signature oben gehören zum Windows-Installer – so lesen es auch ältere Apps.
  final manifest = {
    'version': version,
    ...await _entry(installer, version, pair),
    'android': ?(apk == null ? null : await _entry(apk, version, pair, android: true)),
  };
  final out = File('${installer.parent.path}${Platform.pathSeparator}latest.json');
  final body = '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
  // So liest und prüft sie auch die App – was hier nicht durchgeht, käme dort nie an.
  final parsed = UpdateManifest.parse(body);
  await _verify(parsed.windows, installer, version);
  if (apk != null) await _verify(parsed.android, apk, version, android: true);
  out.writeAsStringSync(body);
  stdout.writeln('Geschrieben: ${out.path}${apk == null ? ' (ohne Android)' : ''}');
}

Future<void> main(List<String> args) async {
  switch (args) {
    case ['keygen']:
      await _keygen();
    case ['sign', final installer, final version]:
      await _sign(installer, version, null);
    case ['sign', final installer, final version, final apk]:
      await _sign(installer, version, apk);
    default:
      stderr.writeln('Aufruf: sign.dart keygen | sign <installer.exe> <version> [<app.apk>]');
      exitCode = 64;
  }
}
