# Datenschutz

**Kurz: Deine Aufgaben gehören dir. Die App schickt nichts an den Entwickler oder an Dritte.**

## Nur auf diesem Gerät

In diesem Modus bleibt alles in einer SQLite-Datenbank am Gerät. Es wird nichts abgeglichen und nichts übertragen.

## Auf allen Geräten

In diesem Modus gleicht die App mit **deiner eigenen** Supabase-Datenbank ab – einem Projekt, das du selbst anlegst und das nur dir gehört.

- Adresse und Key der Datenbank gibst du in der App ein; sie werden nur am Gerät gespeichert und stehen nirgends im Code.
- Die App nimmt nur den öffentlichen „Publishable Key“ an. Den geheimen Key (`sb_secret_…` / `service_role`) lehnt sie ab.
- In der Datenbank schützt Row Level Security jede Zeile: Jedes Konto sieht und ändert nur seine eigenen Daten ([`supabase/schema.sql`](../supabase/schema.sql)).
- Übertragen werden Aufgaben, Unteraufgaben, Notizen, Kategorien, Gewohnheiten, Wochenplan und Einstellungen – sonst nichts.

## Was die App nicht macht

- Keine Werbung, keine Analyse- oder Tracking-Dienste, keine Absturzberichte an Dritte.
- Kein Konto beim Entwickler, keine Registrierung außerhalb deiner eigenen Datenbank.

## Berechtigungen (Android)

| Berechtigung | Wofür |
|---|---|
| Internet | Abgleich mit deiner Supabase-Datenbank (nur im Modus „Auf allen Geräten“) |
| Benachrichtigungen | Erinnerungen für Aufgaben mit Uhrzeit |
| Start nach dem Einschalten | Geplante Erinnerungen nach einem Neustart wiederherstellen |

## Export und Löschen

Der Export (PDF, Text, CSV) wird nur dort gespeichert, wo du ihn hinlegst. Deinstallierst du die App, sind die Daten am Gerät weg; Daten in deiner Supabase-Datenbank löschst du dort.


---

[← Zurück zum README](../README.md)
