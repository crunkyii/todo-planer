import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'update_manifest.dart';

enum UpdateState { idle, checking, upToDate, available, downloading, installing, failed }

/// Auto-Update für die installierte Windows-App: fragt `latest.json` am neuesten GitHub-Release ab,
/// lädt den Installer, prüft seine Signatur und startet ihn. Ohne gültige Signatur wird nichts gestartet.
class Updater extends ChangeNotifier {
  Updater({
    required this.currentVersion,
    required this.supported,
    http.Client? client,
    Uri? manifestUrl,
    String publicKey = updatePublicKey,
    Future<Directory> Function()? tempDir,
    Future<void> Function(String installer)? launch,
  }) : _client = client ?? http.Client(),
       _manifestUrl = manifestUrl ?? latestManifestUrl,
       _publicKey = SimplePublicKey(base64Decode(publicKey), type: KeyPairType.ed25519),
       _tempDir = tempDir ?? (() => Directory.systemTemp.createTemp(_tempPrefix)),
       _launch = launch ?? _runInstaller;

  /// Updater für dieses Gerät. Nur die mit dem Installer installierte Windows-App aktualisiert sich
  /// selbst – daneben liegt dann `unins000.exe`. Entpackte ZIPs und Entwickler-Builds bleiben unberührt.
  factory Updater.forDevice(String currentVersion) {
    final exe = File(Platform.resolvedExecutable);
    final installed =
        Platform.isWindows && File('${exe.parent.path}${Platform.pathSeparator}unins000.exe').existsSync();
    if (installed) _removeOldDownloads();
    return Updater(currentVersion: currentVersion, supported: installed);
  }

  static const _tempPrefix = 'todo-planer-update-';

  /// Räumt die Installer früherer Updates weg (sie liegen nach dem Neustart noch im Temp-Ordner).
  static void _removeOldDownloads() {
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

  /// Größer wird weder `latest.json` noch der Installer angenommen.
  static const maxManifestBytes = 64 * 1024;
  static const maxInstallerBytes = 300 * 1024 * 1024;
  static const _timeout = Duration(seconds: 20);

  final String currentVersion;

  /// `false` = diese App aktualisiert sich nicht selbst (Android, Linux, entpacktes ZIP).
  final bool supported;

  final http.Client _client;
  final Uri _manifestUrl;
  final SimplePublicKey _publicKey;
  final Future<Directory> Function() _tempDir;
  final Future<void> Function(String installer) _launch;

  UpdateState state = UpdateState.idle;

  /// Die gefundene neuere Version (ab [UpdateState.available]).
  UpdateManifest? found;

  /// Fortschritt des Downloads, 0–1.
  double progress = 0;

  bool get busy => state == UpdateState.checking || state == UpdateState.downloading || state == UpdateState.installing;

  bool _disposed = false;

  void _set(UpdateState s) {
    // Eine Antwort kann noch eintreffen, nachdem die App geschlossen wurde.
    if (_disposed) return;
    state = s;
    notifyListeners();
  }

  /// Fragt nach einer neueren Version. Fehler (offline, kaputte Datei) enden in [UpdateState.failed] –
  /// bei [silent] (Prüfung von selbst beim Start) ohne Meldung wieder in [UpdateState.idle].
  Future<void> check({bool silent = false}) async {
    if (!supported || busy) return;
    _set(UpdateState.checking);
    try {
      final body = await _download(_manifestUrl, maxManifestBytes);
      final m = UpdateManifest.parse(utf8.decode(body));
      if (isNewer(m.version, currentVersion)) {
        found = m;
        _set(UpdateState.available);
      } else {
        found = null;
        _set(UpdateState.upToDate);
      }
    } on Object catch (e) {
      debugPrint('Update-Prüfung fehlgeschlagen: ${e.runtimeType}');
      _set(silent ? UpdateState.idle : UpdateState.failed);
    }
  }

  /// Lädt die gefundene Version, prüft die Signatur und startet den Installer.
  /// Der Installer beendet die App und startet danach die neue Version.
  Future<void> install() async {
    final m = found;
    if (!supported || m == null || state != UpdateState.available) return;
    progress = 0;
    _set(UpdateState.downloading);
    try {
      final bytes = await _download(m.url, maxInstallerBytes, onProgress: _onProgress);
      final hash = await Sha256().hash(bytes);
      final ok = await Ed25519().verify(
        signedMessage(m.version, hash.bytes),
        signature: Signature(m.signature, publicKey: _publicKey),
      );
      if (!ok) throw const FormatException('Signatur passt nicht');
      final dir = await _tempDir();
      final file = File('${dir.path}${Platform.pathSeparator}todo-planer-${m.version}-setup.exe');
      await file.writeAsBytes(bytes, flush: true);
      _set(UpdateState.installing);
      await _launch(file.path);
    } on Object catch (e) {
      debugPrint('Update fehlgeschlagen: ${e.runtimeType}');
      _set(UpdateState.failed);
    }
  }

  void _onProgress(double p) {
    // Nur ganze Prozent melden, sonst zeichnet die Oberfläche bei jedem Datenpaket neu.
    if ((p * 100).floor() == (progress * 100).floor()) return;
    progress = p;
    if (!_disposed) notifyListeners();
  }

  /// Lädt [url] in den Speicher und bricht ab, sobald mehr als [limit] Bytes kommen.
  Future<Uint8List> _download(Uri url, int limit, {void Function(double)? onProgress}) async {
    final res = await _client.send(http.Request('GET', url)).timeout(_timeout);
    if (res.statusCode != 200) {
      unawaited(res.stream.drain<void>().catchError((_) {}));
      throw HttpException('HTTP ${res.statusCode}');
    }
    final total = res.contentLength;
    if (total != null && total > limit) throw const HttpException('Datei zu groß');
    final out = BytesBuilder(copy: false);
    await for (final chunk in res.stream.timeout(_timeout)) {
      out.add(chunk);
      if (out.length > limit) throw const HttpException('Datei zu groß');
      if (total != null && total > 0) onProgress?.call(out.length / total);
    }
    return out.takeBytes();
  }

  /// Startet den Installer ohne Fragen (nur ein Fortschrittsfenster) und beendet die App,
  /// damit ihre Dateien ersetzt werden können. Der Installer startet danach die neue Version.
  static Future<void> _runInstaller(String installer) async {
    await Process.start(installer, const ['/SILENT', '/NORESTART'], mode: ProcessStartMode.detached);
    exit(0);
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
