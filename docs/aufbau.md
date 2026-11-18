# So ist die App aufgebaut

```
Bildschirme (lib/screens)  →  AppServices  →  Store  →  LocalDb (SQLite am Gerät)
        ↑ zeichnen neu, wenn der Store sich meldet       ↘  SyncService  ⇄  Supabase
```

- **Bildschirme** lesen aus dem `Store` und ändern Daten nur über seine Methoden (`addTask`, `toggleTask` …). Sie kennen weder SQL noch Supabase.
- **`Store`** ([`lib/data/store.dart`](../lib/data/store.dart)) hält alle Daten im Speicher, schreibt jede Änderung in die lokale Datenbank und merkt sie für den Abgleich vor.
- **`SyncService`** ([`lib/data/sync_service.dart`](../lib/data/sync_service.dart)) lädt Vorgemerktes hoch und holt Neues ab. Bei einem Konflikt gewinnt die Zeile mit dem neueren `updated_at` – am Gerät und (per Trigger) auch in der Datenbank.
- **`AppServices`** ([`lib/app_services.dart`](../lib/app_services.dart)) verbindet alles: Anmeldung, Abgleich anstoßen, Erinnerungen neu planen, Widgets aktualisieren.
- **Reine Logik** (was ist überfällig, wie wird sortiert, welcher Tag ist ein Feiertag) liegt ohne Widgets in `lib/util/` und ist einzeln getestet.
- **Aussehen**: Farben, Radien, Größen und Kurven stehen in [`lib/theme/tokens.dart`](../lib/theme/tokens.dart); Widgets holen sie über `context.tok`, `Sizes`, `Fs`, `Motion`.

Der Weg einer Änderung, z. B. „Aufgabe abhaken“: Tipp → `Store.toggleTask` → Speicher + lokale Datenbank (als „noch hochzuladen“ markiert) → alle Bildschirme zeichnen neu → `SyncService` lädt die Zeile hoch → andere Geräte bekommen sie über Realtime.

## Regeln für Änderungen am Code

- UI-Import ist `package:material_ui/material_ui.dart` (nicht `flutter/material.dart`).
- Farben, Radien, Größen und Kurven nur über [`lib/theme/tokens.dart`](../lib/theme/tokens.dart) (`context.tok`, `Sizes`, `Fs`, `Motion`).
- Alle sichtbaren Texte und Screenreader-Beschriftungen in `app_de.arb` **und** `app_en.arb`; Zugriff über `context.l`.
- Datums- und Zeitformate über `Fmt.of(context)` ([`lib/util/fmt.dart`](../lib/util/fmt.dart)).
- Daten nur über `Store` ändern – der schreibt lokal, merkt die Änderung vor und stößt den Abgleich an.
- drift ohne Codegen (rohes SQL in [`lib/data/local_db.dart`](../lib/data/local_db.dart)) – kein `build_runner`.
- Neue Spalten: `schemaVersion` erhöhen und in `onUpgrade` nachziehen; [`supabase/schema.sql`](../supabase/schema.sql) muss in einem Rutsch und wiederholt ausführbar bleiben.
- Klickbare Elemente über `Pressable` (Feder, Schimmer, Haptik, Fokus, Semantik).
- Vor jedem Commit: `dart format -l 120 lib test`, `flutter analyze` ohne Meldungen, `flutter test` grün.

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

---

[← Zurück zum README](../README.md)
