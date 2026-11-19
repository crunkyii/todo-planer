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
| `test/updater_test.dart` | Auto-Update für Windows und Android: Versionsvergleich, `latest.json` mit und ohne `android`, Signaturprüfung (veränderte Datei, fremder Schlüssel, alte Datei unter neuer Nummer); Android: fehlende Erlaubnis, Abbruch im Installer, offline, Test-Kopie ohne Updates. Android selbst wird dabei durch ein Double ersetzt – der echte Installer lässt sich nur am Handy ausprobieren. |

Hat sich das Aussehen absichtlich geändert, die Vergleichsbilder neu erzeugen:

```bash
flutter test --update-goldens --tags golden
```

Ein Durchlauf der echten App am PC (Fenster geht auf, die App wird durchgeklickt):

```bash
flutter test integration_test -d windows
```

## Android-Update am Handy ausprobieren

Den Installer von Android kann kein Test am PC ersetzen. Dafür gibt es eine Probe-App ([`tool/probe/`](../tool/probe/update_probe.dart)): Sie benutzt den echten Update-Code, aber statt GitHub antwortet der PC, und geprüft wird mit einem Wegwerf-Schlüssel. Sie wird als Debug-Version gebaut – also mit der App-ID der Test-Version, nie über die echte App. Ist die Test-Version schon am Handy, sie vorher deinstallieren (ihre Testdaten gehen dabei verloren).

```bash
dart run tool/probe/serve.dart keygen
```

Den ausgegebenen Schlüssel bei beiden Builds einsetzen – einmal als „alte“ und einmal als „neue“ Version (die APK nach jedem Build wegkopieren):

```bash
flutter build apk --debug -t tool/probe/update_probe.dart --build-name 1.0.0 --build-number 1 --dart-define=PROBE_KEY=<Schlüssel>
```

```bash
flutter build apk --debug -t tool/probe/update_probe.dart --build-name 9.9.9 --build-number 999 --dart-define=PROBE_KEY=<Schlüssel>
```

Die alte Version aufs Handy, den PC als `127.0.0.1` am Handy erreichbar machen und die neue Version anbieten:

```bash
adb install probe-1.0.0.apk
```

```bash
adb reverse tcp:8765 tcp:8765
```

```bash
dart run tool/probe/serve.dart serve probe-9.9.9.apk 9.9.9
```

In der Probe-App **Prüfen** und **Installieren** antippen: Beim ersten Mal öffnet sich „Unbekannte Apps installieren“, danach der Installer; nach **Aktualisieren** und **Öffnen** zeigt die App Version 9.9.9. Mit `kaputt` am Ende des letzten Befehls kommt eine veränderte APK – dann darf sich der Installer nicht öffnen. Zum Schluss aufräumen:

```bash
adb uninstall at.todoliste.todo_liste.debug
```

## App-Symbol

Das App-Symbol in allen Größen wird aus `tool/icon/source.webp` erzeugt:

```bash
flutter test tool/icon/make_icons_test.dart
```

---

[← Zurück zum README](../README.md)
