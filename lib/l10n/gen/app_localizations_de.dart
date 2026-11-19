// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'ToDo Planer';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get undo => 'Rückgängig';

  @override
  String get add => 'Hinzufügen';

  @override
  String get added => 'Hinzugefügt';

  @override
  String get saved => 'Gespeichert';

  @override
  String get itemGone => 'Dieser Eintrag wurde inzwischen gelöscht.';

  @override
  String get back => 'Zurück';

  @override
  String get all => 'Alle';

  @override
  String get name => 'Name';

  @override
  String get color => 'Farbe';

  @override
  String get customColor => 'Eigene Farbe';

  @override
  String get chooseCustomColor => 'Eigene Farbe wählen';

  @override
  String get apply => 'Übernehmen';

  @override
  String get hue => 'Farbton';

  @override
  String get saturation => 'Sättigung';

  @override
  String get brightness => 'Helligkeit';

  @override
  String get none => 'Keine';

  @override
  String get timeNone => 'Ohne';

  @override
  String get done => 'Erledigt';

  @override
  String get reopened => 'Wieder offen';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get mainNavigation => 'Hauptnavigation';

  @override
  String get navTasks => 'Aufgaben';

  @override
  String get navCalendar => 'Kalender';

  @override
  String get navWeek => 'Woche';

  @override
  String get navStats => 'Statistik';

  @override
  String get navSettings => 'Optionen';

  @override
  String get weeklyPlan => 'Wochenplan';

  @override
  String get statistics => 'Statistik';

  @override
  String get settings => 'Einstellungen';

  @override
  String get welcome => 'Willkommen';

  @override
  String get setupLead => 'Wo sollen deine Aufgaben gespeichert werden?';

  @override
  String get setupCloudText =>
      'Eigene kostenlose Supabase-Datenbank. Handy und PC bleiben gleich, auch offline nutzbar.';

  @override
  String get setupLocalTitle => 'Nur auf diesem Gerät';

  @override
  String get setupLocalText => 'Kein Konto, keine Einrichtung. Später in den Optionen umstellbar.';

  @override
  String get languageBoth => 'Sprache · Language';

  @override
  String get connectDb => 'Datenbank verbinden';

  @override
  String get connectOtherDb => 'Andere Datenbank verbinden';

  @override
  String get openSupabase => 'supabase.com öffnen';

  @override
  String get connectExistingLead =>
      'Dein Konto liegt in deiner eigenen Datenbank. Damit dich dieses Gerät anmelden kann, braucht es zuerst ihre <b>Project URL</b> und den <b>Publishable Key</b> – dieselben wie auf deinem ersten Gerät. Beide stehen in deinem Supabase-Projekt.';

  @override
  String get copySql => 'SQL kopieren';

  @override
  String get sqlCopied => 'SQL kopiert – jetzt im SQL Editor einfügen';

  @override
  String get connect => 'Verbinden';

  @override
  String get connecting => 'Verbinde …';

  @override
  String get setupStep1 => 'Auf <b>supabase.com</b> kostenlos registrieren und ein <b>neues Projekt</b> anlegen.';

  @override
  String get setupStep2 =>
      'Im Projekt <b>SQL Editor</b> öffnen, das SQL einfügen und auf <b>Run</b> tippen. Damit werden die Tabellen angelegt.';

  @override
  String get setupStep3 =>
      '<b>Project URL</b>: oben im Projekt auf <b>Connect</b> tippen oder <b>Project Settings → Data API</b> öffnen. Sie sieht so aus: https://abcdefgh.supabase.co – der Teil vor „.supabase.co“ ist die <b>Project ID</b> (Project Settings → General). <b>Publishable Key</b>: unter <b>Project Settings → API Keys</b>, beginnt mit sb_publishable_. Beides kopieren und unten einfügen.';

  @override
  String get setupStep4 =>
      'Nach deiner Registrierung: <b>Authentication → Sign In / Providers</b> → <b>„Allow new users to sign up“</b> ausschalten. Dann kann sich niemand sonst ein Konto in deiner Datenbank anlegen.';

  @override
  String get secretNote => 'Niemals den <b>Secret Key</b> (service_role) eingeben – der gehört nicht in eine App.';

  @override
  String get projectUrl => 'Project URL';

  @override
  String get publishableKey => 'Publishable Key';

  @override
  String get projectUrlHint => 'https://abcdefgh.supabase.co';

  @override
  String get publishableKeyHint => 'sb_publishable_…';

  @override
  String get errUrl => 'Die Project URL sieht so aus: https://abcdefgh.supabase.co';

  @override
  String get errKeyFormat => 'Der Key beginnt mit „sb_publishable_“ (oder bei älteren Projekten mit „eyJ“).';

  @override
  String get errSecretKey => 'Das ist der geheime Schlüssel. Bitte den Publishable Key nehmen.';

  @override
  String get errNoConnection => 'Keine Verbindung. Stimmt die URL und wurde das SQL ausgeführt?';

  @override
  String connectedTo(String host) {
    return 'Verbunden mit $host';
  }

  @override
  String get signIn => 'Anmelden';

  @override
  String get signUp => 'Registrieren';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get haveAccount => 'Ich habe schon ein Konto';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort verbergen';

  @override
  String get errEmail => 'Bitte gib eine gültige E-Mail-Adresse ein.';

  @override
  String get errPassword => 'Bitte gib dein Passwort ein.';

  @override
  String get errPasswordShort => 'Das Passwort braucht mindestens 6 Zeichen.';

  @override
  String get errPasswordLong => 'Das Passwort ist zu lang (höchstens 72 Zeichen).';

  @override
  String get errWrongLogin => 'E-Mail oder Passwort ist falsch.';

  @override
  String get accountCreatedHint => 'Konto erstellt. Jetzt in Supabase „Allow new users to sign up“ ausschalten.';

  @override
  String get confirmEmailHint =>
      'Fast geschafft: Bitte bestätige deine E-Mail-Adresse über den Link in der Mail und melde dich dann an.';

  @override
  String get errNetwork => 'Keine Verbindung zum Server. Bitte prüfe deine Internetverbindung.';

  @override
  String get errEmailNotConfirmed => 'Bitte bestätige zuerst deine E-Mail-Adresse (Link in der Bestätigungs-Mail).';

  @override
  String get errAccountExists => 'Für diese E-Mail-Adresse gibt es bereits ein Konto. Bitte melde dich an.';

  @override
  String get errWeakPassword => 'Das Passwort ist zu schwach. Verwende mindestens 6 Zeichen.';

  @override
  String get errRateLimit => 'Zu viele Versuche. Bitte warte kurz und versuche es dann erneut.';

  @override
  String get errSignupDisabled => 'Registrierung ist in dieser Datenbank ausgeschaltet.';

  @override
  String get errSessionExpired => 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String errAuthGeneric(String message) {
    return 'Anmeldung fehlgeschlagen: $message';
  }

  @override
  String get errNoPermission => 'Keine Berechtigung für diese Aktion. Bitte melde dich erneut an.';

  @override
  String get errTableMissing =>
      'In der Datenbank fehlen Tabellen. Bitte das SQL aus der Einrichtung noch einmal ausführen.';

  @override
  String errDbGeneric(String message) {
    return 'Datenbankfehler: $message';
  }

  @override
  String get errUnexpected => 'Unerwarteter Fehler. Bitte versuche es erneut.';

  @override
  String get today => 'Heute';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get yesterday => 'Gestern';

  @override
  String get overdue => 'Überfällig';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get later => 'Später';

  @override
  String sectionCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get newTask => 'Neue Aufgabe';

  @override
  String get editTask => 'Aufgabe bearbeiten';

  @override
  String get deleteTask => 'Aufgabe löschen';

  @override
  String get task => 'Aufgabe';

  @override
  String get errTaskTitle => 'Bitte gib ein, was zu tun ist.';

  @override
  String get nothingDue => 'Nichts fällig.';

  @override
  String get widgetUpcoming => 'Demnächst';

  @override
  String widgetUntil(String when) {
    return 'bis: $when';
  }

  @override
  String get widgetNoHabits => 'Noch keine Gewohnheiten.';

  @override
  String get widgetSettings => 'Widget einstellen';

  @override
  String get widgetBackground => 'Hintergrund';

  @override
  String get widgetShowBackground => 'Hintergrund anzeigen';

  @override
  String get widgetShape => 'Form';

  @override
  String get widgetShapeRound => 'Rund';

  @override
  String get widgetShapeSoft => 'Weich';

  @override
  String get widgetShapeSquare => 'Eckig';

  @override
  String get widgetBgColor => 'Hintergrundfarbe';

  @override
  String widgetTransparency(int percent) {
    return 'Transparenz: $percent %';
  }

  @override
  String get widgetColorApp => 'Wie App-Design';

  @override
  String get widgetPreview => 'Vorschau';

  @override
  String get widgetHint =>
      'Halte das Widget am Startbildschirm gedrückt und tippe auf „Einstellungen“, um es später zu ändern.';

  @override
  String get nothingFound => 'Nichts gefunden.';

  @override
  String get noTasks => 'Keine Aufgaben.';

  @override
  String get searchTasks => 'Aufgaben durchsuchen';

  @override
  String get search => 'Suchen';

  @override
  String get closeSearch => 'Suche schließen';

  @override
  String get columns => 'Spalten';

  @override
  String get columnsVisible => 'Nebeneinander sichtbar';

  @override
  String get columnsPeriods => 'Zeiträume';

  @override
  String get columnsCategories => 'Kategorien als eigene Spalte';

  @override
  String get close => 'Schließen';

  @override
  String get columnsAllHidden =>
      'Alle Spalten sind ausgeblendet. Unter ⋮ → Spalten lassen sie sich wieder einschalten.';

  @override
  String get columnsDragHint =>
      'Reihenfolge ändern: die Überschrift einer Spalte kurz gedrückt halten und an die gewünschte Stelle ziehen.';

  @override
  String get moveLeft => 'Nach links verschieben';

  @override
  String get moveRight => 'Nach rechts verschieben';

  @override
  String get columnsNarrowHint => 'In einem schmalen Fenster passen weniger Spalten nebeneinander als eingestellt.';

  @override
  String get columnsDragHintTouch =>
      'Reihenfolge ändern: auf eine Überschrift lange drücken und sie an die gewünschte Stelle ziehen.';

  @override
  String get moveUp => 'Nach oben verschieben';

  @override
  String get moveDown => 'Nach unten verschieben';

  @override
  String get sort => 'Sortieren';

  @override
  String get sortByDate => 'Nach Datum';

  @override
  String get sortByCategory => 'Nach Kategorie';

  @override
  String get sortByName => 'Nach Name (A–Z)';

  @override
  String get filterByCategory => 'Nach Kategorie filtern';

  @override
  String get showCompleted => 'Erledigte anzeigen';

  @override
  String get hideCompleted => 'Erledigte ausblenden';

  @override
  String get completedHidden => 'Erledigte ausgeblendet';

  @override
  String get completedShown => 'Erledigte werden angezeigt';

  @override
  String get deleteCompleted => 'Erledigte löschen';

  @override
  String get noCompleted => 'Keine erledigten Aufgaben';

  @override
  String completedDeleted(int count) {
    return '$count erledigte gelöscht';
  }

  @override
  String get completedTasks => 'Erledigte Aufgaben';

  @override
  String get subtask => 'Unteraufgabe';

  @override
  String get subtasks => 'Unteraufgaben';

  @override
  String get removeSubtask => 'Unteraufgabe entfernen';

  @override
  String get notes => 'Notiz';

  @override
  String get notesHint => 'Mehr zur Aufgabe …';

  @override
  String get schemaOutdated =>
      'Die Datenbank ist älter als die App: In Supabase die Datei schema.sql noch einmal ausführen.';

  @override
  String get dueOn => 'Fällig am';

  @override
  String get dateAndTime => 'Datum und Uhrzeit';

  @override
  String get time => 'Uhrzeit';

  @override
  String get hour => 'Stunde';

  @override
  String get minute => 'Minute';

  @override
  String get quickDate => 'Schnellauswahl Datum';

  @override
  String get quickTime => 'Schnellauswahl Uhrzeit';

  @override
  String get inOneWeek => 'In 1 Woche';

  @override
  String get prevMonth => 'Voriger Monat';

  @override
  String get prevLists => 'Vorherige Listen';

  @override
  String get nextLists => 'Nächste Listen';

  @override
  String get todayAllDone => 'Alles erledigt';

  @override
  String todayOpen(int count) {
    return '$count offen';
  }

  @override
  String todayOpenLate(int count, int late) {
    return '$count offen, davon $late überfällig';
  }

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String a11yDone(String title) {
    return 'Erledigt: $title';
  }

  @override
  String a11yReopen(String title) {
    return 'Wieder öffnen: $title';
  }

  @override
  String a11yCheckSub(String title) {
    return 'Unteraufgabe abhaken: $title';
  }

  @override
  String a11yReopenSub(String title) {
    return 'Unteraufgabe wieder öffnen: $title';
  }

  @override
  String categoryLabel(String name) {
    return 'Kategorie: $name';
  }

  @override
  String deletedItem(String name) {
    return '„$name“ gelöscht';
  }

  @override
  String deletedCatMoved(String name, String target) {
    return '„$name“ gelöscht, Aufgaben → $target';
  }

  @override
  String infoDue(String day) {
    return 'Fällig $day';
  }

  @override
  String infoHandIn(String day) {
    return 'Abgabe $day';
  }

  @override
  String infoListFrom(String info, String day) {
    return '$info · in der Liste ab $day';
  }

  @override
  String dayWithTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String weekdayWithDate(String weekday, String date) {
    return '$weekday, $date';
  }

  @override
  String weekdayShortWithDate(String weekday, String date) {
    return '$weekday $date';
  }

  @override
  String progress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get pendingSyncHint => 'Wird synchronisiert, sobald du online bist';

  @override
  String get habits => 'Gewohnheiten';

  @override
  String get habit => 'Gewohnheit';

  @override
  String get newHabit => 'Neue Gewohnheit';

  @override
  String get editHabit => 'Gewohnheit bearbeiten';

  @override
  String get daily => 'Täglich';

  @override
  String get habitsCheckAll => 'Alle Gewohnheiten für heute abhaken';

  @override
  String get habitsReopenAll => 'Alle Gewohnheiten wieder öffnen';

  @override
  String get habitHint => 'z. B. Wasser trinken';

  @override
  String a11yHabitDoneToday(String name) {
    return '$name heute erledigt';
  }

  @override
  String a11yHabitReopen(String name) {
    return '$name wieder öffnen';
  }

  @override
  String a11yHabitDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get noHabits => 'Noch keine Gewohnheiten – tippe auf +.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Tage', one: '1 Tag');
    return '$_temp0';
  }

  @override
  String get categories => 'Kategorien';

  @override
  String get manageCategories => 'Kategorien verwalten';

  @override
  String get newCategory => 'Neue Kategorie';

  @override
  String get editCategory => 'Kategorie bearbeiten';

  @override
  String get errCategoryExists => 'Diese Kategorie gibt es schon.';

  @override
  String get errName => 'Bitte gib einen Namen ein.';

  @override
  String get categoryHint => 'z. B. Referat';

  @override
  String get catHomework => 'Hausübung';

  @override
  String get catTask => 'Aufgabe';

  @override
  String get catTest => 'Test';

  @override
  String get catAppointment => 'Termin';

  @override
  String get doWhen => 'Erledigen';

  @override
  String get showInTasks => 'In Aufgaben zeigen';

  @override
  String get listFromAlways => 'Immer';

  @override
  String get listFromWeek => 'Ab „Diese Woche“';

  @override
  String get listFromTomorrow => 'Ab „Morgen“';

  @override
  String get listFromToday => 'Ab „Heute“';

  @override
  String get listFromNever => 'Nie';

  @override
  String hiddenByCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben ausgeblendet',
      one: '1 Aufgabe ausgeblendet',
    );
    return '$_temp0 – einstellbar bei der Kategorie';
  }

  @override
  String get offsetSameDay => 'Selber Tag';

  @override
  String offsetDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Tage vorher', one: '1 Tag vorher');
    return '$_temp0';
  }

  @override
  String get offsetWeekBefore => '1 Woche vorher';

  @override
  String catDoSameDay(int open) {
    return 'Am selben Tag erledigen · $open offen';
  }

  @override
  String catDoDaysBefore(int count, int open) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage vorher erledigen · $open offen',
      one: '1 Tag vorher erledigen · $open offen',
    );
    return '$_temp0';
  }

  @override
  String catDoWeekBefore(int open) {
    return '1 Woche vorher erledigen · $open offen';
  }

  @override
  String categoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Kategorien', one: '1 Kategorie');
    return '$_temp0';
  }

  @override
  String get newBlock => 'Neuer Block';

  @override
  String get editBlock => 'Block bearbeiten';

  @override
  String get blockAdded => 'Block angelegt';

  @override
  String blocksAdded(int count) {
    return '$count Blöcke angelegt';
  }

  @override
  String get blockDeleted => 'Block gelöscht';

  @override
  String get from => 'Von';

  @override
  String get to => 'Bis';

  @override
  String timeWithDuration(String duration) {
    return 'Zeit · $duration';
  }

  @override
  String get day => 'Tag';

  @override
  String get days => 'Tage';

  @override
  String get everyWeek => 'Jede Woche';

  @override
  String get repeatEveryWeek => 'Jede Woche wiederholen';

  @override
  String get errToAfterFrom => '„Bis“ muss nach „Von“ liegen.';

  @override
  String get durInvalid => '„Bis“ muss nach „Von“ liegen';

  @override
  String get errPickDay => 'Bitte wähle mindestens einen Tag.';

  @override
  String get tasksThatDay => 'Aufgaben an diesem Tag';

  @override
  String get blockHint => 'Schule, Training …';

  @override
  String get prevWeek => 'Vorige Woche';

  @override
  String get nextWeek => 'Nächste Woche';

  @override
  String get prevDay => 'Voriger Tag';

  @override
  String get nextDay => 'Nächster Tag';

  @override
  String get backToWeek => 'Zurück zur Woche';

  @override
  String showDay(String day) {
    return '$day anzeigen';
  }

  @override
  String weekNumber(int number) {
    return 'KW $number';
  }

  @override
  String dayAndWeek(String day, String week) {
    return '$day · $week';
  }

  @override
  String rangeDash(String from, String to) {
    return '$from – $to';
  }

  @override
  String a11yBlock(String name, String day, String from, String to) {
    return '$name, $day $from bis $to';
  }

  @override
  String durHoursMin(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String durHours(int hours) {
    return '$hours Std.';
  }

  @override
  String durMin(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get quickPlus30 => '+30 Min.';

  @override
  String get quickPlus60 => '+1 Std.';

  @override
  String get quickPlus90 => '+1½ Std.';

  @override
  String get quickPlus120 => '+2 Std.';

  @override
  String get activity => 'Aktivität';

  @override
  String get period => 'Zeitraum';

  @override
  String get less => 'weniger';

  @override
  String get more => 'mehr';

  @override
  String get perDay => 'pro Tag';

  @override
  String get tileDone => 'erledigt';

  @override
  String tileStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Tage Serie', one: 'Tag Serie');
    return '$_temp0';
  }

  @override
  String daysRange(int count) {
    return '$count Tage';
  }

  @override
  String heatSummary(int total, int days) {
    return '<b>$total</b> erledigt an <b>$days</b> Tagen';
  }

  @override
  String heatDay(String date, int count) {
    return '$date: <b>$count</b> erledigt';
  }

  @override
  String a11yHeatDay(String date, int count) {
    return '$date: $count erledigt';
  }

  @override
  String chartA11y(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erledigte Aufgaben',
      one: '1 erledigte Aufgabe',
    );
    return '$_temp0 in $days Tagen';
  }

  @override
  String barTooltip(String day, int count) {
    return '$day: $count';
  }

  @override
  String get byCategory => 'Nach Kategorie';

  @override
  String get language => 'Sprache';

  @override
  String get appearance => 'Darstellung';

  @override
  String get light => 'Hell';

  @override
  String get dark => 'Dunkel';

  @override
  String get system => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get themeHimmel => 'Himmel';

  @override
  String get themeOzean => 'Ozean';

  @override
  String get themeMint => 'Mint';

  @override
  String get themeWald => 'Wald';

  @override
  String get themeSonne => 'Sonne';

  @override
  String get themeAbendrot => 'Abendrot';

  @override
  String get themeBeere => 'Beere';

  @override
  String get themeLavendel => 'Lavendel';

  @override
  String get themeNord => 'Nord';

  @override
  String get themeGraphit => 'Graphit';

  @override
  String get colorSkyBlue => 'Himmelblau';

  @override
  String get colorMintGreen => 'Mintgrün';

  @override
  String get colorSunYellow => 'Sonnengelb';

  @override
  String get colorCoral => 'Koralle';

  @override
  String get colorLavender => 'Lavendel';

  @override
  String get reminders => 'Erinnerungen';

  @override
  String get grid => 'Raster (Minuten)';

  @override
  String get weekStartsOn => 'Woche beginnt am';

  @override
  String get dayStarts => 'Tag beginnt';

  @override
  String get dayEnds => 'Tag endet';

  @override
  String get storage => 'Speicherort';

  @override
  String get database => 'Datenbank';

  @override
  String get signOut => 'Abmelden';

  @override
  String get offline => 'Offline';

  @override
  String offlinePending(int count) {
    return 'Offline · $count warten';
  }

  @override
  String get synced => 'Synchronisiert';

  @override
  String get syncing => 'Synchronisiere …';

  @override
  String get allSynced => 'Alles synchronisiert';

  @override
  String get offlineToast => 'Offline – Änderungen werden am Gerät gespeichert';

  @override
  String get backOnline => 'Wieder online';

  @override
  String backOnlineSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wieder online – synchronisiere $count Änderungen …',
      one: 'Wieder online – synchronisiere 1 Änderung …',
    );
    return '$_temp0';
  }

  @override
  String get savedOnDevice => 'Am Gerät gespeichert';

  @override
  String get savedOnDeviceLater => 'Am Gerät gespeichert – wird später synchronisiert';

  @override
  String get noSyncOtherDevices => 'Kein Abgleich mit anderen Geräten';

  @override
  String get connectToDb => 'Mit Datenbank verbinden';

  @override
  String get connectToDbSub => 'Aufgaben auf Handy und PC abgleichen';

  @override
  String get notifChannelName => 'Erinnerungen';

  @override
  String get notifChannelDesc => 'Erinnert an Aufgaben mit Uhrzeit';

  @override
  String get yearly => 'Jährlich';

  @override
  String get yearlyHint => 'Wiederholt sich jedes Jahr';

  @override
  String get doneYearly => 'Erledigt – nächstes Jahr wieder';

  @override
  String holidayLine(String name) {
    return 'Feiertag: $name';
  }

  @override
  String get hNewYear => 'Neujahr';

  @override
  String get hEpiphany => 'Heilige Drei Könige';

  @override
  String get hEasterMonday => 'Ostermontag';

  @override
  String get hLabourDay => 'Staatsfeiertag';

  @override
  String get hAscension => 'Christi Himmelfahrt';

  @override
  String get hWhitMonday => 'Pfingstmontag';

  @override
  String get hCorpusChristi => 'Fronleichnam';

  @override
  String get hAssumption => 'Mariä Himmelfahrt';

  @override
  String get hNationalDay => 'Nationalfeiertag';

  @override
  String get hAllSaints => 'Allerheiligen';

  @override
  String get hImmaculate => 'Mariä Empfängnis';

  @override
  String get hChristmas => 'Christtag';

  @override
  String get hStStephen => 'Stefanitag';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get exportData => 'Daten exportieren';

  @override
  String get exportSub => 'Als PDF, Text oder Tabelle speichern';

  @override
  String get exportPdfSub => 'Zum Lesen und Drucken';

  @override
  String get exportTxtSub => 'Einfacher Text';

  @override
  String get exportCsvSub => 'Tabelle für Excel';

  @override
  String get exportSaved => 'Export gespeichert';

  @override
  String get exportFailed => 'Export fehlgeschlagen';

  @override
  String get colTitle => 'Titel';

  @override
  String get colCategory => 'Kategorie';

  @override
  String get colDue => 'Abgabe';

  @override
  String get colDaysDone => 'Tage erledigt';

  @override
  String get colLastDone => 'Zuletzt erledigt';

  @override
  String get colDay => 'Tag';

  @override
  String get colFrom => 'Von';

  @override
  String get colTo => 'Bis';

  @override
  String get colLeadDays => 'Vorlauf (Tage)';

  @override
  String exportStamp(String date) {
    return 'Stand: $date';
  }

  @override
  String exportWeekOf(String date) {
    return 'Nur Woche ab $date';
  }

  @override
  String get updates => 'Updates';

  @override
  String updateVersion(String version) {
    return 'Version $version';
  }

  @override
  String updateCurrent(String version) {
    return 'Version $version – aktuell';
  }

  @override
  String get updateChecking => 'Suche nach Updates …';

  @override
  String updateAvailable(String version) {
    return 'Version $version ist verfügbar';
  }

  @override
  String get updateInstall => 'Installieren';

  @override
  String updateDownloading(int percent) {
    return 'Lädt herunter … $percent %';
  }

  @override
  String get updateInstalling => 'Wird installiert – die App startet gleich neu';

  @override
  String get updateConfirm => 'Bitte im Fenster von Android auf „Aktualisieren“ tippen';

  @override
  String get updateFailed => 'Das hat nicht geklappt – hier klicken, um es noch einmal zu versuchen';

  @override
  String get langDe => 'Deutsch';

  @override
  String get langEn => 'English';

  @override
  String olderDoneLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ältere erledigte Aufgaben laden',
      one: '1 ältere erledigte Aufgabe laden',
    );
    return '$_temp0';
  }

  @override
  String olderDoneOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ältere erledigte Aufgaben sind nur online sichtbar',
      one: '1 ältere erledigte Aufgabe ist nur online sichtbar',
    );
    return '$_temp0';
  }

  @override
  String get olderDoneFailed => 'Ältere Aufgaben konnten nicht geladen werden';

  @override
  String exportOlderMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ohne $count ältere erledigte Aufgaben – die gibt es nur online',
      one: 'Ohne 1 ältere erledigte Aufgabe – die gibt es nur online',
    );
    return '$_temp0';
  }

  @override
  String flickHeader(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offen',
      one: '1 offen',
      zero: 'nichts offen',
    );
    return 'Heute, $date · $_temp0';
  }

  @override
  String flickTimed(String time, String title) {
    return '$time $title';
  }

  @override
  String flickOverdue(String title) {
    return '⚠ $title (überfällig)';
  }

  @override
  String get flickToday => 'Heutige Aufgaben für Flick';

  @override
  String get flickTodaySub => 'Zeigt sie im Windows-Launcher Flick, wenn man „Aufgaben“ eintippt';

  @override
  String get flickCopy => 'Flick-Shortcuts kopieren';

  @override
  String get flickCopySub => 'In Flick „flick config“ eintippen und am Ende einfügen';

  @override
  String get flickCopied => 'Flick-Shortcuts kopiert';

  @override
  String get flickAboutAdd => 'Neue Aufgabe im ToDo Planer';

  @override
  String get flickAboutToday => 'Heutige Aufgaben aus dem ToDo Planer';

  @override
  String get flickAboutTab => 'ToDo Planer in einem Tab öffnen';

  @override
  String get flickGuideTitle => 'Flick einrichten';

  @override
  String get flickGuideIntro => 'Die Shortcuts sind kopiert. So kommen sie in Flick:';

  @override
  String get flickStep1 => 'Flick öffnen';

  @override
  String get flickStep1Sub => 'Alt+Leertaste drücken.';

  @override
  String get flickStep2 => '„flick config“ eintippen';

  @override
  String get flickStep2Sub => 'Enter drücken – die Datei config.toml öffnet sich im Editor.';

  @override
  String get flickStep3 => 'Ans Ende einfügen';

  @override
  String get flickStep3Sub =>
      'Ganz nach unten gehen und Strg+V drücken. Waren die Shortcuts schon einmal drin, den alten Block vorher löschen – sonst gibt es sie doppelt.';

  @override
  String get flickStep4 => 'Speichern';

  @override
  String get flickStep4Sub => 'Strg+S drücken. Flick übernimmt die Shortcuts sofort.';

  @override
  String get flickGuideList => 'Liste „Aufgaben“';

  @override
  String get flickGuideTry => 'Das kannst du dann eintippen';

  @override
  String get flickCopyAgain => 'Nochmal kopieren';

  @override
  String get flickHeading => 'Flick';

  @override
  String get closeHint => 'Hinweis schließen';

  @override
  String blockMoved(String time) {
    return 'Block verschoben auf $time';
  }

  @override
  String get pickCategory => 'Kategorie';

  @override
  String get addTasksToDay => 'Weitere Aufgaben für diesen Tag';

  @override
  String get pickTasksTitle => 'Aufgaben für diesen Tag';

  @override
  String get pickTasksInfo => 'Alle offenen Aufgaben ab diesem Tag. Die gewählten stehen dann im Block zur Auswahl.';

  @override
  String get pickTasksNone => 'Keine offenen Aufgaben ab diesem Tag.';

  @override
  String applyCount(int count) {
    return '$count übernehmen';
  }
}
