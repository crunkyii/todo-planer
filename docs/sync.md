# Auf allen Geräten: eigene Datenbank (Supabase, kostenlos)

Die App zeigt diese Schritte auch selbst an („Datenbank verbinden“).

1. Auf [supabase.com](https://supabase.com/dashboard) registrieren und ein **neues Projekt** anlegen.
2. Im Projekt den **SQL Editor** öffnen. In der App auf **„SQL kopieren“** tippen (oder den Inhalt von [`supabase/schema.sql`](../supabase/schema.sql) nehmen), einfügen und auf **Run** klicken. Das legt alle Tabellen samt Zugriffsschutz (Row Level Security) an. Das Skript kann gefahrlos noch einmal ausgeführt werden.
3. Unter **Project Settings → API Keys** die **Project URL** (`https://….supabase.co`) und den **Publishable Key** (`sb_publishable_…`, bei älteren Projekten der `anon`-Key `eyJ…`) kopieren und in der App einfügen.
   **Niemals den Secret Key (`sb_secret_…` / `service_role`) eingeben** – die App lehnt ihn ab.
4. In der App ein Konto erstellen (einmalig, danach bleibt man angemeldet).
5. Danach in Supabase unter **Authentication → Sign In / Providers** die Option **„Allow new users to sign up“** ausschalten. Dann kann sich niemand sonst ein Konto in deiner Datenbank anlegen.

Auf weiteren Geräten: gleiche URL und gleichen Key eingeben und mit demselben Konto **anmelden**.

## So funktioniert der Abgleich

- Jede Änderung landet zuerst in der lokalen Datenbank (drift/SQLite) und in einer Warteschlange.
- Sobald das Gerät online ist, werden Änderungen hochgeladen; die neueste Änderung gewinnt.
- Über Supabase Realtime bekommen andere Geräte Änderungen sofort mit.
- Offline zeigt die App eine kurze Meldung und ein Wolken-Symbol bei Aufgaben, die noch warten.

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


---

[← Zurück zum README](../README.md)
