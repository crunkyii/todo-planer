import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo_liste/services/update_manifest.dart';
import 'package:todo_liste/services/update_platform.dart';
import 'package:todo_liste/services/updater.dart';

const _manifest = 'https://example.test/latest.json';
const _installerUrl = '${releaseDownloadBase}v1.1.0/todo-planer-1.1.0-setup.exe';
final _installer = utf8.encode('Das ist der Installer');

/// Test-Schlüsselpaar (nicht der echte Release-Schlüssel).
late SimpleKeyPair _key;
late String _publicKey;

Future<String> _signature(String version, List<int> bytes, {SimpleKeyPair? key}) async {
  final hash = await Sha256().hash(bytes);
  final sig = await Ed25519().sign(signedMessage(version, hash.bytes), keyPair: key ?? _key);
  return base64Encode(sig.bytes);
}

Future<String> _manifestBody({String version = '1.1.0', String url = _installerUrl, String? signature}) async =>
    jsonEncode({'version': version, 'url': url, 'signature': signature ?? await _signature(version, _installer)});

/// Updater mit falschem Netz: [manifest] ist die Antwort auf `latest.json`, [installer] die Datei.
({Updater updater, List<String> launched, List<Uri> requests}) _make({
  String? manifest,
  List<int>? installer,
  int status = 200,
  String current = '1.0.0',
  bool supported = true,
}) {
  final launched = <String>[];
  final requests = <Uri>[];
  final client = MockClient((req) async {
    requests.add(req.url);
    if (req.url.toString() == _manifest) return http.Response(manifest ?? '', manifest == null ? 404 : status);
    return http.Response.bytes(installer ?? _installer, status);
  });
  final updater = Updater(
    currentVersion: current,
    supported: supported,
    client: client,
    manifestUrl: Uri.parse(_manifest),
    publicKey: _publicKey,
    platform: WindowsUpdate(
      tempDir: () => Directory.systemTemp.createTemp('updater-test-'),
      launch: (path) async => launched.add(path),
    ),
  );
  return (updater: updater, launched: launched, requests: requests);
}

void main() {
  setUpAll(() async {
    _key = await Ed25519().newKeyPair();
    _publicKey = base64Encode((await _key.extractPublicKey()).bytes);
  });

  group('Versionen', () {
    test('vergleicht Zahl für Zahl, nicht als Text', () {
      expect(isNewer('1.10.0', '1.9.9'), isTrue);
      expect(isNewer('1.0.1', '1.0.0+7'), isTrue);
      expect(isNewer('1.0.0', '1.0.0'), isFalse);
      expect(isNewer('0.9.9', '1.0.0'), isFalse);
    });

    test('unlesbare Versionen sind nie neuer', () {
      expect(isNewer('2', '1.0.0'), isFalse);
      expect(isNewer('1.2.x', '1.0.0'), isFalse);
      expect(isNewer('9.9.9', 'unbekannt'), isFalse);
      expect(parseVersion('1.-2.3'), isNull);
      expect(parseVersion(r'1.2.3+..\x'), isNull);
      expect(parseVersion('1.2.3\n'), isNull);
      expect(parseVersion('1.2.3+4'), [1, 2, 3]);
    });
  });

  group('latest.json', () {
    final sig = base64Encode(List.filled(64, 1));

    test('nimmt nur Adressen der eigenen Release-Seite', () {
      for (final url in [
        'https://evil.test/setup.exe',
        'http://github.com/crunkyii/todo-planer/releases/download/v1/setup.exe',
        'https://github.com/crunkyii/todo-planer/releases/download/../../../other/setup.exe',
        'https://github.com/crunkyii/todo-planer-evil/releases/download/v1/setup.exe',
        // „%2e%2e“ löst Uri.parse zu „..“ auf – der Pfad landet dann in einem fremden Repository.
        '$releaseDownloadBase%2e%2e/%2e%2e/%2e%2e/%2e%2e/evil/repo/releases/download/v1/setup.exe',
        '${releaseDownloadBase}v1/setup.exe?x=1',
        '${releaseDownloadBase}v1/setup.exe#x',
        'https://github.com:444/crunkyii/todo-planer/releases/download/v1/setup.exe',
        'https://github.com@evil.test/crunkyii/todo-planer/releases/download/v1/setup.exe',
      ]) {
        expect(
          () => UpdateManifest.parse(jsonEncode({'version': '1.1.0', 'url': url, 'signature': sig})),
          throwsFormatException,
          reason: url,
        );
      }
    });

    test('lehnt fehlende Felder, falsche Typen und kurze Signaturen ab', () {
      for (final body in [
        '[]',
        '{}',
        jsonEncode({'version': 1, 'url': _installerUrl, 'signature': sig}),
        jsonEncode({'version': '1.1.0', 'url': _installerUrl}),
        jsonEncode({'version': '1.1.0', 'url': _installerUrl, 'signature': 'AAAA'}),
        jsonEncode({'version': '1.1.0', 'url': _installerUrl, 'signature': 'kein base64!'}),
      ]) {
        expect(() => UpdateManifest.parse(body), throwsFormatException, reason: body);
      }
    });
  });

  group('Prüfen', () {
    test('findet eine neuere Version', () async {
      final t = _make(manifest: await _manifestBody());
      await t.updater.check();
      expect(t.updater.state, UpdateState.available);
      expect(t.updater.found?.version, '1.1.0');
    });

    test('gleiche oder ältere Version: aktuell', () async {
      for (final current in ['1.1.0', '2.0.0']) {
        final t = _make(manifest: await _manifestBody(), current: current);
        await t.updater.check();
        expect(t.updater.state, UpdateState.upToDate, reason: current);
        expect(t.updater.found, isNull);
      }
    });

    test('offline, 404 oder kaputte Datei: fehlgeschlagen, kein Absturz', () async {
      for (final t in [_make(), _make(manifest: 'kein json'), _make(manifest: await _manifestBody(), status: 500)]) {
        await t.updater.check();
        expect(t.updater.state, UpdateState.failed);
      }
    });

    test('nicht unterstützte Geräte fragen gar nicht erst', () async {
      final t = _make(manifest: await _manifestBody(), supported: false);
      await t.updater.check();
      await t.updater.install();
      expect(t.requests, isEmpty);
      expect(t.updater.state, UpdateState.idle);
    });

    test('Prüfung von selbst beim Start scheitert leise', () async {
      final t = _make();
      await t.updater.check(silent: true);
      expect(t.updater.state, UpdateState.idle);
    });

    test('Antwort nach dem Schließen der App wirft nicht', () async {
      final t = _make(manifest: await _manifestBody());
      final running = t.updater.check();
      t.updater.dispose();
      await running;
    });

    test('nach einem Fehler geht es beim nächsten Versuch weiter', () async {
      final t = _make(manifest: await _manifestBody(), installer: utf8.encode('kaputt'));
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.failed);
      await t.updater.check();
      expect(t.updater.state, UpdateState.available);
    });

    test('zu große latest.json wird abgebrochen', () async {
      final t = _make(manifest: ' ' * (Updater.maxManifestBytes + 1));
      await t.updater.check();
      expect(t.updater.state, UpdateState.failed);
    });
  });

  group('Installieren', () {
    test('lädt, prüft die Signatur und startet genau diese Datei', () async {
      final t = _make(manifest: await _manifestBody());
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.installing);
      expect(t.launched, hasLength(1));
      expect(t.launched.single, endsWith('todo-planer-1.1.0-setup.exe'));
      expect(File(t.launched.single).readAsBytesSync(), _installer);
      expect(t.requests.last.toString(), _installerUrl);
    });

    test('veränderte Datei wird nicht gestartet', () async {
      final t = _make(manifest: await _manifestBody(), installer: utf8.encode('Das ist ein anderer Installer'));
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.failed);
      expect(t.launched, isEmpty);
    });

    test('Signatur mit fremdem Schlüssel wird nicht gestartet', () async {
      final other = await Ed25519().newKeyPair();
      final t = _make(
        manifest: await _manifestBody(signature: await _signature('1.1.0', _installer, key: other)),
      );
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.failed);
      expect(t.launched, isEmpty);
    });

    test('alte, echt signierte Datei unter neuer Versionsnummer wird nicht gestartet', () async {
      // Die Signatur gilt für 1.0.5 – in latest.json steht aber 1.1.0.
      final t = _make(manifest: await _manifestBody(signature: await _signature('1.0.5', _installer)));
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.failed);
      expect(t.launched, isEmpty);
    });

    test('Fehler beim Download: fehlgeschlagen, nichts gestartet', () async {
      final t = _make(manifest: await _manifestBody());
      await t.updater.check();
      final broken = Updater(
        currentVersion: '1.0.0',
        supported: true,
        client: MockClient((_) async => http.Response('', 503)),
        publicKey: _publicKey,
        platform: WindowsUpdate(launch: (path) async => t.launched.add(path)),
      )..found = t.updater.found;
      broken.state = UpdateState.available;
      await broken.install();
      expect(broken.state, UpdateState.failed);
      expect(t.launched, isEmpty);
    });

    test('ohne vorherige Prüfung passiert nichts', () async {
      final t = _make(manifest: await _manifestBody());
      await t.updater.install();
      expect(t.requests, isEmpty);
      expect(t.launched, isEmpty);
    });

    test('der eingebaute öffentliche Schlüssel ist ein Ed25519-Schlüssel', () {
      expect(base64Decode(updatePublicKey), hasLength(32));
    });
  });
}
