# Installer und Auto-Update (Windows und Android)

## Windows-Installer

`todo-planer-<Version>-setup.exe` installiert die App nur für den angemeldeten Benutzer nach `%LOCALAPPDATA%\Programs\ToDo Planer` – ohne Admin-Rechte und ohne UAC-Abfrage (wer schon eine ältere Version installiert hat, behält deren Ordner). Er legt einen Eintrag im Startmenü an (auf Wunsch auch am Desktop) und lässt sich über „Apps“ in den Windows-Einstellungen wieder entfernen. Die Aufgaben liegen nicht im Programmordner; ein Update oder eine Deinstallation löscht sie nicht.

## So läuft ein Update ab

1. Beim Start (und beim Antippen von **Optionen → Updates**) lädt die App die Datei [`latest.json`](https://github.com/crunkyii/todo-planer/releases/latest/download/latest.json) vom neuesten Release.
2. Steht dort eine höhere Version, meldet die App das und zeigt den Knopf **Installieren**.
3. Nach dem Antippen lädt sie die Datei für das eigene Gerät und **prüft ihre Signatur**. Erst danach geht es weiter:
   - **Windows:** Der Installer startet. Es erscheint nur ein Fortschrittsfenster; danach startet die neue Version von selbst.
   - **Android:** Die App öffnet den Installer von Android. Dort einmal auf **Aktualisieren** tippen – ganz ohne Nachfrage lässt Android keine App eine andere installieren.

### Android: die Erlaubnis beim ersten Update

Android lässt eine App nur dann den Installer öffnen, wenn man ihr das erlaubt hat. Beim ersten Update öffnet die App deshalb einmal die Seite **Unbekannte Apps installieren** – dort den Schalter für *ToDo Planer* einschalten und zurückgehen, das Update läuft dann weiter. Wer das nicht möchte, geht einfach zurück: Die App läuft normal weiter, das Update bleibt in den Optionen stehen. Dasselbe gilt, wenn man im Installer auf **Abbrechen** tippt.

Die geladene APK liegt nur im eigenen Cache der App. Der Installer bekommt Lesezugriff auf genau diesen einen Ordner; alte Downloads räumt die App beim nächsten Start weg.

### Wer sich selbst aktualisiert

- **Windows:** nur die mit dem Installer installierte App.
- **Android:** nur die veröffentlichte App von der Release-Seite.

Die Test-Version (`….debug`) und selbst gebaute Apps bekommen keine Updates eingespielt: Sie sind mit einem anderen Schlüssel signiert, Android würde die APK des Releases dort ohnehin ablehnen.

## Warum das sicher ist

- Jede Update-Datei ist mit **Ed25519** unterschrieben. Der öffentliche Schlüssel steckt in der App ([`lib/services/update_manifest.dart`](../lib/services/update_manifest.dart)), der private liegt nur am Rechner, an dem Releases gebaut werden – nie im Repository.
- Unterschrieben wird die **Versionsnummer zusammen mit der Prüfsumme** (SHA-256) der Datei. Eine veränderte Datei fällt genauso durch wie eine alte, echte Datei, die als „neue Version“ ausgegeben wird.
- Die App lädt nur von der Release-Seite dieses Projekts (`https`), nimmt keine niedrigere Version an und bricht bei zu großen Dateien oder zu langem Warten ab.
- Passt etwas nicht, wird **nichts gestartet** und kein Installer geöffnet; die geladene Datei wird gelöscht und die App läuft einfach weiter.
- Unter Android kommt die Prüfung des Systems dazu: Es installiert ein Update nur, wenn die APK mit demselben Schlüssel signiert ist wie die installierte App.

Der Code dazu: [`lib/services/updater.dart`](../lib/services/updater.dart) (Prüfen, Laden, Signatur – für beide Systeme gleich), [`lib/services/update_platform.dart`](../lib/services/update_platform.dart) (der letzte Schritt je System) und [`AppUpdate.kt`](../android/app/src/main/kotlin/at/todoliste/todo_liste/update/AppUpdate.kt) (Erlaubnis und Installer unter Android). Tests in [`test/updater_test.dart`](../test/updater_test.dart).

## Aufbau von `latest.json`

```json
{
  "version": "1.3.0",
  "url": "https://github.com/crunkyii/todo-planer/releases/download/v1.3.0/todo-planer-1.3.0-setup.exe",
  "signature": "…",
  "android": {
    "url": "https://github.com/crunkyii/todo-planer/releases/download/v1.3.0/todo-planer-1.3.0.apk",
    "signature": "…"
  }
}
```

`version`, `url` und `signature` oben gehören zum Windows-Installer – so lesen es auch ältere Windows-Apps, die `android` noch nicht kennen und das Feld überspringen. Fehlt `android`, finden Android-Apps in diesem Release kein Update.

## Ein Release bauen

Einmalig das Schlüsselpaar anlegen. Der private Schlüssel landet in `~/.todo-planer/update-signing.key` (anderer Ort: Umgebungsvariable `TODO_PLANER_SIGNING_KEY`), der öffentliche wird ausgegeben und gehört als `updatePublicKey` in `lib/services/update_manifest.dart`:

```bash
dart run tool/release/sign.dart keygen
```

Für die APK braucht es außerdem den eigenen Release-Schlüssel in `android/key.properties` ([bauen.md](bauen.md)). Der SHA-256-Fingerabdruck seines Zertifikats gehört als `releaseCertSha256` in `lib/services/update_manifest.dart` – daran erkennt die App, dass sie die veröffentlichte ist. Anzeigen lässt er sich mit `apksigner verify --print-certs <app.apk>`.

Für jede neue Version die Nummer in `pubspec.yaml` erhöhen (auch die Zahl hinter dem `+`, sonst nimmt Android das Update nicht an), dann:

```bash
pwsh tool/release/build-release.ps1
```

Das Skript baut den Windows-Installer und die APK, prüft, dass die APK mit dem Release-Schlüssel signiert ist, signiert beide Dateien und schreibt `latest.json`. Am Ende prüft es die Signaturen mit demselben Code wie die App. Der Ordner, in dem gebaut wird, steht in den fertigen Dateien – deshalb aus einem neutralen Ordner bauen (z. B. `C:\src\todo-planer`), nicht aus dem eigenen Benutzerordner; das Skript bricht sonst ab.

Die drei Dateien aus `build/dist/` – `todo-planer-<Version>-setup.exe`, `todo-planer-<Version>.apk` und `latest.json` – an das GitHub-Release mit dem Tag `v<Version>` hängen. Ab dann finden installierte Apps die neue Version.

Geht der private Schlüssel verloren, können installierte Apps keine Updates mehr prüfen; dann braucht es einen neuen Schlüssel und eine von Hand installierte Version.

---

[← Zurück zum README](../README.md)
