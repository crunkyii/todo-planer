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

## Eigene SQL-Datenbank

Neben Supabase soll man auch eine eigene Datenbank auf SQL-Basis verbinden können, z. B. PostgreSQL, MySQL/MariaDB
oder SQL Server auf dem eigenen Server oder NAS.

- **Einrichtung** wie bei „Datenbank verbinden“: Art der Datenbank wählen, Adresse, Port, Datenbankname, Benutzer
  und Passwort eingeben, „Verbindung testen“, dann übernehmen.
- **Tabellen anlegen**: Die App bringt für jede unterstützte Datenbank ein fertiges SQL-Skript mit (wie
  `supabase/schema.sql`), das wiederholt ausführbar ist. Am besten legt die App die Tabellen nach Rückfrage selbst an.
- **Abgleich** wie bisher: lokale drift-Datenbank bleibt die Quelle, Warteschlange (`dirty`), feldweises
  Zusammenführen (`field_times`), Abruf nur des Neuen (`synced_at`). Dafür den Sync hinter eine Schnittstelle legen
  (`SyncBackend`), die Supabase und die eigene Datenbank beide umsetzen.
- **Mehrere Geräte und Konten**: Ohne Supabase gibt es kein fertiges Login und keine Row Level Security. Entweder
  ein kleiner eigener Server (REST-API) vor der Datenbank, der Konten und Rechte prüft, oder pro Person eine eigene
  Datenbank bzw. ein eigener Datenbank-Benutzer.
- **Sicherheit**: Nur verschlüsselte Verbindungen (TLS), Passwort sicher am Gerät speichern, nie im Klartext loggen.
  Eine Datenbank direkt ins Internet zu stellen ist riskant – in der Anleitung den Weg über VPN (z. B. Tailscale,
  WireGuard) oder einen eigenen Server empfehlen.
- **Neue Libraries** für die Datenbank-Treiber vorher prüfen und abstimmen (Version, Lizenz, läuft auf Android,
  Windows und Linux).
