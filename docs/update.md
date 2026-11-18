# Installer und Auto-Update (Windows)

## Installer

`todo-planer-<Version>-setup.exe` installiert die App nur für den angemeldeten Benutzer nach `%LOCALAPPDATA%\Programs\Todo-Planer` – ohne Admin-Rechte und ohne UAC-Abfrage. Er legt einen Eintrag im Startmenü an (auf Wunsch auch am Desktop) und lässt sich über „Apps“ in den Windows-Einstellungen wieder entfernen. Die Aufgaben liegen nicht im Programmordner; ein Update oder eine Deinstallation löscht sie nicht.

## So läuft ein Update ab

1. Beim Start (und beim Antippen von **Optionen → Updates**) lädt die App die Datei [`latest.json`](https://github.com/crunkyii/todo-planer/releases/latest/download/latest.json) vom neuesten Release.
2. Steht dort eine höhere Version, meldet die App das und zeigt den Knopf **Installieren**.
3. Nach dem Antippen lädt sie den Installer, **prüft seine Signatur** und startet ihn. Es erscheint nur ein Fortschrittsfenster; danach startet die neue Version von selbst.

Nur die mit dem Installer installierte App aktualisiert sich. Wer die App selbst baut, bekommt keine Updates eingespielt.

## Warum das sicher ist

- Jede Update-Datei ist mit **Ed25519** unterschrieben. Der öffentliche Schlüssel steckt in der App ([`lib/services/update_manifest.dart`](../lib/services/update_manifest.dart)), der private liegt nur am Rechner, an dem Releases gebaut werden – nie im Repository.
- Unterschrieben wird die **Versionsnummer zusammen mit der Prüfsumme** (SHA-256) der Datei. Eine veränderte Datei fällt genauso durch wie eine alte, echte Datei, die als „neue Version“ ausgegeben wird.
- Die App lädt nur von der Release-Seite dieses Projekts (`https`), nimmt keine niedrigere Version an und bricht bei zu großen Dateien ab.
- Passt etwas nicht, wird **nichts gestartet**; die App läuft einfach weiter.

Der Code dazu: [`lib/services/updater.dart`](../lib/services/updater.dart), Tests in [`test/updater_test.dart`](../test/updater_test.dart).

## Ein Release bauen

Einmalig das Schlüsselpaar anlegen. Der private Schlüssel landet in `~/.todo-planer/update-signing.key` (anderer Ort: Umgebungsvariable `TODO_PLANER_SIGNING_KEY`), der öffentliche wird ausgegeben und gehört als `updatePublicKey` in `lib/services/update_manifest.dart`:

```bash
dart run tool/release/sign.dart keygen
```

Für jede neue Version die Nummer in `pubspec.yaml` erhöhen, dann:

```bash
pwsh tool/release/build-windows.ps1
```

Die beiden Dateien aus `build/dist/` – `todo-planer-<Version>-setup.exe` und `latest.json` – an das GitHub-Release mit dem Tag `v<Version>` hängen. Ab dann finden installierte Apps die neue Version.

Geht der private Schlüssel verloren, können installierte Apps keine Updates mehr prüfen; dann braucht es einen neuen Schlüssel und eine von Hand installierte Version.

---

[← Zurück zum README](../README.md)
