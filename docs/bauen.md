# Selbst bauen

## Voraussetzungen

- [Flutter](https://docs.flutter.dev/get-started/install) 3.50 oder neuer (Dart 3.14)
- Für Android: Android Studio mit Android SDK 37
- Für Windows: Visual Studio mit „Desktopentwicklung mit C++“ **und** der Einzelkomponente „C++ ATL für die neuesten Buildtools (x86 und x64)“ (die Erinnerungen unter Windows brauchen ATL; ohne sie bricht der Build mit `atlbase.h` ab)
- Für Linux: `clang cmake ninja-build pkg-config libgtk-3-dev`

```bash
git clone https://github.com/crunkyii/todo-planer.git
```

```bash
cd todo-planer
```

```bash
flutter pub get
```

## Starten

```bash
flutter run -d windows
```

Beim ersten Start fragt die App, wo die Aufgaben gespeichert werden sollen:

- **Nur auf diesem Gerät** – kein Konto, keine Einrichtung. Fertig.
- **Auf allen Geräten** – eigene Supabase-Datenbank (siehe unten).

Es gibt **keine** Konfigurationsdatei mit Zugangsdaten im Code: URL und Key werden in der App eingegeben und am Gerät gespeichert.

### Windows

```bash
flutter build windows
```

Das Ergebnis liegt in `build/windows/x64/runner/Release/`.

## Android (Release-APK)

Für Updates muss jede APK mit **demselben eigenen Schlüssel** signiert sein. Einmalig einen Schlüssel anlegen (das Passwort gut aufheben, nie ins Repository!):

```bash
keytool -genkey -v -keystore ~/todo-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias todo
```

Dann die Datei `android/key.properties` anlegen (steht in `.gitignore` und wird nicht committet):

```properties
storePassword=<dein Passwort>
keyPassword=<dein Passwort>
keyAlias=todo
storeFile=<absoluter Pfad zur .jks-Datei>
```

```bash
flutter build apk --release
```

Die APK liegt in `build/app/outputs/flutter-apk/app-release.apk`. Ohne `key.properties` bricht der Release-Build mit einem Hinweis ab.

## Android (Test-Version neben der echten App)

```bash
flutter build apk --debug
```

Die Debug-Version hat eine eigene App-ID (`….debug`) und heißt am Handy „Todo-Liste Test“. Sie lässt sich neben der echten App installieren und hat eigene, leere Daten – zum Ausprobieren, ohne die eigenen Aufgaben anzufassen.

---

[← Zurück zum README](../README.md)
