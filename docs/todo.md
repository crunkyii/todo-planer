# Todo – geplante Funktionen

## Plugin-Marktplatz

Ein Marktplatz in der App, über den man Themes und Plugins findet, installiert und wieder entfernt.

- **Marktplatz-Seite** (z. B. Optionen → Erweiterungen): Liste mit Name, Beschreibung, Autor, Version und
  Vorschaubild, dazu Suche und die Bereiche „Themes“ und „Plugins“.
- **Eigene Beiträge**: Andere Personen können eigene Themes und Plugins einreichen, z. B. per Pull Request in ein
  eigenes Repo mit einer Liste (`index.json`) oder über ein Formular.
- **Themes**: Farben, Radien und Schriften als Datei, die auf `lib/theme/tokens.dart` abgebildet wird.
  Hell- und Dunkel-Variante, Vorschau vor dem Übernehmen.
- **Plugins**: klare Schnittstelle (was ein Plugin lesen und auslösen darf), Version der App, die es braucht,
  Rechte beim Installieren anzeigen.
- **Sicherheit**: Nur geprüfte oder signierte Einträge, kein fremder Code ohne Prüfung, Plugins jederzeit
  abschaltbar.
- **Flick als Plugin**: Die Flick-Anbindung wird nicht mehr automatisch eingerichtet. Sie steht als Plugin im
  Marktplatz und wird erst aktiv, wenn man sie dort installiert. Beim Entfernen räumt sie ihre Dateien wieder weg.
