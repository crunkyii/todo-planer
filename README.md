# Todo-Liste

Eine Aufgaben-App für Handy (Android) und PC (Windows, Linux), gebaut mit Flutter.

- **Aufgaben** mit Kategorien, Vorlauf (z. B. Hausübung „1 Tag vorher erledigen“), Uhrzeit, Unteraufgaben, Suche, Sortierung und Wischen zum Löschen
- **Gewohnheiten** mit Serien-Flamme
- **Kalender**, **Wochenplan** mit Zeitblöcken und **Statistik** mit Heatmap
- **10 Themes**, hell/dunkel, Deutsch/Englisch
- **Offline zuerst**: Alles wird sofort am Gerät gespeichert und später abgeglichen
- Optional: eigene kostenlose **Supabase**-Datenbank, damit Handy und PC gleich bleiben

## Voraussetzungen

- [Flutter](https://docs.flutter.dev/get-started/install) 3.50 oder neuer (Dart 3.14)
- Für Android: Android Studio mit Android SDK 37
- Für Windows: Visual Studio mit „Desktopentwicklung mit C++“ **und** der Einzelkomponente „C++ ATL für die neuesten Buildtools (x86 und x64)“ (die Erinnerungen unter Windows brauchen ATL; ohne sie bricht der Build mit `atlbase.h` ab)
- Für Linux: `clang cmake ninja-build pkg-config libgtk-3-dev`

```bash
git clone <URL dieses Repositorys>
```

```bash
cd TodoListe
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

## Eigene Datenbank einrichten (Supabase, kostenlos)

Die App zeigt diese Schritte auch selbst an („Datenbank verbinden“).

1. Auf [supabase.com](https://supabase.com/dashboard) registrieren und ein **neues Projekt** anlegen.
2. Im Projekt den **SQL Editor** öffnen. In der App auf **„SQL kopieren“** tippen (oder den Inhalt von [`supabase/schema.sql`](supabase/schema.sql) nehmen), einfügen und auf **Run** klicken. Das legt alle Tabellen samt Zugriffsschutz (Row Level Security) an. Das Skript kann gefahrlos noch einmal ausgeführt werden.
3. Unter **Project Settings → API Keys** die **Project URL** (`https://….supabase.co`) und den **Publishable Key** (`sb_publishable_…`, bei älteren Projekten der `anon`-Key `eyJ…`) kopieren und in der App einfügen.
   **Niemals den Secret Key (`sb_secret_…` / `service_role`) eingeben** – die App lehnt ihn ab.
4. In der App ein Konto erstellen (einmalig, danach bleibt man angemeldet).
5. Danach in Supabase unter **Authentication → Sign In / Providers** die Option **„Allow new users to sign up“** ausschalten. Dann kann sich niemand sonst ein Konto in deiner Datenbank anlegen.

Auf weiteren Geräten: gleiche URL und gleichen Key eingeben und mit demselben Konto **anmelden**.

### So funktioniert der Abgleich

- Jede Änderung landet zuerst in der lokalen Datenbank (drift/SQLite) und in einer Warteschlange.
- Sobald das Gerät online ist, werden Änderungen hochgeladen; die neueste Änderung gewinnt.
- Über Supabase Realtime bekommen andere Geräte Änderungen sofort mit.
- Offline zeigt die App eine kurze Meldung und ein Wolken-Symbol bei Aufgaben, die noch warten.

## Tests und Prüfung

```bash
flutter analyze
```

```bash
flutter test
```

## Bauen

### Windows

```bash
flutter build windows
```

Das Ergebnis liegt in `build/windows/x64/runner/Release/`.

### Android (Release-APK)

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

## Projektaufbau

| Ordner | Inhalt |
|---|---|
| `lib/data/` | Modelle, lokale Datenbank (drift), Store, Einstellungen, Supabase und Sync |
| `lib/screens/` | Bildschirme: Einrichtung, Anmeldung, Aufgaben, Kalender, Woche, Statistik, Optionen, Sheets |
| `lib/widgets/` | Bausteine: Knöpfe mit Feder-Effekt, Sheets, Menü, Kalender- und Uhrzeit-Auswahl, Meldungen |
| `lib/theme/` | Farben, Themes, Größen, Animationskurven |
| `lib/l10n/` | Texte auf Deutsch (`app_de.arb`) und Englisch (`app_en.arb`) |
| `supabase/schema.sql` | Datenbank-Schema mit Row Level Security |
| `design/prototyp.html` | Klick-Prototyp, nach dem die App gebaut ist |

Neue Texte immer in **beide** ARB-Dateien eintragen; `flutter pub get` erzeugt daraus den Code.
