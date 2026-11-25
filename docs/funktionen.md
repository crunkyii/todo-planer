# Was die App kann

## Aufgaben

- **Kategorien** mit Farbe. Jede Kategorie hat einen **Vorlauf**: Eine Hausübung mit „1 Tag vorher erledigen“ steht schon am Vortag in der Liste.
- **In Aufgaben zeigen**: Pro Kategorie einstellbar, ab welcher Gruppe ihre Aufgaben in der Liste stehen – *Immer*, ab *Diese Woche*, ab *Morgen*, ab *Heute* oder *Nie*. So stehen z. B. Geburtstage erst in der Woche in der Liste, in der sie sind. Die Suche, der Chip der Kategorie und der Kalender zeigen immer alles; beim ersten Mal steht unten in der Liste ein Hinweis, wie viele Aufgaben gerade ausgeblendet sind. Er bleibt bis zum Schließen (✕) oder Beenden der App und kommt danach an diesem Gerät nicht wieder.
- **Gruppen**: Überfällig, Heute, Morgen, Diese Woche, Später, Erledigt – oder sortiert nach Kategorie oder Name.
- **Uhrzeit** und **Benachrichtigung**: Je Aufgabe einstellbar (unter Datum und Uhrzeit) – *Keine*, *Zum Zeitpunkt*, 5 Minuten bis 1 Tag vorher oder eine eigene Zeit in Minuten (höchstens 7 Tage). Dazu braucht die Aufgabe eine Uhrzeit, aber keinen Block im Wochenplan.
- **Unteraufgaben** zum einzeln Abhaken.
- **Notiz**: Über das Notiz-Symbol neben den Unteraufgaben lässt sich ein längerer Text dazuschreiben. Die Karte zeigt die ersten zwei Zeilen, die Suche findet auch Text aus Notizen.
- **Jährliche Aufgaben**: Steht „Geburtstag“, „Jahrestag“ o. Ä. im Titel, entsteht beim Abhaken dieselbe Aufgabe fürs nächste Jahr.
- **Suche** und **Rückgängig** nach dem Löschen (gelöscht wird im Formular der Aufgabe).
- **Am PC** stehen die Gruppen als Listen nebeneinander. Unter ⋮ → *Spalten* stellt man ein, wie viele gleichzeitig zu sehen sind, welche Zeiträume es gibt und welche Kategorien eine eigene Spalte bekommen (gilt nur an diesem Gerät). Die Reihenfolge ändert man, indem man die Überschrift einer Spalte kurz gedrückt hält (Maus oder Finger) und sie an die gewünschte Stelle zieht – ein kurzer Klick oder Wisch verschiebt nichts. In einem schmalen Fenster passen weniger Spalten nebeneinander als eingestellt. Am Handy gibt es unter ⋮ → *Spalten* dieselben Zeiträume und Kategorien als Abschnitte; die Reihenfolge ändert man dort mit langem Druck auf eine Überschrift und Ziehen.

## Gewohnheiten

Tägliche Gewohnheiten zum Abhaken, mit Serien-Flamme für aufeinanderfolgende Tage.

## Kalender, Wochenplan, Statistik

- **Kalender** mit allen Aufgaben und den österreichischen Feiertagen.
- **Wochenplan** mit Zeitblöcken (einmalig oder jede Woche), Raster 5, 15 oder 30 Minuten. Beim Anlegen eines Blocks stehen die **Aufgaben des gewählten Tags** zur Auswahl – samt dem Vorlauf ihrer Kategorie: Ein Test mit zwei Tagen Vorlauf steht an beiden Tagen davor und am Abgabetag, eine Hausübung mit einem Tag Vorlauf auch am Tag davor (dort mit „Abgabe …“ dahinter). Antippen übernimmt den Namen; am Abgabetag bekommt die Aufgabe außerdem die Von-Zeit als Uhrzeit, an den Tagen davor bleibt ihre Abgabezeit.
- **„+“ bei „Aufgaben an diesem Tag“** öffnet die Seite *Aufgaben für diesen Tag*: alle offenen Aufgaben ab diesem Tag (bzw. ab heute), nach Datum sortiert, mit Filter-Chips nach Kategorie. Die gewählten kommen im Blatt als weitere Chips dazu, die erste ist gleich ausgewählt (Name und Farbe des Blocks wie bei den anderen Chips). An den Aufgaben selbst wird nichts gespeichert – auch ihre Uhrzeit bleibt, weil der Block nicht am Abgabetag liegt.
- **Block ansehen**: Kurz auf einen Block tippen öffnet seine Ansicht – Tag, Uhrzeit mit Dauer und ob er jede Woche oder nur in einer Woche ist. Ist der Block aus einer Aufgabe entstanden, steht diese Aufgabe darunter wie in der Liste: Abgabe, Unteraufgaben (abhakbar) und Notiz; Antippen öffnet die ganze Aufgabe. *Bearbeiten* und *Löschen* (mit Rückgängig) stehen im ⋮-Menü oben rechts – nichts geht beim Antippen gleich in den Bearbeiten-Modus. Gibt es die Aufgabe nicht mehr, steht das dort. Die Verbindung zur Aufgabe wird abgeglichen (Spalte `week_blocks.task_id`, kommt mit dem aktuellen `schema.sql`; ohne sie bleibt sie nur am Gerät).
- **Benachrichtigung vor einem Block**: Dieselbe Auswahl steht im Formular des Blocks (Standard: *Keine*). Blöcke werden zwei Wochen im Voraus geplant, bei jedem Start der App neu. Ist die Aufgabe dazu erledigt, kommt keine.
- **Pünktliche Benachrichtigungen** (Android, Optionen → Erinnerungen): Freiwillige Erlaubnis „Wecker und Erinnerungen“, dann kommt die Benachrichtigung auf die Minute. Ohne sie kommt sie trotzdem, aber manchmal etwas später. Wird die Erlaubnis in den Systemeinstellungen entzogen, löscht Android die geplanten genauen Benachrichtigungen; beim nächsten Öffnen plant die App alle neu. Der Schalter in der App hat diesen Nachteil nicht.
- **Blöcke verschieben**: Lange auf einen Block drücken (Finger oder Maus) und nach oben oder unten ziehen. Er springt in Schritten des eingestellten Rasters, die Dauer bleibt gleich, und er bleibt zwischen „Tag beginnt“ und „Tag endet“. Beim Ziehen steht die neue Uhrzeit über dem Block; danach kommt „Block verschoben auf …“ mit *Rückgängig*. Ein wöchentlicher Block wandert in allen Wochen mit. Ohne Maus/Finger geht das Verschieben über die Von-/Bis-Zeit beim Bearbeiten.
- **Wochenbeginn** frei wählbar (Optionen → *Woche beginnt am*, gilt nur an diesem Gerät) – für Wochenplan, Kalender und die Gruppe „Diese Woche“.
- **Uhrzeit am PC tippen**: Im Zeitrad einfach Ziffern eingeben, z. B. `1430`.
- **Statistik** mit Heatmap, Diagramm der erledigten Aufgaben und Serien.

## Startbildschirm-Widgets (Android)

Vier Widgets: „Heute“, „Demnächst“, Zähler und Gewohnheiten zum Abhaken. Form, Farbe und Durchsichtigkeit sind einstellbar. In den Einstellungen eines Listen-Widgets (Widget gedrückt halten → „Einstellungen“) lässt sich unter **Inhalt** jederzeit umstellen, ob es *Heute*, *Demnächst* oder *Gewohnheiten* zeigt. Bei *Demnächst* legt der **Zeitraum** fest, wie weit es in die Zukunft schaut (*3 Tage*, *1 Woche*, *2 Wochen*, *1 Monat* oder *Alles*); Überfälliges steht immer drin, und die Zahl oben zählt nur, was im Widget steht.

## Steuern über Flick (Windows)

[Flick](https://github.com/Whiskey-Bravo/flick) ist ein Tastatur-Launcher für Windows (Alt+Leertaste, MIT-Lizenz). Die App lässt sich darüber öffnen und steuern:

| In Flick eintippen | Was passiert |
|---|---|
| `addAufgabe` | Die App kommt nach vorne (oder startet) und das Formular *Neue Aufgabe* ist offen. |
| `Aufgaben` | Die heutigen und überfälligen Aufgaben stehen **direkt in der Flick-Leiste** (oben eine Zeile mit Datum und Anzahl). Enter auf einer Zeile öffnet die App im Tab *Aufgaben*, scrollt zu dieser Aufgabe und lässt ihre Karte kurz größer werden und leuchten (bei „Animationen reduzieren“ nur leuchten). |
| `todo` → `Aufgaben`, `Kalender`, `Wochenplan`, `Statistik`, `Optionen` | Die App öffnet in diesem Tab. Man kann auch gleich `todo kal` tippen. |

**Einrichten (einmal):**

1. Die App mit dem Installer ab dieser Version installieren – er trägt die Links `todoplaner://…` in Windows ein.
2. In der App: *Optionen → Flick → Heutige Aufgaben für Flick* einschalten.
3. *Optionen → Flick → Flick-Shortcuts kopieren* antippen. Die App kopiert die Shortcuts, legt ihre drei Symbole in `%LOCALAPPDATA%\ToDo Planer\Flick\Icons` ab und öffnet die Seite **„Flick einrichten“** mit den Schritten, dem Schalter für die Liste und einer Vorschau, was man in Flick eintippen kann (mit den Symbolen). Dort gibt es auch „Nochmal kopieren“.
4. In Flick `flick config` eintippen (öffnet die `config.toml`), den kopierten Text ans Ende einfügen und speichern. Flick übernimmt das sofort. Waren die Shortcuts schon einmal drin, vorher den alten Block löschen. (Man kann die Shortcuts auch in Flick unter *Settings → Shortcuts* von Hand anlegen.)

Jeder Shortcut hat ein eigenes Symbol (`icon = …` in der `config.toml`): *Aufgabe hinzufügen* für `addAufgabe`, *Aufgaben anzeigen* für `Aufgaben`, *ToDo Planer öffnen* für `todo`. Die Dateien liegen in der App unter [`assets/flick`](../assets/flick). Fehlt eine, zeigt Flick sein eigenes Symbol.

Die Vorlage mit Erklärungen liegt auch unter [`tool/flick/todo-planer.toml`](../tool/flick/todo-planer.toml) – dort muss man die Pfade bei `pick` und `icon` selbst anpassen; die kopierte Version aus der App hat sie schon richtig.

**So funktioniert es:**

- **Links:** `todoplaner://add`, `todoplaner://add?title=…` und `todoplaner://tab/<Tab>` (Tabs deutsch oder englisch: `aufgaben`/`tasks`, `kalender`/`calendar`, `woche`/`wochenplan`/`week`, `statistik`/`stats`, `optionen`/`settings`). Ein Link kann nur etwas **zeigen**, nie etwas speichern oder löschen – auch wenn eine Webseite so einen Link anbietet, passiert nichts ohne eigenes Tippen.
- **Nur eine App:** Läuft die App schon, startet ein Link keine zweite. Der zweite Start reicht den Link an das offene Fenster weiter, holt es nach vorne und beendet sich gleich wieder. Ist gerade ein Formular offen, bleibt es offen (nichts Getipptes geht verloren).
- **Heutige Aufgaben:** Flick kann keine Daten von einem Programm abfragen. Ein Flick-Shortcut mit `pick` zeigt aber die Unterordner eines Ordners als Liste. Darum legt die App bei jeder Änderung (und um Mitternacht) in `%LOCALAPPDATA%\ToDo Planer\Flick\Heute` für jede Zeile einen leeren Ordner an – z. B. `14∶00 Max Mustermann anrufen`. Vorne steht unsichtbar eine Nummer, die die Reihenfolge hält (Flick sortiert nach Namen), Zeichen, die in Ordnernamen verboten sind, werden durch ähnlich aussehende ersetzt. Flick liest nur diese Ordner, nie die Datenbank oder Supabase. Schaltet man die Option aus, löscht die App die Ordner wieder (nur leere – eigene Dateien darin bleiben).
- **Grenzen:** Die Liste ist so aktuell wie die App: Ist die App geschlossen, steht dort der letzte Stand (die Kopfzeile zeigt das Datum). Flick liest den Ordner beim Öffnen der Liste neu ein und sonst alle 5 Minuten – direkt nach einer Änderung kann einmal noch der alte Stand kommen. Höchstens 49 Aufgaben passen in die Liste.

## Export

Alle Daten als PDF, Text oder CSV (für Excel).

## Aussehen und Sprache

10 Themes, hell/dunkel/System. Sprachen: Deutsch, Englisch, Spanisch, Französisch und Italienisch – unter Optionen → **Sprache** (oder beim ersten Start) als Karten mit Flagge; „Wie das Gerät“ nimmt die Sprache des Handys bzw. PCs. Beim ersten Start gilt die Sprache des Geräts (sonst Englisch), unter Windows die im Installer gewählte. Auswahlen in den Optionen und Formularen sind Zeilen mit dem gewählten Wert, die beim Antippen ein Menü öffnen. Alle Bedienelemente haben Beschriftungen für Screenreader.


---

[← Zurück zum README](../README.md)
