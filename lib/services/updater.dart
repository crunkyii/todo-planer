import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'update_manifest.dart';
import 'update_platform.dart';

enum UpdateState { idle, checking, upToDate, available, downloading, installing, failed }

/// Auto-Update für die installierte Windows-App und die veröffentlichte Android-App: fragt `latest.json`
/// am neuesten GitHub-Release ab, lädt die Datei für dieses Gerät, prüft ihre Signatur und übergibt sie
/// an [UpdatePlatform]. Ohne gültige Signatur wird nichts gestartet.
class Updater extends ChangeNotifier {
  Updater({
    required this.currentVersion,
    required this.supported,
    this._platform = const WindowsUpdate(),
    http.Client? client,
    Uri? manifestUrl,
    String publicKey = updatePublicKey,
  }) : _client = client ?? http.Client(),
       _manifestUrl = manifestUrl ?? latestManifestUrl,
       _publicKey = SimplePublicKey(base64Decode(publicKey), type: KeyPairType.ed25519);

  /// Updater für dieses Gerät. Selbst aktualisieren sich nur die mit dem Installer installierte
  /// Windows-App und die veröffentlichte Android-App.
  static Future<Updater> forDevice(String currentVersion) async {
    if (Platform.isAndroid) return forAndroid(currentVersion, const AndroidUpdate());
    final installed = WindowsUpdate.installed;
    if (installed) WindowsUpdate.removeOldDownloads();
    return Updater(currentVersion: currentVersion, supported: installed);
  }

  /// Android: Die Test-Kopie (`….debug`) und selbst gebaute Apps bleiben unberührt.
  static Future<Updater> forAndroid(String currentVersion, AndroidUpdate android) async {
    var release = false;
    try {
      release = await android.isReleaseApp();
      if (release) await android.removeOldDownloads();
    } on Object catch (e) {
      // Aufräumen gescheitert oder keine Antwort vom System – der Start der App hängt nicht daran.
      debugPrint('Update-Vorbereitung fehlgeschlagen: ${e.runtimeType}');
    }
    return Updater(currentVersion: currentVersion, supported: release, platform: android);
  }

  /// Größer wird weder `latest.json` noch die Update-Datei angenommen.
  static const maxManifestBytes = 64 * 1024;
  static const maxInstallerBytes = 300 * 1024 * 1024;
  static const _timeout = Duration(seconds: 20);

  final String currentVersion;

  /// `false` = diese App aktualisiert sich nicht selbst (Linux, entpacktes ZIP, Test-Kopie am Handy).
  final bool supported;

  final UpdatePlatform _platform;
  final http.Client _client;
  final Uri _manifestUrl;
  final SimplePublicKey _publicKey;

  UpdateState state = UpdateState.idle;

  /// Die gefundene neuere Version (ab [UpdateState.available]).
  UpdateManifest? found;

  /// Fortschritt des Downloads, 0–1.
  double progress = 0;

  /// Bestätigt der Nutzer die Installation in einem Fenster des Systems (Android)?
  bool get asksUser => _platform.asksUser;

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
      final body = BytesBuilder(copy: false);
      await _get(_manifestUrl, maxManifestBytes).forEach(body.add);
      final m = UpdateManifest.parse(utf8.decode(body.takeBytes()));
      // Ein Release ohne Datei für dieses Gerät ist hier kein Update.
      if (isNewer(m.version, currentVersion) && _platform.fileOf(m) != null) {
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

  /// Lädt die gefundene Version, prüft die Signatur und startet die Installation. Unter Windows beendet
  /// der Installer die App und startet die neue Version; unter Android bestätigt der Nutzer im Fenster
  /// des Systems. Lehnt er ab oder bricht ab, steht das Update weiter bereit – ohne Fehlermeldung.
  Future<void> install() async {
    final m = found;
    final source = m == null ? null : _platform.fileOf(m);
    if (!supported || m == null || source == null || state != UpdateState.available) return;
    progress = 0;
    _set(UpdateState.downloading);
    File? file;
    var launched = false;
    try {
      if (!await _platform.prepare()) return _set(UpdateState.available);
      final dir = await _platform.downloadDir();
      file = File('${dir.path}${Platform.pathSeparator}${_platform.fileName(m.version)}');
      final hash = await _downloadTo(file, source.url);
      final ok = await Ed25519().verify(
        _platform.message(m.version, hash),
        signature: Signature(source.signature, publicKey: _publicKey),
      );
      if (!ok) throw const FormatException('Signatur passt nicht');
      _set(UpdateState.installing);
      launched = await _platform.launch(file);
      if (!launched) _set(UpdateState.available);
    } on Object catch (e) {
      debugPrint('Update fehlgeschlagen: ${e.runtimeType}');
      _set(UpdateState.failed);
    } finally {
      // Nicht geprüft oder nicht installiert: Die Datei soll nicht liegen bleiben.
      if (!launched && file != null) await _delete(file);
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Gesperrt – der nächste Start räumt auf.
    }
  }

  void _onProgress(double p) {
    // Nur ganze Prozent melden, sonst zeichnet die Oberfläche bei jedem Datenpaket neu.
    if ((p * 100).floor() == (progress * 100).floor()) return;
    progress = p;
    if (!_disposed) notifyListeners();
  }

  /// Lädt [url] Stück für Stück nach [file] und liefert die SHA-256-Prüfsumme dessen, was geschrieben
  /// wurde. So liegt auch eine große APK nie ganz im Arbeitsspeicher.
  Future<List<int>> _downloadTo(File file, Uri url) async {
    final out = await file.open(mode: FileMode.write);
    final sha = Sha256().newHashSink();
    try {
      await for (final chunk in _get(url, maxInstallerBytes, onProgress: _onProgress)) {
        await out.writeFrom(chunk);
        sha.add(chunk);
      }
      await out.flush();
    } finally {
      await out.close();
    }
    sha.close();
    return (await sha.hash()).bytes;
  }

  /// Lädt [url] und bricht ab, sobald mehr als [limit] Bytes kommen oder länger nichts kommt.
  Stream<List<int>> _get(Uri url, int limit, {void Function(double)? onProgress}) async* {
    final res = await _client.send(http.Request('GET', url)).timeout(_timeout);
    if (res.statusCode != 200) {
      unawaited(res.stream.drain<void>().catchError((_) {}));
      throw HttpException('HTTP ${res.statusCode}');
    }
    final total = res.contentLength;
    if (total != null && total > limit) throw const HttpException('Datei zu groß');
    var got = 0;
    await for (final chunk in res.stream.timeout(_timeout)) {
      got += chunk.length;
      if (got > limit) throw const HttpException('Datei zu groß');
      if (total != null && total > 0) onProgress?.call(got / total);
      yield chunk;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
