# Todo-Liste

Eine Aufgaben-App für Handy (Android) und PC (Windows, Linux), gebaut mit Flutter.

- **Aufgaben** mit Kategorien, Vorlauf (z. B. Hausübung „1 Tag vorher erledigen“), Uhrzeit, Unteraufgaben, Suche, Sortierung und Wischen zum Löschen
- **Jährliche Aufgaben**: Steht „Geburtstag“, „Jahrestag“ o. Ä. im Titel, entsteht beim Abhaken dieselbe Aufgabe fürs nächste Jahr
- **Gewohnheiten** mit Serien-Flamme
- **Kalender** mit österreichischen Feiertagen, **Wochenplan** mit Zeitblöcken und **Statistik** mit Heatmap
- **Erinnerungen** für Aufgaben mit Uhrzeit
- **Startbildschirm-Widgets** (Android): „Heute“, „Demnächst“, Zähler und Gewohnheiten zum Abhaken, Farben einstellbar
- **Export** aller Daten als PDF, Text oder CSV
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

`flutter test` braucht kein Gerät und keine Datenbank: Die lokale Datenbank läuft im Speicher, Supabase wird durch [`test/fake_supabase.dart`](test/fake_supabase.dart) ersetzt.

| Datei | Was sie prüft |
|---|---|
| `test/logic_test.dart`, `test/yearly_holidays_test.dart` | Reine Logik: Datum, Sortierung, Abschnitte, Serien, Feiertage, jährliche Aufgaben |
| `test/store_test.dart`, `test/sync_test.dart` | Store, Warteschlange und Abgleich (gegen das Supabase-Double) |
| `test/behaviour_test.dart`, `test/widget_test.dart` | Die ganze App wird bedient: Formulare, Menüs, Tastatur, Schriftgrößen, Barrierefreiheit |
| `test/screens_test.dart` | Bildvergleich jedes Tabs (Goldens in `test/goldens/`) |
| `test/export_test.dart`, `test/home_widgets_test.dart`, `test/widget_config_test.dart` | Export, Daten für die Startbildschirm-Widgets und deren Einstellungen |

Hat sich das Aussehen absichtlich geändert, die Vergleichsbilder neu erzeugen:

```bash
flutter test --update-goldens --tags golden
```

Ein Durchlauf der echten App am PC (Fenster geht auf, die App wird durchgeklickt):

```bash
flutter test integration_test -d windows
```

Das App-Symbol in allen Größen wird aus `tool/icon/source.webp` erzeugt:

```bash
flutter test tool/icon/make_icons_test.dart
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

### Android (Test-Version neben der echten App)

```bash
flutter build apk --debug
```

Die Debug-Version hat eine eigene App-ID (`….debug`) und heißt am Handy „Todo-Liste Test“. Sie lässt sich neben der echten App installieren und hat eigene, leere Daten – zum Ausprobieren, ohne die eigenen Aufgaben anzufassen.

## So ist die App aufgebaut

```
Bildschirme (lib/screens)  →  AppServices  →  Store  →  LocalDb (SQLite am Gerät)
        ↑ zeichnen neu, wenn der Store sich meldet       ↘  SyncService  ⇄  Supabase
```

- **Bildschirme** lesen aus dem `Store` und ändern Daten nur über seine Methoden (`addTask`, `toggleTask` …). Sie kennen weder SQL noch Supabase.
- **`Store`** ([`lib/data/store.dart`](lib/data/store.dart)) hält alle Daten im Speicher, schreibt jede Änderung in die lokale Datenbank und merkt sie für den Abgleich vor.
- **`SyncService`** ([`lib/data/sync_service.dart`](lib/data/sync_service.dart)) lädt Vorgemerktes hoch und holt Neues ab. Bei einem Konflikt gewinnt die Zeile mit dem neueren `updated_at` – am Gerät und (per Trigger) auch in der Datenbank.
- **`AppServices`** ([`lib/app_services.dart`](lib/app_services.dart)) verbindet alles: Anmeldung, Abgleich anstoßen, Erinnerungen neu planen, Widgets aktualisieren.
- **Reine Logik** (was ist überfällig, wie wird sortiert, welcher Tag ist ein Feiertag) liegt ohne Widgets in `lib/util/` und ist einzeln getestet.
- **Aussehen**: Farben, Radien, Größen und Kurven stehen in [`lib/theme/tokens.dart`](lib/theme/tokens.dart); Widgets holen sie über `context.tok`, `Sizes`, `Fs`, `Motion`.

Der Weg einer Änderung, z. B. „Aufgabe abhaken“: Tipp → `Store.toggleTask` → Speicher + lokale Datenbank (als „noch hochzuladen“ markiert) → alle Bildschirme zeichnen neu → `SyncService` lädt die Zeile hoch → andere Geräte bekommen sie über Realtime.


## Projektaufbau

| Ordner | Inhalt |
|---|---|
| `lib/data/` | Modelle, lokale Datenbank (drift, rohes SQL), Store, Einstellungen, Supabase und Sync |
| `lib/screens/` | Bildschirme: Einrichtung, Anmeldung, Aufgaben, Kalender, Woche, Statistik, Optionen, Widget-Einstellungen |
| `lib/screens/sheets/` | Die Formulare, die von unten hereinfahren – eines je Datei (Aufgabe, Block, Gewohnheit, Kategorie, Export) |
| `lib/services/` | Erinnerungen, Export (PDF/Text/CSV), Daten für die Startbildschirm-Widgets, Fehlermeldungen |
| `lib/util/` | Reine Logik ohne Widgets: Datum, Formate, Sortierung, Feiertage, Statistik, Wochenplan-Spuren |
| `lib/widgets/` | Bausteine: Knöpfe mit Feder-Effekt, Sheets, Menü, Kalender- und Uhrzeit-Auswahl, Meldungen |
| `lib/theme/` | Farben, Themes, Größen, Animationskurven |
| `lib/l10n/` | Texte auf Deutsch (`app_de.arb`) und Englisch (`app_en.arb`); `gen/` wird daraus erzeugt |
| `android/app/src/main/kotlin/…/widgets/` | Die Startbildschirm-Widgets (Kotlin) – sie zeigen, was `lib/services/home_widgets.dart` ihnen schickt |
| `supabase/schema.sql` | Datenbank-Schema mit Row Level Security |
| `test/`, `integration_test/` | Tests (siehe oben) |
| `tool/icon/` | Quelle und Erzeuger des App-Symbols |

Neue Texte immer in **beide** ARB-Dateien eintragen; `flutter pub get` erzeugt daraus den Code.
