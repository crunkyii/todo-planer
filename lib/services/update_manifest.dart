import 'dart:convert';

/// Nur von hier lädt die App Updates: die Release-Dateien dieses Projekts auf GitHub.
const releaseDownloadBase = 'https://github.com$_releasePath';
const _releasePath = '/crunkyii/todo-planer/releases/download/';

/// Die Datei, die immer auf die neueste Version zeigt (liegt an jedem Release).
final latestManifestUrl = Uri.parse('https://github.com/crunkyii/todo-planer/releases/latest/download/latest.json');

/// Öffentlicher Ed25519-Schlüssel, mit dem jede Update-Datei geprüft wird. Der private Schlüssel
/// dazu liegt nur am Rechner, an dem Releases gebaut werden (siehe `tool/release/sign.dart`).
const updatePublicKey = 'V1d6vuvYDMZgex4hxbgqzKApaL5rHfgQSnz2nsRy08Q=';

/// „1.2.3“ (auch „1.2.3+4“) als Zahlenliste; `null`, wenn es keine solche Version ist.
List<int>? parseVersion(String v) {
  final m = RegExp(r'^(\d{1,6})\.(\d{1,6})\.(\d{1,6})(\+\d{1,9})?$').firstMatch(v);
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
}

/// Ist [candidate] neuer als [current]? Unlesbare Versionen gelten nie als neuer.
bool isNewer(String candidate, String current) {
  final a = parseVersion(candidate), b = parseVersion(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Was unterschrieben wird: Version **und** Prüfsumme der Datei. So kann niemand eine alte,
/// echt signierte Datei als „neue Version“ ausgeben.
List<int> signedMessage(String version, List<int> sha256) =>
    utf8.encode('todo-planer-update\n$version\n${base64Encode(sha256)}\n');

/// App-ID der veröffentlichten Android-App und SHA-256 ihres Signatur-Zertifikats (öffentlich, steht in
/// jeder APK). Nur diese App aktualisiert sich selbst: Die Test-Kopie und selbst gebaute Apps sind anders
/// signiert, Android würde die APK des Releases dort ohnehin ablehnen.
const releaseAppId = 'at.todoliste.todo_liste';
const releaseCertSha256 = 'e5d510e4f9f18a57185eaa0caf10fb3d1129274417ba07b564ba5bbdd914ffe2';

/// Eine Datei eines Releases: woher sie kommt und ihre Signatur.
class UpdateFile {
  const UpdateFile({required this.url, required this.signature});

  final Uri url;
  final List<int> signature;

  /// Liest Adresse und Signatur aus [j]; [what] steht in der Fehlermeldung.
  factory UpdateFile._parse(Map<dynamic, dynamic> j, String what) {
    final url = j['url'], signature = j['signature'];
    if (url is! String) throw FormatException('latest.json: Adresse ($what)');
    // Erst zerlegen, dann prüfen: `Uri.parse` löst „..“ und „%2e%2e“ schon auf, ein Vergleich am
    // Text würde das übersehen. Erlaubt ist nur die eigene Release-Seite über https.
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.startsWith(_releasePath)) {
      throw FormatException('latest.json: Adresse ($what)');
    }
    if (signature is! String) throw FormatException('latest.json: Signatur ($what)');
    final sig = base64Decode(signature);
    if (sig.length != 64) throw FormatException('latest.json: Signatur ($what)');
    return UpdateFile(url: uri, signature: sig);
  }
}

/// Inhalt von `latest.json`. Oben stehen Version, Adresse und Signatur des Windows-Installers (so lesen
/// es auch ältere Windows-Apps), unter `android` Adresse und Signatur der APK.
class UpdateManifest {
  const UpdateManifest({required this.version, required this.windows, this.android});

  final String version;
  final UpdateFile windows;

  /// `null` bei Releases ohne APK (und bei `latest.json` aus der Zeit vor dem Android-Update).
  final UpdateFile? android;

  /// Liest und prüft die Datei; wirft [FormatException], wenn etwas nicht passt.
  factory UpdateManifest.parse(String body) {
    final j = jsonDecode(body);
    if (j is! Map) throw const FormatException('latest.json: kein Objekt');
    final version = j['version'], android = j['android'];
    if (version is! String || parseVersion(version) == null) throw const FormatException('latest.json: Version');
    if (android != null && android is! Map) throw const FormatException('latest.json: android');
    return UpdateManifest(
      version: version,
      windows: UpdateFile._parse(j, 'Windows'),
      android: android is Map ? UpdateFile._parse(android, 'Android') : null,
    );
  }
}
