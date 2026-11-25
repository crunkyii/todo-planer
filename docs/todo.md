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
  - **Standardmäßig nichts von Flick**: Ohne Plugin enthält die App keinen Flick-Teil – kein Abschnitt in den
    Optionen, keine Flick-Symbole (`assets/flick`), keine Vorlage (`tool/flick`), kein Export der heutigen Aufgaben.
    Das alles wandert in das Plugin.
  - **Repo verlinken**: Die Plugin-Seite verlinkt das Flick-Repo (https://github.com/Whiskey-Bravo/flick).
  - **Rechte**: Beim Installieren steht in Klartext, was das Plugin darf – Aufgaben lesen, **Datenbank verändern**
    (Aufgaben anlegen und abhaken, das wird mit den anderen Geräten abgeglichen) und Dateien in einem eigenen Ordner.
- Entwurf mit Bildschirmen: Design-Konzept „ToDo Planer – Konzept“ (Marktplatz, Plugin-Rechte).

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

## Mehr Animationen

### Wischen im Kalender und im Wochenplan

Beim Wischen zum nächsten oder vorigen Monat bzw. zur nächsten oder vorigen Woche soll man sehen, in welche
Richtung es geht.

- Der Inhalt folgt dem Finger und gleitet dann ganz hinaus, der neue Monat bzw. die neue Woche kommt von der
  passenden Seite herein (nach links wischen → nächster, nach rechts → voriger).
- Lässt man zu früh los, federt die Ansicht zurück. Dasselbe Hineingleiten auch bei den Pfeil-Knöpfen und bei
  „Heute“.
- Titel (Monat bzw. Kalenderwoche) wechselt mit, z. B. kurz hinausgleiten und ausblenden.
- Dauer und Kurven über `Motion` in `lib/theme/tokens.dart`; bei „Animationen reduzieren“ nur ein kurzes Überblenden.

### Abhaken von Aufgaben und Gewohnheiten

Beim Abhaken soll mehr passieren, damit es sich nach Erfolg anfühlt.

- Haken zeichnet sich, der Kreis füllt sich mit der Farbe der Kategorie bzw. Gewohnheit, kleiner Sprung (Feder).
- **Splash** beim Abhaken: von oben gesehen spritzen aus dem Kreis Tropfen in seiner Farbe in alle Richtungen
  (rundliche Tropfen in verschiedenen Größen, mit kleinem Glanzlicht, dazu ein paar Spritzer; nur knapp über den Kreis hinaus). Es gibt 50 verschiedene Splashes, jedes Abhaken nimmt zufällig einen, ziehen sich dann zusammen und
  verschwinden nach gut einer halben Sekunde. Nur beim gerade abgehakten Kreis, nicht beim Öffnen; gezeichnet über
  den Nachbarzeilen (`CustomPainter` in einem `Overlay`, kein Paket nötig).
- Aufgaben: Titel wird animiert durchgestrichen, die Karte rutscht dann sanft in „Erledigt“, die Liste schließt
  die Lücke weich.
- Gewohnheiten: Serie (Streak) zählt sichtbar hoch; bei allen Gewohnheiten des Tages oder einer runden Serie
  ein kleiner Konfetti- oder Funken-Effekt.
- Wieder öffnen läuft rückwärts ab. Haptik wie bei `Pressable`; „Animationen reduzieren“ beachten.
