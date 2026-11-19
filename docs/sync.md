# Auf allen Geräten: eigene Datenbank (Supabase, kostenlos)

Die App zeigt diese Schritte auch selbst an („Datenbank verbinden“).

1. Auf [supabase.com](https://supabase.com/dashboard) registrieren und ein **neues Projekt** anlegen.
2. Im Projekt den **SQL Editor** öffnen. In der App auf **„SQL kopieren“** tippen (oder den Inhalt von [`supabase/schema.sql`](../supabase/schema.sql) nehmen), einfügen und auf **Run** klicken. Das legt alle Tabellen samt Zugriffsschutz (Row Level Security) an. Das Skript kann gefahrlos noch einmal ausgeführt werden.
3. Unter **Project Settings → API Keys** die **Project URL** (`https://….supabase.co`) und den **Publishable Key** (`sb_publishable_…`, bei älteren Projekten der `anon`-Key `eyJ…`) kopieren und in der App einfügen.
   **Niemals den Secret Key (`sb_secret_…` / `service_role`) eingeben** – die App lehnt ihn ab.
4. In der App ein Konto erstellen (einmalig, danach bleibt man angemeldet). Auf jedem weiteren Gerät beim ersten Start **„Ich habe schon ein Konto“** wählen, dieselbe URL und denselben Key eingeben und anmelden.
5. Danach in Supabase unter **Authentication → Sign In / Providers** die Option **„Allow new users to sign up“** ausschalten. Dann kann sich niemand sonst ein Konto in deiner Datenbank anlegen.

Auf weiteren Geräten: gleiche URL und gleichen Key eingeben und mit demselben Konto **anmelden**.

## So funktioniert der Abgleich

- Jede Änderung landet zuerst in der lokalen Datenbank (drift/SQLite) und in einer Warteschlange.
- Sobald das Gerät online ist, werden Änderungen hochgeladen.
- Ändern zwei Geräte dieselbe Aufgabe, gelten beide Änderungen, solange es verschiedene Felder sind (siehe unten). Beim selben Feld gewinnt die neuere Änderung.
- Über Supabase Realtime bekommen andere Geräte Änderungen sofort mit.
- Offline zeigt die App eine kurze Meldung und ein Wolken-Symbol bei Aufgaben, die noch warten.

## Zwei Geräte ändern dieselbe Aufgabe

Beispiel: Du änderst offline am Handy den **Titel** und am PC das **Datum** derselben Aufgabe. Früher gewann die ganze Zeile mit der neueren Änderung, die andere ging verloren. Jetzt bleiben beide.

- Die App merkt sich je Feld, wann es zuletzt geändert wurde (Spalte `field_times`, ein kleines JSON wie `{"title": "…", "due": "…"}`).
- Beim Abgleich gewinnt **je Feld** der neuere Wert – am Gerät (`lib/data/field_merge.dart`) und in der Datenbank (Trigger `sync_guard` in [`supabase/schema.sql`](../supabase/schema.sql)) mit derselben Regel. In welcher Reihenfolge die Geräte hochladen, ist egal.
- Was zusammengehört, zählt als ein Feld: **Datum und Uhrzeit**, **erledigt und der Zeitpunkt des Abhakens**, beim Wochenplan **Tag, Zeit und Wiederholung**.
- Das gilt für Aufgaben, Unteraufgaben, Kategorien, Gewohnheiten und Wochenblöcke. Die Haken der Gewohnheiten und die Einstellungen haben nur einen Stand – dort gewinnt wie bisher der neuere.
- **Löschen gegen Bearbeiten:** Löscht ein Gerät die Aufgabe und das andere ändert sie, bleibt sie gelöscht. Die Änderung ist trotzdem gespeichert – machst du das Löschen rückgängig, ist sie da.
- **Ältere App-Versionen und alte Zeilen** haben keine Zeitstempel je Feld. Dann gilt wie früher: Die ganze Zeile mit der neueren Änderung gewinnt.
- Die Uhren der Geräte sollten ungefähr stimmen – „neuer“ heißt: laut Uhr des Geräts, das geändert hat. Haben zwei Änderungen am selben Feld exakt denselben Zeitpunkt, gilt die, die zuerst in der Datenbank war.
- **Alle Geräte aktualisieren:** Eine ältere App-Version bekommt eine eingemischte ältere Änderung an einem anderen Feld nicht mit und kann sie bei ihrer nächsten Änderung an derselben Aufgabe überschreiben.

## Ältere erledigte Aufgaben liegen nur online

Damit die Daten am Gerät klein bleiben, behält die App erledigte Aufgaben nur **7 Tage** lokal. Danach liegen sie (samt Unteraufgaben) nur noch in deiner Supabase-Datenbank.

- Das gilt nur im Modus „Auf allen Geräten“ mit angemeldetem Konto. Im Modus „Nur auf diesem Gerät“ bleibt alles am Gerät.
- Vom Gerät genommen wird eine Aufgabe erst, wenn sie hochgeladen ist. Was noch in der Warteschlange steht, bleibt liegen.
- Das ist **kein Löschen**: In Supabase ändert sich dabei nichts.
- Im Abschnitt „Erledigt“ und im Kalender steht ein Knopf **„… ältere erledigte Aufgaben laden“**. Er holt sie seitenweise vom Server – nur zum Anzeigen, nicht zurück in den Gerätespeicher. Offline steht dort der Hinweis, dass sie nur online sichtbar sind. Auch die Suche findet ältere erst, nachdem sie geladen sind.
- Hakst du eine solche Aufgabe wieder auf oder bearbeitest sie, liegt sie wieder ganz normal am Gerät und wird abgeglichen.
- **Statistik und Heatmap stimmen auch offline**: Am Gerät bleibt pro ausgelagerter Aufgabe ein kleiner Merkzettel (Tag des Abhakens, Kategorie, Abgabetag – kein Titel, keine Notiz). Daraus zählt die Statistik. Dieser Merkzettel wird nicht abgeglichen.
- Auf einem neuen Gerät werden ältere erledigte Aufgaben gar nicht erst gespeichert; beim ersten Abgleich entstehen nur die Merkzettel.
- Der Export enthält online auch die älteren. Offline fehlen sie – das steht dann im Export und in der Meldung.
- „Erledigte löschen“ löscht die erledigten Aufgaben, die gerade zu sehen sind (auch nachgeladene). Ältere, die nicht geladen sind, bleiben online liegen.

## Nach einem Update der App

Bringt eine neue Version neue Spalten mit, zeigt die App den Hinweis „Die Datenbank ist älter als die App“. Dann [`supabase/schema.sql`](../supabase/schema.sql) noch einmal komplett im SQL Editor ausführen – bestehende Daten bleiben erhalten.

Für das feldweise Zusammenführen (Spalte `field_times`) gilt: Bis das Skript ausgeführt ist, gleicht die App weiter ab, aber wie früher mit der ganzen Zeile.


---

[← Zurück zum README](../README.md)
