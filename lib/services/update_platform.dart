import 'dart:io';

import 'package:flutter/services.dart';

import 'update_manifest.dart';

/// Der letzte Schritt eines Updates – das Einzige, worin sich Windows und Android unterscheiden.
/// Prüfen, Laden und die Signaturprüfung macht für beide der `Updater`.
abstract class UpdatePlatform {
  /// Die Datei für dieses Gerät; `null`, wenn das Release keine dafür hat.
  UpdateFile? fileOf(UpdateManifest manifest);

  /// Was für diese Datei unterschrieben sein muss (siehe [signedMessage]).
  List<int> message(String version, List<int> sha256);

  /// Unter diesem Namen wird der Download gespeichert.
  String fileName(String version);

  /// Ordner für den Download.
  Future<Directory> downloadDir();

  /// Muss der Nutzer die Installation im Fenster des Systems bestätigen?
  bool get asksUser;

  /// Vor dem Download: Darf die App überhaupt installieren? `false` = der Nutzer hat abgelehnt.
  Future<bool> prepare();

  /// Startet die geprüfte Datei. `false` = der Nutzer hat abgebrochen, die App läuft weiter.
  Future<bool> launch(File file);
}

/// Windows: Der Installer läuft ohne Fragen und ersetzt die App.
class WindowsUpdate implements UpdatePlatform {
  const WindowsUpdate({this._tempDir, this._launch});

  static const _tempPrefix = 'todo-planer-update-';

  final Future<Directory> Function()? _tempDir;
  final Future<void> Function(String installer)? _launch;

  /// Nur die mit dem Installer installierte App aktualisiert sich selbst – daneben liegt dann
  /// `unins000.exe`. Entpackte ZIPs und Entwickler-Builds bleiben unberührt.
  static bool get installed {
    final exe = File(Platform.resolvedExecutable);
    return Platform.isWindows && File('${exe.parent.path}${Platform.pathSeparator}unins000.exe').existsSync();
  }

  /// Räumt die Installer früherer Updates weg (sie liegen nach dem Neustart noch im Temp-Ordner).
  static void removeOldDownloads() {
    try {
      for (final e in Directory.systemTemp.listSync()) {
        if (e is Directory && e.uri.pathSegments.lastWhere((s) => s.isNotEmpty).startsWith(_tempPrefix)) {
          e.deleteSync(recursive: true);
        }
      }
    } on FileSystemException {
      // Gesperrt oder schon weg – dann eben beim nächsten Start.
    }
  }

  @override
  UpdateFile? fileOf(UpdateManifest manifest) => manifest.windows;

  @override
  List<int> message(String version, List<int> sha256) => signedMessage(version, sha256);

  @override
  String fileName(String version) => 'todo-planer-$version-setup.exe';

  @override
  Future<Directory> downloadDir() => _tempDir?.call() ?? Directory.systemTemp.createTemp(_tempPrefix);

  @override
  bool get asksUser => false;

  @override
  Future<bool> prepare() async => true;

  @override
  Future<bool> launch(File file) async {
    await (_launch ?? _runInstaller)(file.path);
    return true;
  }

  /// Startet den Installer ohne Fragen (nur ein Fortschrittsfenster) und beendet die App,
  /// damit ihre Dateien ersetzt werden können. Der Installer startet danach die neue Version.
  static Future<void> _runInstaller(String installer) async {
    await Process.start(installer, const ['/SILENT', '/NORESTART'], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// Android: Die App übergibt die geprüfte APK an den Installer des Systems; dort tippt der Nutzer
/// auf „Aktualisieren“. Die Gegenseite ist `AppUpdate.kt`.
class AndroidUpdate implements UpdatePlatform {
  const AndroidUpdate([this._channel = const MethodChannel('todo_liste/update')]);

  final MethodChannel _channel;

  /// Ist das die veröffentlichte App (richtige App-ID, mit dem Release-Schlüssel signiert)?
  Future<bool> isReleaseApp() async {
    final info = await _channel.invokeMapMethod<String, Object?>('info');
    return info?['package'] == releaseAppId && info?['cert'] == releaseCertSha256;
  }

  /// Räumt die APKs früherer Updates aus dem Cache der App.
  Future<void> removeOldDownloads() async {
    final dir = await downloadDir();
    await for (final e in dir.list()) {
      await e.delete(recursive: true);
    }
  }

  @override
  UpdateFile? fileOf(UpdateManifest manifest) => manifest.android;

  @override
  List<int> message(String version, List<int> sha256) => signedMessage(version, sha256, android: true);

  @override
  String fileName(String version) => 'todo-planer-$version.apk';

  /// Ein Ordner im Cache der App – nur ihn gibt der FileProvider an den Installer weiter.
  @override
  Future<Directory> downloadDir() async =>
      Directory((await _channel.invokeMethod<String>('dir'))!).create(recursive: true);

  @override
  bool get asksUser => true;

  /// Fehlt die Erlaubnis „Unbekannte Apps installieren“, öffnet Android die Seite dafür und die App
  /// wartet, bis der Nutzer zurückkommt.
  @override
  Future<bool> prepare() async =>
      await _channel.invokeMethod<bool>('canInstall') == true ||
      await _channel.invokeMethod<bool>('requestPermission') == true;

  /// Öffnet den Installer. Bestätigt der Nutzer, ersetzt Android die App und beendet sie dabei –
  /// eine Antwort kommt also nur, wenn er abgebrochen hat (`false`) oder Android die APK nicht
  /// installieren konnte (Fehler).
  @override
  Future<bool> launch(File file) async => await _channel.invokeMethod<bool>('install', file.path) == true;
}
