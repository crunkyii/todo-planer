# ToDo Planer

Aufgaben, Gewohnheiten, Kalender und Wochenplan in einer App – für Android, Windows und Linux, gebaut mit Flutter. Funktioniert ohne Konto und ohne Internet; wer will, gleicht Handy und PC über eine eigene Datenbank ab.

![Aufgaben, Kalender, Wochenplan und Statistik](screenshots/hero.png)

## Installieren

**Android:** Unter [Releases](https://github.com/crunkyii/todo-planer/releases/latest) die Datei `todo-planer-<Version>.apk` herunterladen und öffnen. Beim ersten Mal fragt Android, ob Apps aus dieser Quelle installiert werden dürfen. Neue Versionen meldet die App danach selbst; zum Installieren genügt ein Tipper in der App und einer im Fenster von Android ([so funktioniert das Update](docs/update.md)).

**Windows:** Unter [Releases](https://github.com/crunkyii/todo-planer/releases/latest) die Datei `todo-planer-<Version>-setup.exe` herunterladen und ausführen. Der Installer braucht keine Admin-Rechte. Weil er nicht von Microsoft zertifiziert ist, warnt Windows beim ersten Start („Der Computer wurde durch Windows geschützt“) – mit **Weitere Informationen → Trotzdem ausführen** geht es weiter. Neue Versionen holt sich die App danach selbst ([so funktioniert das Update](docs/update.md)).

**Selbst bauen** (auch für Linux): siehe [docs/bauen.md](docs/bauen.md).

Beim ersten Start fragt die App, wo die Aufgaben gespeichert werden sollen: **Konto erstellen** bzw. **Ich habe schon ein Konto** (auf allen Geräten, eigene kostenlose Supabase-Datenbank) oder **Nur auf diesem Gerät** (kein Konto, keine Einrichtung).

## Was es kann

- **Aufgaben** mit Kategorien, Uhrzeit, Unteraufgaben, Notizen, Suche und Erinnerungen
- **Vorlauf** je Kategorie – eine Hausübung steht schon am Vortag in der Liste
- **Weniger voll**: je Kategorie einstellbar, ab wann ihre Aufgaben in der Liste stehen (z. B. Geburtstage erst in ihrer Woche)
- **Gewohnheiten** mit Serien-Flamme
- **Kalender** mit österreichischen Feiertagen, **Wochenplan** mit Zeitblöcken, **Statistik** mit Heatmap
- **Startbildschirm-Widgets** für Android
- **Export** als PDF, Text oder CSV
- **10 Themes**, hell/dunkel, Deutsch/Englisch
- **Auto-Update** unter Windows und Android – signiert und geprüft, bevor etwas installiert wird
- **Offline zuerst**: Alles wird sofort am Gerät gespeichert und später abgeglichen

| Aufgaben | Neue Aufgabe | Kalender |
|---|---|---|
| ![Aufgaben](screenshots/aufgaben.png) | ![Neue Aufgabe](screenshots/aufgabe-neu.png) | ![Kalender](screenshots/kalender.png) |

| Wochenplan | Statistik | Dunkel |
|---|---|---|
| ![Wochenplan](screenshots/woche.png) | ![Statistik](screenshots/statistik.png) | ![Aufgaben im dunklen Modus](screenshots/aufgaben-dunkel.png) |

## Datenschutz

Deine Aufgaben bleiben am Gerät – oder in **deiner eigenen** Datenbank, wenn du den Abgleich einschaltest. Keine Werbung, kein Tracking, kein Konto beim Entwickler. Details: [docs/datenschutz.md](docs/datenschutz.md).

## Mehr erfahren

| Seite | Inhalt |
|---|---|
| [Was die App kann](docs/funktionen.md) | Alle Funktionen im Detail |
| [Auf allen Geräten](docs/sync.md) | Eigene Supabase-Datenbank einrichten, so funktioniert der Abgleich |
| [Datenschutz](docs/datenschutz.md) | Was gespeichert und übertragen wird |
| [Installer und Auto-Update](docs/update.md) | Wie das Update unter Windows und Android abläuft und geprüft wird |
| [Selbst bauen](docs/bauen.md) | Voraussetzungen, Starten, Windows- und Android-Build |
| [Tests](docs/tests.md) | Was getestet wird und wie man die Tests startet |
| [Aufbau](docs/aufbau.md) | Architektur, Ordner und Regeln für Änderungen am Code |

## Lizenz

[MIT](LICENSE)
