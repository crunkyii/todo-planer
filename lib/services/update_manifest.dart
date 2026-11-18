import 'dart:convert';

/// Nur von hier lädt die App Updates: die Release-Dateien dieses Projekts auf GitHub.
const releaseDownloadBase = 'https://github.com/crunkyii/todo-planer/releases/download/';

/// Die Datei, die immer auf die neueste Version zeigt (liegt an jedem Release).
final latestManifestUrl = Uri.parse('https://github.com/crunkyii/todo-planer/releases/latest/download/latest.json');

/// Öffentlicher Ed25519-Schlüssel, mit dem jede Update-Datei geprüft wird. Der private Schlüssel
/// dazu liegt nur am Rechner, an dem Releases gebaut werden (siehe `tool/release/sign.dart`).
const updatePublicKey = 'V1d6vuvYDMZgex4hxbgqzKApaL5rHfgQSnz2nsRy08Q=';

/// „1.2.3“ (auch „1.2.3+4“) als Zahlenliste; `null`, wenn es keine solche Version ist.
List<int>? parseVersion(String v) {
  final parts = v.split('+').first.split('.');
  if (parts.length != 3) return null;
  final nums = [for (final p in parts) RegExp(r'^\d{1,6}$').hasMatch(p) ? int.parse(p) : null];
  return nums.contains(null) ? null : nums.cast<int>();
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

/// Inhalt von `latest.json`.
class UpdateManifest {
  const UpdateManifest({required this.version, required this.url, required this.signature});

  final String version;
  final Uri url;
  final List<int> signature;

  /// Liest und prüft die Datei; wirft [FormatException], wenn etwas nicht passt.
  factory UpdateManifest.parse(String body) {
    final j = jsonDecode(body);
    if (j is! Map) throw const FormatException('latest.json: kein Objekt');
    final version = j['version'], url = j['url'], signature = j['signature'];
    if (version is! String || parseVersion(version) == null) throw const FormatException('latest.json: Version');
    // Nur die eigene Release-Seite, nur https, kein „..“ im Pfad.
    if (url is! String || !url.startsWith(releaseDownloadBase) || url.contains('..')) {
      throw const FormatException('latest.json: Adresse');
    }
    if (signature is! String) throw const FormatException('latest.json: Signatur');
    final sig = base64Decode(signature);
    if (sig.length != 64) throw const FormatException('latest.json: Signatur');
    return UpdateManifest(version: version, url: Uri.parse(url), signature: sig);
  }
}
