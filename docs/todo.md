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

## Widget „Demnächst“: wie weit in die Zukunft

In den Widget-Einstellungen soll man festlegen können, wie weit „Demnächst“ in die Zukunft schaut.

- Neue Einstellung **Zeitraum**, nur wenn der Inhalt „Demnächst“ ist, z. B. *3 Tage*, *1 Woche*, *2 Wochen*,
  *1 Monat* oder *Alles*. Standard bleibt *Alles*, damit sich bestehende Widgets nicht ändern.
- Gespeichert in `WidgetConfig` (Dart und `WidgetConfig.kt`); `WidgetData.tasks()` filtert nach Fälligkeit bis zu
  diesem Tag, Überfälliges bleibt immer drin. Die Zahl im Kopf zählt nur, was angezeigt wird.
- Vorschau im Einstellungsfenster zeigt den Zeitraum mit an, Texte in `app_de.arb` und `app_en.arb`.

## Auswahl-Balken ersetzen

Die Auswahl-Balken mit mehreren Feldern nebeneinander (`Seg`, z. B. *Hell / Dunkel / System*, *Deutsch / English*,
*Rund / Weich / Eckig*, *Heute / Demnächst / Gewohnheiten*) sollen überall aus der App verschwinden.

- Stattdessen eine schlichtere Auswahl, z. B. eine Zeile mit dem aktuellen Wert, die beim Antippen ein Menü
  (`AppMenuRoute`) oder ein Sheet mit den Möglichkeiten öffnet – überall gleich.
- Betrifft alle Stellen mit `Seg<…>` (Optionen, Widget-Einstellungen, Formulare); danach `Seg` entfernen.
- Bedienung mit Tastatur und Screenreader muss erhalten bleiben, Vergleichsbilder (Goldens) neu erzeugen.

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
  (unterschiedlich lang, mit kleinem Glanzlicht, dazwischen ein paar runde Spritzer), ziehen sich dann zusammen und
  verschwinden nach gut einer halben Sekunde. Nur beim gerade abgehakten Kreis, nicht beim Öffnen; gezeichnet über
  den Nachbarzeilen (`CustomPainter` in einem `Overlay`, kein Paket nötig).
- Aufgaben: Titel wird animiert durchgestrichen, die Karte rutscht dann sanft in „Erledigt“, die Liste schließt
  die Lücke weich.
- Gewohnheiten: Serie (Streak) zählt sichtbar hoch; bei allen Gewohnheiten des Tages oder einer runden Serie
  ein kleiner Konfetti- oder Funken-Effekt.
- Wieder öffnen läuft rückwärts ab. Haptik wie bei `Pressable`; „Animationen reduzieren“ beachten.

## Mehr Sprachen: Deutsch, Englisch, Spanisch, Französisch, Italienisch

Die App gibt es bisher nur auf Deutsch und Englisch. Dazu kommen Spanisch, Französisch und Italienisch – weitere
Sprachen später.

- **Übersetzungen**: neue Dateien `lib/l10n/app_es.arb`, `app_fr.arb`, `app_it.arb` mit allen Schlüsseln aus
  `app_de.arb` (Platzhalter und Mehrzahl-Formen mitnehmen), danach `flutter gen-l10n`. Texte der Android-Widgets
  (Zusammenfassung `widget.v1`) und Datumsformate (`Fmt`) mit prüfen.
- **Einstellung**: `SettingsStore.lang` erlaubt alle fünf Codes; beim ersten Start die Sprache des Geräts nehmen,
  wenn sie dabei ist, sonst Englisch.
- **Sprachauswahl als eigene Seite** (Optionen → Sprache) statt Balken: untereinander Karten mit runder Flagge,
  dem Namen in der eigenen Sprache (*Deutsch, English, Español, Français, Italiano*) und rechts klein dem Namen in
  der eingestellten Sprache, z. B. „(Spanisch)“. Die gewählte Karte hat einen Rahmen in der Primärfarbe und einen
  Haken; oben rechts ein Fertig-Haken. Darunter „Wie das Gerät“. Antippen wechselt sofort.
- **Installer** (Windows, `tool/release/installer.iss`): unter `[Languages]` zusätzlich Spanisch, Französisch und
  Italienisch (`compiler:Languages\Spanish.isl`, `French.isl`, `Italian.isl`). Beim Start fragt der Installer
  „Setup-Sprache auswählen“ mit allen fünf Sprachen (`ShowLanguageDialog=yes`); eigene Texte wie „Desktop-Symbol“
  in jeder Sprache unter `[CustomMessages]`. Die gewählte Sprache wird beim ersten Start als App-Sprache übernommen.
- **Tests**: Goldens zusätzlich in einer neuen Sprache (lange französische Wörter prüfen), Test, dass alle ARB-Dateien
  dieselben Schlüssel haben.
- Entwurf mit Bildschirmen: Design-Konzept „ToDo Planer – Konzept“ (Sprache wählen, Installer: Sprache).
