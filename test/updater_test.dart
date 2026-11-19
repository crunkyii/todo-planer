import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
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

Future<String> _signature(String version, List<int> bytes, {SimpleKeyPair? key, bool android = false}) async {
  final hash = await Sha256().hash(bytes);
  final sig = await Ed25519().sign(signedMessage(version, hash.bytes, android: android), keyPair: key ?? _key);
  return base64Encode(sig.bytes);
}

const _apkUrl = '${releaseDownloadBase}v1.1.0/todo-planer-1.1.0.apk';
final _apk = utf8.encode('Das ist die APK');

/// [android] `null` = alte Form ohne APK; sonst der Eintrag (fehlende Felder werden richtig ergänzt).
Future<String> _manifestBody({
  String version = '1.1.0',
  String url = _installerUrl,
  String? signature,
  Map<String, Object?>? android,
}) async => jsonEncode({
  'version': version,
  'url': url,
  'signature': signature ?? await _signature(version, _installer),
  if (android != null)
    'android': {'url': _apkUrl, 'signature': await _signature(version, _apk, android: true), ...android},
});

/// Updater wie am Handy: Das Netz ist falsch, statt Android antwortet [_FakeAndroid].
Future<({Updater updater, _FakeAndroid android, List<Uri> requests})> _makeAndroid({
  String? manifest,
  List<int>? apk,
  int apkStatus = 200,
  String package = releaseAppId,
  String? cert = releaseCertSha256,
  bool canInstall = true,
  bool grants = false,
  bool confirms = false,
}) async {
  final android = _FakeAndroid(
    package: package,
    cert: cert,
    canInstall: canInstall,
    grants: grants,
    confirms: confirms,
  );
  final requests = <Uri>[];
  final platform = AndroidUpdate(android.channel);
  // So entscheidet die App beim Start, ob sie sich selbst aktualisiert.
  final device = await Updater.forAndroid('1.0.0', platform);
  final client = MockClient((req) async {
    requests.add(req.url);
    if (req.url == latestManifestUrl) return http.Response(manifest ?? '', manifest == null ? 404 : 200);
    return http.Response.bytes(apk ?? _apk, apkStatus);
  });
  final updater = Updater(
    currentVersion: device.currentVersion,
    supported: device.supported,
    platform: platform,
    client: client,
    publicKey: _publicKey,
  );
  return (updater: updater, android: android, requests: requests);
}

/// Steht für `AppUpdate.kt`: beantwortet die Aufrufe der App und merkt sich, was geöffnet wurde.
class _FakeAndroid {
  _FakeAndroid({
    this.package = releaseAppId,
    this.cert = releaseCertSha256,
    this.canInstall = true,
    this.grants = false,
    this.confirms = false,
  }) {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, _answer);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }

  final channel = const MethodChannel('todo_liste/update');
  final dir = Directory.systemTemp.createTempSync('updater-android-');

  final String package;
  final String? cert;

  /// Hat die App die Erlaubnis „Unbekannte Apps installieren“?
  bool canInstall;

  /// Schaltet der Nutzer die Erlaubnis ein, wenn Android ihn danach fragt?
  final bool grants;

  /// Tippt der Nutzer im Installer auf „Aktualisieren“? Dann ersetzt Android die App – es kommt nie
  /// eine Antwort. Sonst hat er abgebrochen.
  final bool confirms;

  /// Meldet Android nach dem Bestätigen, dass die Installation gescheitert ist?
  var installError = false;

  var permissionAsked = 0;

  /// Was dem Installer übergeben wurde: Pfad und Inhalt der Datei in diesem Moment.
  final opened = <({String path, List<int> bytes})>[];
  final installerOpen = Completer<void>();

  Future<Object?> _answer(MethodCall call) async {
    switch (call.method) {
      case 'info':
        return {'package': package, 'cert': cert};
      case 'dir':
        return dir.path;
      case 'canInstall':
        return canInstall;
      case 'requestPermission':
        permissionAsked++;
        return canInstall = grants;
      case 'install':
        final path = call.arguments as String;
        opened.add((path: path, bytes: File(path).readAsBytesSync()));
        if (!installerOpen.isCompleted) installerOpen.complete();
        if (installError) throw PlatformException(code: 'install');
        return confirms ? Completer<Object?>().future : false;
    }
    throw MissingPluginException();
  }
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('alte Form ohne android bleibt gültig', () {
      final m = UpdateManifest.parse(jsonEncode({'version': '1.1.0', 'url': _installerUrl, 'signature': sig}));
      expect(m.windows.url.toString(), _installerUrl);
      expect(m.android, isNull);
    });

    test('mit android: Installer und APK stehen nebeneinander', () {
      final apkSig = base64Encode(List.filled(64, 2));
      final m = UpdateManifest.parse(
        jsonEncode({
          'version': '1.1.0',
          'url': _installerUrl,
          'signature': sig,
          'android': {'url': _apkUrl, 'signature': apkSig},
        }),
      );
      expect(m.windows.url.toString(), _installerUrl);
      expect(m.windows.signature, base64Decode(sig));
      expect(m.android?.url.toString(), _apkUrl);
      expect(m.android?.signature, base64Decode(apkSig));
    });

    test('android-Eintrag: fremde Adresse, fehlende Felder und falsche Typen fallen durch', () {
      for (final android in <Object?>[
        'apk',
        <Object?>[],
        <String, Object?>{},
        {'url': _apkUrl},
        {'url': _apkUrl, 'signature': 'AAAA'},
        {'url': 'https://evil.test/todo.apk', 'signature': sig},
        {'url': 'https://github.com/crunkyii/todo-planer-evil/releases/download/v1/todo.apk', 'signature': sig},
        {
          'url': '$releaseDownloadBase%2e%2e/%2e%2e/%2e%2e/%2e%2e/evil/repo/releases/download/v1/a.apk',
          'signature': sig,
        },
      ]) {
        expect(
          () => UpdateManifest.parse(
            jsonEncode({'version': '1.1.0', 'url': _installerUrl, 'signature': sig, 'android': android}),
          ),
          throwsFormatException,
          reason: '$android',
        );
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

    test('latest.json mit android: Windows lädt weiter den Installer', () async {
      final t = _make(manifest: await _manifestBody(android: {}));
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.installing);
      expect(t.updater.asksUser, isFalse);
      expect(t.requests.last.toString(), _installerUrl);
      expect(File(t.launched.single).readAsBytesSync(), _installer);
    });

    test('Windows nimmt die APK nicht als Installer an', () async {
      // Oben stehen Adresse und Signatur der APK – echt signiert, aber nur für Android.
      final t = _make(
        manifest: await _manifestBody(signature: await _signature('1.1.0', _apk, android: true), android: {}),
        installer: _apk,
      );
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.failed);
      expect(t.launched, isEmpty);
    });
  });

  group('Android', () {
    test('findet die neuere Version, lädt die APK und öffnet genau diese Datei im Installer', () async {
      final t = await _makeAndroid(manifest: await _manifestBody(android: {}), confirms: true);
      await t.updater.check();
      expect(t.updater.state, UpdateState.available);
      expect(t.updater.found?.version, '1.1.0');
      unawaited(t.updater.install());
      await t.android.installerOpen.future;
      expect(t.updater.state, UpdateState.installing);
      expect(t.updater.asksUser, isTrue);
      expect(t.requests.last.toString(), _apkUrl);
      final opened = t.android.opened.single;
      expect(opened.bytes, _apk);
      // Die Datei liegt direkt im Update-Ordner der App – nur den gibt der FileProvider frei.
      expect(File(opened.path).parent.path, t.android.dir.path);
      expect(opened.path, endsWith('todo-planer-1.1.0.apk'));
      expect(t.android.permissionAsked, 0);
    });

    test('Release ohne APK (alte latest.json): kein Update, nichts geladen', () async {
      final t = await _makeAndroid(manifest: await _manifestBody());
      await t.updater.check();
      expect(t.updater.state, UpdateState.upToDate);
      await t.updater.install();
      expect(t.requests, [latestManifestUrl]);
      expect(t.android.opened, isEmpty);
    });

    test('veränderte APK, fremder Schlüssel, alte APK unter neuer Nummer: Installer bleibt zu', () async {
      final other = await Ed25519().newKeyPair();
      final cases = {
        'veränderte APK': (apk: utf8.encode('Das ist eine andere APK'), signature: null),
        'fremder Schlüssel': (apk: null, signature: await _signature('1.1.0', _apk, key: other, android: true)),
        // Die Signatur gilt für 1.0.5 – in latest.json steht aber 1.1.0.
        'alte APK unter neuer Nummer': (apk: null, signature: await _signature('1.0.5', _apk, android: true)),
        // Echt signiert, aber als Windows-Installer: Der Installer selbst kommt als „APK“ …
        'Windows-Installer als APK': (apk: _installer, signature: await _signature('1.1.0', _installer)),
        // … oder die richtige APK trägt eine Signatur ohne den Android-Vermerk.
        'APK als Windows-Datei signiert': (apk: null, signature: await _signature('1.1.0', _apk)),
      };
      for (final MapEntry(key: what, value: c) in cases.entries) {
        final t = await _makeAndroid(
          manifest: await _manifestBody(android: {'signature': ?c.signature}),
          apk: c.apk,
        );
        await t.updater.check();
        await t.updater.install();
        expect(t.updater.state, UpdateState.failed, reason: what);
        expect(t.android.opened, isEmpty, reason: what);
        // Die ungeprüfte Datei bleibt nicht liegen.
        expect(t.android.dir.listSync(), isEmpty, reason: what);
      }
    });

    test('fehlende Erlaubnis: Die App fragt einmal und macht nach dem Einschalten weiter', () async {
      final t = await _makeAndroid(manifest: await _manifestBody(android: {}), canInstall: false, grants: true);
      await t.updater.check();
      await t.updater.install();
      expect(t.android.permissionAsked, 1);
      expect(t.android.opened.single.bytes, _apk);
    });

    test('Erlaubnis abgelehnt: nichts geladen, keine Fehlermeldung, später geht es wieder', () async {
      final t = await _makeAndroid(manifest: await _manifestBody(android: {}), canInstall: false);
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.available);
      expect(t.requests, [latestManifestUrl]);
      expect(t.android.opened, isEmpty);
      // Beim nächsten Antippen fragt Android wieder.
      await t.updater.install();
      expect(t.android.permissionAsked, 2);
      expect(t.updater.state, UpdateState.available);
    });

    test('Abbruch im Installer: Update steht weiter bereit, die APK ist weg', () async {
      final t = await _makeAndroid(manifest: await _manifestBody(android: {}));
      await t.updater.check();
      await t.updater.install();
      expect(t.android.opened, hasLength(1));
      expect(t.updater.state, UpdateState.available);
      expect(t.android.dir.listSync(), isEmpty);
      await t.updater.install();
      expect(t.android.opened, hasLength(2));
    });

    test('offline: Prüfung beim Start bleibt still, Download-Fehler öffnet nichts', () async {
      final offline = await _makeAndroid();
      await offline.updater.check(silent: true);
      expect(offline.updater.state, UpdateState.idle);
      await offline.updater.check();
      expect(offline.updater.state, UpdateState.failed);

      final t = await _makeAndroid(manifest: await _manifestBody(android: {}), apkStatus: 503);
      await t.updater.check();
      await t.updater.install();
      expect(t.updater.state, UpdateState.failed);
      expect(t.android.opened, isEmpty);
    });

    test('Android kann die APK nicht installieren: Fehler statt stillem Abbruch, die APK ist weg', () async {
      final t = await _makeAndroid(manifest: await _manifestBody(android: {}));
      t.android.installError = true;
      await t.updater.check();
      await t.updater.install();
      expect(t.android.opened, hasLength(1));
      expect(t.updater.state, UpdateState.failed);
      expect(t.android.dir.listSync(), isEmpty);
    });

    test('nur die veröffentlichte App aktualisiert sich: Test-Kopie und selbst gebaute Apps nicht', () async {
      Future<bool> supported({String package = releaseAppId, String? cert = releaseCertSha256}) async =>
          (await _makeAndroid(package: package, cert: cert)).updater.supported;
      expect(await supported(), isTrue);
      expect(await supported(package: '$releaseAppId.debug'), isFalse);
      expect(await supported(cert: 'ab' * 32), isFalse);
      expect(await supported(cert: null), isFalse);
    });

    test('antwortet Android nicht, startet die App trotzdem – ohne Updates', () async {
      const silent = MethodChannel('todo_liste/update-fehlt');
      final updater = await Updater.forAndroid('1.0.0', const AndroidUpdate(silent));
      expect(updater.supported, isFalse);
    });

    test('alte Downloads werden beim Start weggeräumt', () async {
      final android = _FakeAndroid();
      File('${android.dir.path}/todo-planer-0.9.0.apk').writeAsStringSync('alt');
      await Updater.forAndroid('1.0.0', AndroidUpdate(android.channel));
      expect(android.dir.listSync(), isEmpty);
    });

    test('die Test-Kopie fragt nicht bei GitHub nach', () async {
      final t = await _makeAndroid(
        manifest: await _manifestBody(android: {}),
        package: '$releaseAppId.debug',
      );
      await t.updater.check();
      expect(t.requests, isEmpty);
      expect(t.updater.state, UpdateState.idle);
    });
  });
}
