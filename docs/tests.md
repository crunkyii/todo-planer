# Tests und Prüfung

```bash
flutter analyze
```

```bash
flutter test
```

`flutter test` braucht kein Gerät und keine Datenbank: Die lokale Datenbank läuft im Speicher, Supabase wird durch [`test/fake_supabase.dart`](../test/fake_supabase.dart) ersetzt.

| Datei | Was sie prüft |
|---|---|
| `test/logic_test.dart`, `test/yearly_holidays_test.dart` | Reine Logik: Datum, Sortierung, Abschnitte, Serien, Feiertage, jährliche Aufgaben |
| `test/store_test.dart`, `test/sync_test.dart` | Store, Warteschlange und Abgleich (gegen das Supabase-Double): feldweises Zusammenführen, ältere erledigte Aufgaben nur online |
| `test/behaviour_test.dart`, `test/widget_test.dart` | Die ganze App wird bedient: Formulare, Menüs, Tastatur, Schriftgrößen, Barrierefreiheit |
| `test/screens_test.dart` | Bildvergleich jedes Tabs (Goldens in `test/goldens/`) |
| `test/export_test.dart`, `test/home_widgets_test.dart`, `test/widget_config_test.dart` | Export, Daten für die Startbildschirm-Widgets und deren Einstellungen |
| `test/updater_test.dart` | Auto-Update: Versionsvergleich, `latest.json`, Signaturprüfung (veränderte Datei, fremder Schlüssel, alte Datei unter neuer Nummer) |

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

---

[← Zurück zum README](../README.md)
