# Datenschutz

**Kurz: Deine Aufgaben gehören dir. Die App schickt keine Daten an den Entwickler oder an Dritte.**

## Nur auf diesem Gerät

In diesem Modus bleibt alles in einer SQLite-Datenbank am Gerät. Es wird nichts abgeglichen und nichts übertragen.

## Auf allen Geräten

In diesem Modus gleicht die App mit **deiner eigenen** Supabase-Datenbank ab – einem Projekt, das du selbst anlegst und das nur dir gehört.

- Adresse und Key der Datenbank gibst du in der App ein; sie werden nur am Gerät gespeichert und stehen nirgends im Code.
- Die App nimmt nur den öffentlichen „Publishable Key“ an. Den geheimen Key (`sb_secret_…` / `service_role`) lehnt sie ab.
- In der Datenbank schützt Row Level Security jede Zeile: Jedes Konto sieht und ändert nur seine eigenen Daten ([`supabase/schema.sql`](../supabase/schema.sql)).
- Übertragen werden Aufgaben, Unteraufgaben, Notizen, Kategorien, Gewohnheiten, Wochenplan und Einstellungen – sonst nichts. Dazu gehört je Eintrag, wann welches Feld zuletzt geändert wurde (damit Änderungen von zwei Geräten zusammenpassen).
- Erledigte Aufgaben, die vor mehr als 7 Tagen abgehakt wurden, liegen nur noch in deiner Datenbank und nicht mehr am Gerät. Am Gerät bleibt dafür nur ein Merkzettel für die Statistik (Tag, Kategorie, Abgabetag – ohne Titel und Notiz). Details: [sync.md](sync.md).

## Update-Prüfung (Windows und Android)

Die mit dem Installer installierte Windows-App und die Android-App von der Release-Seite fragen beim Start bei GitHub nach, ob es eine neuere Version gibt, und laden sie von dort, wenn du auf **Installieren** tippst. Dabei wird nur eine Datei abgerufen – die App schickt nichts mit: keine Aufgaben, keine Kennung, kein Konto. GitHub sieht dabei wie jede Website deine IP-Adresse ([Datenschutzerklärung von GitHub](https://docs.github.com/de/site-policy/privacy-policies/github-general-privacy-statement)). Unter Android liegt die geladene Datei nur im eigenen Cache der App und wird beim nächsten Start gelöscht. Selbst gebaute Apps und die Test-Version prüfen nicht auf Updates. Details: [update.md](update.md).

## Was die App nicht macht

- Keine Werbung, keine Analyse- oder Tracking-Dienste, keine Absturzberichte an Dritte.
- Kein Konto beim Entwickler, keine Registrierung außerhalb deiner eigenen Datenbank.

## Berechtigungen (Android)

| Berechtigung | Wofür |
|---|---|
| Internet | Abgleich mit deiner Supabase-Datenbank (nur im Modus „Auf allen Geräten“) und Update-Prüfung |
| Benachrichtigungen | Erinnerungen für Aufgaben mit Uhrzeit |
| Start nach dem Einschalten | Geplante Erinnerungen nach einem Neustart wiederherstellen |
| Apps installieren (`REQUEST_INSTALL_PACKAGES`) | Nur fürs Update: die geprüfte neue Version an den Installer von Android übergeben. Gilt erst, wenn du es unter „Unbekannte Apps installieren“ einschaltest, und jede Installation bestätigst du selbst. |

## Export und Löschen

Der Export (PDF, Text, CSV) wird nur dort gespeichert, wo du ihn hinlegst. Deinstallierst du die App, sind die Daten am Gerät weg; Daten in deiner Supabase-Datenbank löschst du dort.


---

[← Zurück zum README](../README.md)
