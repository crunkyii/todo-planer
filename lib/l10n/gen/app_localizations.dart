import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de'), Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'Todo-Liste'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @undo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get undo;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @added.
  ///
  /// In de, this message translates to:
  /// **'Hinzugefügt'**
  String get added;

  /// No description provided for @saved.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert'**
  String get saved;

  /// No description provided for @back.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get back;

  /// No description provided for @all.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get all;

  /// No description provided for @name.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @color.
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get color;

  /// No description provided for @customColor.
  ///
  /// In de, this message translates to:
  /// **'Eigene Farbe'**
  String get customColor;

  /// No description provided for @chooseCustomColor.
  ///
  /// In de, this message translates to:
  /// **'Eigene Farbe wählen'**
  String get chooseCustomColor;

  /// No description provided for @apply.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get apply;

  /// No description provided for @hue.
  ///
  /// In de, this message translates to:
  /// **'Farbton'**
  String get hue;

  /// No description provided for @saturation.
  ///
  /// In de, this message translates to:
  /// **'Sättigung'**
  String get saturation;

  /// No description provided for @brightness.
  ///
  /// In de, this message translates to:
  /// **'Helligkeit'**
  String get brightness;

  /// No description provided for @none.
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get none;

  /// No description provided for @timeNone.
  ///
  /// In de, this message translates to:
  /// **'Ohne'**
  String get timeNone;

  /// No description provided for @done.
  ///
  /// In de, this message translates to:
  /// **'Erledigt'**
  String get done;

  /// No description provided for @reopened.
  ///
  /// In de, this message translates to:
  /// **'Wieder offen'**
  String get reopened;

  /// No description provided for @moreOptions.
  ///
  /// In de, this message translates to:
  /// **'Weitere Optionen'**
  String get moreOptions;

  /// No description provided for @mainNavigation.
  ///
  /// In de, this message translates to:
  /// **'Hauptnavigation'**
  String get mainNavigation;

  /// No description provided for @navTasks.
  ///
  /// In de, this message translates to:
  /// **'Aufgaben'**
  String get navTasks;

  /// No description provided for @navCalendar.
  ///
  /// In de, this message translates to:
  /// **'Kalender'**
  String get navCalendar;

  /// No description provided for @navWeek.
  ///
  /// In de, this message translates to:
  /// **'Woche'**
  String get navWeek;

  /// No description provided for @navStats.
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In de, this message translates to:
  /// **'Optionen'**
  String get navSettings;

  /// No description provided for @weeklyPlan.
  ///
  /// In de, this message translates to:
  /// **'Wochenplan'**
  String get weeklyPlan;

  /// No description provided for @statistics.
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get statistics;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @welcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen'**
  String get welcome;

  /// No description provided for @setupLead.
  ///
  /// In de, this message translates to:
  /// **'Wo sollen deine Aufgaben gespeichert werden?'**
  String get setupLead;

  /// No description provided for @setupCloudTitle.
  ///
  /// In de, this message translates to:
  /// **'Auf allen Geräten'**
  String get setupCloudTitle;

  /// No description provided for @setupCloudText.
  ///
  /// In de, this message translates to:
  /// **'Eigene kostenlose Supabase-Datenbank. Handy und PC bleiben gleich, auch offline nutzbar.'**
  String get setupCloudText;

  /// No description provided for @setupLocalTitle.
  ///
  /// In de, this message translates to:
  /// **'Nur auf diesem Gerät'**
  String get setupLocalTitle;

  /// No description provided for @setupLocalText.
  ///
  /// In de, this message translates to:
  /// **'Kein Konto, keine Einrichtung. Später in den Optionen umstellbar.'**
  String get setupLocalText;

  /// No description provided for @languageBoth.
  ///
  /// In de, this message translates to:
  /// **'Sprache · Language'**
  String get languageBoth;

  /// No description provided for @connectDb.
  ///
  /// In de, this message translates to:
  /// **'Datenbank verbinden'**
  String get connectDb;

  /// No description provided for @connectOtherDb.
  ///
  /// In de, this message translates to:
  /// **'Andere Datenbank verbinden'**
  String get connectOtherDb;

  /// No description provided for @openSupabase.
  ///
  /// In de, this message translates to:
  /// **'supabase.com öffnen'**
  String get openSupabase;

  /// No description provided for @copySql.
  ///
  /// In de, this message translates to:
  /// **'SQL kopieren'**
  String get copySql;

  /// No description provided for @sqlCopied.
  ///
  /// In de, this message translates to:
  /// **'SQL kopiert – jetzt im SQL Editor einfügen'**
  String get sqlCopied;

  /// No description provided for @connect.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get connect;

  /// No description provided for @connecting.
  ///
  /// In de, this message translates to:
  /// **'Verbinde …'**
  String get connecting;

  /// No description provided for @setupStep1.
  ///
  /// In de, this message translates to:
  /// **'Auf <b>supabase.com</b> kostenlos registrieren und ein <b>neues Projekt</b> anlegen.'**
  String get setupStep1;

  /// No description provided for @setupStep2.
  ///
  /// In de, this message translates to:
  /// **'Im Projekt <b>SQL Editor</b> öffnen, das SQL einfügen und auf <b>Run</b> tippen. Damit werden die Tabellen angelegt.'**
  String get setupStep2;

  /// No description provided for @setupStep3.
  ///
  /// In de, this message translates to:
  /// **'<b>Project URL</b>: oben im Projekt auf <b>Connect</b> tippen oder <b>Project Settings → Data API</b> öffnen. Sie sieht so aus: https://abcdefgh.supabase.co – der Teil vor „.supabase.co“ ist die <b>Project ID</b> (Project Settings → General). <b>Publishable Key</b>: unter <b>Project Settings → API Keys</b>, beginnt mit sb_publishable_. Beides kopieren und unten einfügen.'**
  String get setupStep3;

  /// No description provided for @setupStep4.
  ///
  /// In de, this message translates to:
  /// **'Nach deiner Registrierung: <b>Authentication → Sign In / Providers</b> → <b>„Allow new users to sign up“</b> ausschalten. Dann kann sich niemand sonst ein Konto in deiner Datenbank anlegen.'**
  String get setupStep4;

  /// No description provided for @secretNote.
  ///
  /// In de, this message translates to:
  /// **'Niemals den <b>Secret Key</b> (service_role) eingeben – der gehört nicht in eine App.'**
  String get secretNote;

  /// No description provided for @projectUrl.
  ///
  /// In de, this message translates to:
  /// **'Project URL'**
  String get projectUrl;

  /// No description provided for @publishableKey.
  ///
  /// In de, this message translates to:
  /// **'Publishable Key'**
  String get publishableKey;

  /// No description provided for @projectUrlHint.
  ///
  /// In de, this message translates to:
  /// **'https://abcdefgh.supabase.co'**
  String get projectUrlHint;

  /// No description provided for @publishableKeyHint.
  ///
  /// In de, this message translates to:
  /// **'sb_publishable_…'**
  String get publishableKeyHint;

  /// No description provided for @errUrl.
  ///
  /// In de, this message translates to:
  /// **'Die Project URL sieht so aus: https://abcdefgh.supabase.co'**
  String get errUrl;

  /// No description provided for @errKeyFormat.
  ///
  /// In de, this message translates to:
  /// **'Der Key beginnt mit „sb_publishable_“ (oder bei älteren Projekten mit „eyJ“).'**
  String get errKeyFormat;

  /// No description provided for @errSecretKey.
  ///
  /// In de, this message translates to:
  /// **'Das ist der geheime Schlüssel. Bitte den Publishable Key nehmen.'**
  String get errSecretKey;

  /// No description provided for @errNoConnection.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung. Stimmt die URL und wurde das SQL ausgeführt?'**
  String get errNoConnection;

  /// No description provided for @connectedTo.
  ///
  /// In de, this message translates to:
  /// **'Verbunden mit {host}'**
  String connectedTo(String host);

  /// No description provided for @signIn.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellen'**
  String get createAccount;

  /// No description provided for @haveAccount.
  ///
  /// In de, this message translates to:
  /// **'Ich habe schon ein Konto'**
  String get haveAccount;

  /// No description provided for @email.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get email;

  /// No description provided for @password.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort anzeigen'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort verbergen'**
  String get hidePassword;

  /// No description provided for @errEmail.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib eine gültige E-Mail-Adresse ein.'**
  String get errEmail;

  /// No description provided for @errPassword.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib dein Passwort ein.'**
  String get errPassword;

  /// No description provided for @errPasswordShort.
  ///
  /// In de, this message translates to:
  /// **'Das Passwort braucht mindestens 6 Zeichen.'**
  String get errPasswordShort;

  /// No description provided for @errPasswordLong.
  ///
  /// In de, this message translates to:
  /// **'Das Passwort ist zu lang (höchstens 72 Zeichen).'**
  String get errPasswordLong;

  /// No description provided for @errWrongLogin.
  ///
  /// In de, this message translates to:
  /// **'E-Mail oder Passwort ist falsch.'**
  String get errWrongLogin;

  /// No description provided for @accountCreatedHint.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellt. Jetzt in Supabase „Allow new users to sign up“ ausschalten.'**
  String get accountCreatedHint;

  /// No description provided for @confirmEmailHint.
  ///
  /// In de, this message translates to:
  /// **'Fast geschafft: Bitte bestätige deine E-Mail-Adresse über den Link in der Mail und melde dich dann an.'**
  String get confirmEmailHint;

  /// No description provided for @errNetwork.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung zum Server. Bitte prüfe deine Internetverbindung.'**
  String get errNetwork;

  /// No description provided for @errEmailNotConfirmed.
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätige zuerst deine E-Mail-Adresse (Link in der Bestätigungs-Mail).'**
  String get errEmailNotConfirmed;

  /// No description provided for @errAccountExists.
  ///
  /// In de, this message translates to:
  /// **'Für diese E-Mail-Adresse gibt es bereits ein Konto. Bitte melde dich an.'**
  String get errAccountExists;

  /// No description provided for @errWeakPassword.
  ///
  /// In de, this message translates to:
  /// **'Das Passwort ist zu schwach. Verwende mindestens 6 Zeichen.'**
  String get errWeakPassword;

  /// No description provided for @errRateLimit.
  ///
  /// In de, this message translates to:
  /// **'Zu viele Versuche. Bitte warte kurz und versuche es dann erneut.'**
  String get errRateLimit;

  /// No description provided for @errSignupDisabled.
  ///
  /// In de, this message translates to:
  /// **'Registrierung ist in dieser Datenbank ausgeschaltet.'**
  String get errSignupDisabled;

  /// No description provided for @errSessionExpired.
  ///
  /// In de, this message translates to:
  /// **'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.'**
  String get errSessionExpired;

  /// No description provided for @errAuthGeneric.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung fehlgeschlagen: {message}'**
  String errAuthGeneric(String message);

  /// No description provided for @errNoPermission.
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung für diese Aktion. Bitte melde dich erneut an.'**
  String get errNoPermission;

  /// No description provided for @errTableMissing.
  ///
  /// In de, this message translates to:
  /// **'In der Datenbank fehlen Tabellen. Bitte das SQL aus der Einrichtung noch einmal ausführen.'**
  String get errTableMissing;

  /// No description provided for @errDbGeneric.
  ///
  /// In de, this message translates to:
  /// **'Datenbankfehler: {message}'**
  String errDbGeneric(String message);

  /// No description provided for @errUnexpected.
  ///
  /// In de, this message translates to:
  /// **'Unerwarteter Fehler. Bitte versuche es erneut.'**
  String get errUnexpected;

  /// No description provided for @today.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In de, this message translates to:
  /// **'Morgen'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In de, this message translates to:
  /// **'Gestern'**
  String get yesterday;

  /// No description provided for @overdue.
  ///
  /// In de, this message translates to:
  /// **'Überfällig'**
  String get overdue;

  /// No description provided for @thisWeek.
  ///
  /// In de, this message translates to:
  /// **'Diese Woche'**
  String get thisWeek;

  /// No description provided for @later.
  ///
  /// In de, this message translates to:
  /// **'Später'**
  String get later;

  /// No description provided for @sectionCount.
  ///
  /// In de, this message translates to:
  /// **'{label} ({count})'**
  String sectionCount(String label, int count);

  /// No description provided for @newTask.
  ///
  /// In de, this message translates to:
  /// **'Neue Aufgabe'**
  String get newTask;

  /// No description provided for @editTask.
  ///
  /// In de, this message translates to:
  /// **'Aufgabe bearbeiten'**
  String get editTask;

  /// No description provided for @deleteTask.
  ///
  /// In de, this message translates to:
  /// **'Aufgabe löschen'**
  String get deleteTask;

  /// No description provided for @task.
  ///
  /// In de, this message translates to:
  /// **'Aufgabe'**
  String get task;

  /// No description provided for @errTaskTitle.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib ein, was zu tun ist.'**
  String get errTaskTitle;

  /// No description provided for @errPickDate.
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle ein Datum.'**
  String get errPickDate;

  /// No description provided for @nothingDue.
  ///
  /// In de, this message translates to:
  /// **'Nichts fällig.'**
  String get nothingDue;

  /// No description provided for @widgetUpcoming.
  ///
  /// In de, this message translates to:
  /// **'Demnächst'**
  String get widgetUpcoming;

  /// No description provided for @widgetNoHabits.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Gewohnheiten.'**
  String get widgetNoHabits;

  /// No description provided for @nothingFound.
  ///
  /// In de, this message translates to:
  /// **'Nichts gefunden.'**
  String get nothingFound;

  /// No description provided for @noTasks.
  ///
  /// In de, this message translates to:
  /// **'Keine Aufgaben.'**
  String get noTasks;

  /// No description provided for @searchTasks.
  ///
  /// In de, this message translates to:
  /// **'Aufgaben durchsuchen'**
  String get searchTasks;

  /// No description provided for @search.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get search;

  /// No description provided for @closeSearch.
  ///
  /// In de, this message translates to:
  /// **'Suche schließen'**
  String get closeSearch;

  /// No description provided for @sort.
  ///
  /// In de, this message translates to:
  /// **'Sortieren'**
  String get sort;

  /// No description provided for @sortByDate.
  ///
  /// In de, this message translates to:
  /// **'Nach Datum'**
  String get sortByDate;

  /// No description provided for @sortByCategory.
  ///
  /// In de, this message translates to:
  /// **'Nach Kategorie'**
  String get sortByCategory;

  /// No description provided for @sortByName.
  ///
  /// In de, this message translates to:
  /// **'Nach Name (A–Z)'**
  String get sortByName;

  /// No description provided for @filterByCategory.
  ///
  /// In de, this message translates to:
  /// **'Nach Kategorie filtern'**
  String get filterByCategory;

  /// No description provided for @showCompleted.
  ///
  /// In de, this message translates to:
  /// **'Erledigte anzeigen'**
  String get showCompleted;

  /// No description provided for @hideCompleted.
  ///
  /// In de, this message translates to:
  /// **'Erledigte ausblenden'**
  String get hideCompleted;

  /// No description provided for @completedHidden.
  ///
  /// In de, this message translates to:
  /// **'Erledigte ausgeblendet'**
  String get completedHidden;

  /// No description provided for @completedShown.
  ///
  /// In de, this message translates to:
  /// **'Erledigte werden angezeigt'**
  String get completedShown;

  /// No description provided for @deleteCompleted.
  ///
  /// In de, this message translates to:
  /// **'Erledigte löschen'**
  String get deleteCompleted;

  /// No description provided for @noCompleted.
  ///
  /// In de, this message translates to:
  /// **'Keine erledigten Aufgaben'**
  String get noCompleted;

  /// No description provided for @completedDeleted.
  ///
  /// In de, this message translates to:
  /// **'{count} erledigte gelöscht'**
  String completedDeleted(int count);

  /// No description provided for @completedTasks.
  ///
  /// In de, this message translates to:
  /// **'Erledigte Aufgaben'**
  String get completedTasks;

  /// No description provided for @subtask.
  ///
  /// In de, this message translates to:
  /// **'Unteraufgabe'**
  String get subtask;

  /// No description provided for @subtasks.
  ///
  /// In de, this message translates to:
  /// **'Unteraufgaben'**
  String get subtasks;

  /// No description provided for @removeSubtask.
  ///
  /// In de, this message translates to:
  /// **'Unteraufgabe entfernen'**
  String get removeSubtask;

  /// No description provided for @dueOn.
  ///
  /// In de, this message translates to:
  /// **'Fällig am'**
  String get dueOn;

  /// No description provided for @dateAndTime.
  ///
  /// In de, this message translates to:
  /// **'Datum und Uhrzeit'**
  String get dateAndTime;

  /// No description provided for @time.
  ///
  /// In de, this message translates to:
  /// **'Uhrzeit'**
  String get time;

  /// No description provided for @hour.
  ///
  /// In de, this message translates to:
  /// **'Stunde'**
  String get hour;

  /// No description provided for @minute.
  ///
  /// In de, this message translates to:
  /// **'Minute'**
  String get minute;

  /// No description provided for @quickDate.
  ///
  /// In de, this message translates to:
  /// **'Schnellauswahl Datum'**
  String get quickDate;

  /// No description provided for @quickTime.
  ///
  /// In de, this message translates to:
  /// **'Schnellauswahl Uhrzeit'**
  String get quickTime;

  /// No description provided for @inOneWeek.
  ///
  /// In de, this message translates to:
  /// **'In 1 Woche'**
  String get inOneWeek;

  /// No description provided for @prevMonth.
  ///
  /// In de, this message translates to:
  /// **'Voriger Monat'**
  String get prevMonth;

  /// No description provided for @nextMonth.
  ///
  /// In de, this message translates to:
  /// **'Nächster Monat'**
  String get nextMonth;

  /// No description provided for @a11yDone.
  ///
  /// In de, this message translates to:
  /// **'Erledigt: {title}'**
  String a11yDone(String title);

  /// No description provided for @a11yReopen.
  ///
  /// In de, this message translates to:
  /// **'Wieder öffnen: {title}'**
  String a11yReopen(String title);

  /// No description provided for @a11yCheckSub.
  ///
  /// In de, this message translates to:
  /// **'Unteraufgabe abhaken: {title}'**
  String a11yCheckSub(String title);

  /// No description provided for @a11yReopenSub.
  ///
  /// In de, this message translates to:
  /// **'Unteraufgabe wieder öffnen: {title}'**
  String a11yReopenSub(String title);

  /// No description provided for @categoryLabel.
  ///
  /// In de, this message translates to:
  /// **'Kategorie: {name}'**
  String categoryLabel(String name);

  /// No description provided for @deletedItem.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ gelöscht'**
  String deletedItem(String name);

  /// No description provided for @deletedCatMoved.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ gelöscht, Aufgaben → {target}'**
  String deletedCatMoved(String name, String target);

  /// No description provided for @infoDue.
  ///
  /// In de, this message translates to:
  /// **'Fällig {day}'**
  String infoDue(String day);

  /// No description provided for @infoHandIn.
  ///
  /// In de, this message translates to:
  /// **'Abgabe {day}'**
  String infoHandIn(String day);

  /// No description provided for @infoListFrom.
  ///
  /// In de, this message translates to:
  /// **'{info} · in der Liste ab {day}'**
  String infoListFrom(String info, String day);

  /// No description provided for @dayWithTime.
  ///
  /// In de, this message translates to:
  /// **'{day}, {time}'**
  String dayWithTime(String day, String time);

  /// No description provided for @weekdayWithDate.
  ///
  /// In de, this message translates to:
  /// **'{weekday}, {date}'**
  String weekdayWithDate(String weekday, String date);

  /// No description provided for @weekdayShortWithDate.
  ///
  /// In de, this message translates to:
  /// **'{weekday} {date}'**
  String weekdayShortWithDate(String weekday, String date);

  /// No description provided for @progress.
  ///
  /// In de, this message translates to:
  /// **'{done}/{total}'**
  String progress(int done, int total);

  /// No description provided for @pendingSyncHint.
  ///
  /// In de, this message translates to:
  /// **'Wird synchronisiert, sobald du online bist'**
  String get pendingSyncHint;

  /// No description provided for @habits.
  ///
  /// In de, this message translates to:
  /// **'Gewohnheiten'**
  String get habits;

  /// No description provided for @habit.
  ///
  /// In de, this message translates to:
  /// **'Gewohnheit'**
  String get habit;

  /// No description provided for @newHabit.
  ///
  /// In de, this message translates to:
  /// **'Neue Gewohnheit'**
  String get newHabit;

  /// No description provided for @editHabit.
  ///
  /// In de, this message translates to:
  /// **'Gewohnheit bearbeiten'**
  String get editHabit;

  /// No description provided for @daily.
  ///
  /// In de, this message translates to:
  /// **'Täglich'**
  String get daily;

  /// No description provided for @habitsCheckAll.
  ///
  /// In de, this message translates to:
  /// **'Alle Gewohnheiten für heute abhaken'**
  String get habitsCheckAll;

  /// No description provided for @habitsReopenAll.
  ///
  /// In de, this message translates to:
  /// **'Alle Gewohnheiten wieder öffnen'**
  String get habitsReopenAll;

  /// No description provided for @habitHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Wasser trinken'**
  String get habitHint;

  /// No description provided for @a11yHabitDoneToday.
  ///
  /// In de, this message translates to:
  /// **'{name} heute erledigt'**
  String a11yHabitDoneToday(String name);

  /// No description provided for @a11yHabitReopen.
  ///
  /// In de, this message translates to:
  /// **'{name} wieder öffnen'**
  String a11yHabitReopen(String name);

  /// No description provided for @a11yHabitDay.
  ///
  /// In de, this message translates to:
  /// **'{name}, {date}'**
  String a11yHabitDay(String name, String date);

  /// No description provided for @noHabits.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Gewohnheiten – tippe auf +.'**
  String get noHabits;

  /// No description provided for @streakDays.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Tag} other{{count} Tage}}'**
  String streakDays(int count);

  /// No description provided for @categories.
  ///
  /// In de, this message translates to:
  /// **'Kategorien'**
  String get categories;

  /// No description provided for @manageCategories.
  ///
  /// In de, this message translates to:
  /// **'Kategorien verwalten'**
  String get manageCategories;

  /// No description provided for @newCategory.
  ///
  /// In de, this message translates to:
  /// **'Neue Kategorie'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In de, this message translates to:
  /// **'Kategorie bearbeiten'**
  String get editCategory;

  /// No description provided for @errCategoryExists.
  ///
  /// In de, this message translates to:
  /// **'Diese Kategorie gibt es schon.'**
  String get errCategoryExists;

  /// No description provided for @errName.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Namen ein.'**
  String get errName;

  /// No description provided for @categoryHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Referat'**
  String get categoryHint;

  /// No description provided for @catHomework.
  ///
  /// In de, this message translates to:
  /// **'Hausübung'**
  String get catHomework;

  /// No description provided for @catTask.
  ///
  /// In de, this message translates to:
  /// **'Aufgabe'**
  String get catTask;

  /// No description provided for @catTest.
  ///
  /// In de, this message translates to:
  /// **'Test'**
  String get catTest;

  /// No description provided for @catAppointment.
  ///
  /// In de, this message translates to:
  /// **'Termin'**
  String get catAppointment;

  /// No description provided for @doWhen.
  ///
  /// In de, this message translates to:
  /// **'Erledigen'**
  String get doWhen;

  /// No description provided for @offsetSameDay.
  ///
  /// In de, this message translates to:
  /// **'Selber Tag'**
  String get offsetSameDay;

  /// No description provided for @offsetDaysBefore.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Tag vorher} other{{count} Tage vorher}}'**
  String offsetDaysBefore(int count);

  /// No description provided for @offsetWeekBefore.
  ///
  /// In de, this message translates to:
  /// **'1 Woche vorher'**
  String get offsetWeekBefore;

  /// No description provided for @catDoSameDay.
  ///
  /// In de, this message translates to:
  /// **'Am selben Tag erledigen · {open} offen'**
  String catDoSameDay(int open);

  /// No description provided for @catDoDaysBefore.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Tag vorher erledigen · {open} offen} other{{count} Tage vorher erledigen · {open} offen}}'**
  String catDoDaysBefore(int count, int open);

  /// No description provided for @catDoWeekBefore.
  ///
  /// In de, this message translates to:
  /// **'1 Woche vorher erledigen · {open} offen'**
  String catDoWeekBefore(int open);

  /// No description provided for @categoriesCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Kategorie} other{{count} Kategorien}}'**
  String categoriesCount(int count);

  /// No description provided for @newBlock.
  ///
  /// In de, this message translates to:
  /// **'Neuer Block'**
  String get newBlock;

  /// No description provided for @editBlock.
  ///
  /// In de, this message translates to:
  /// **'Block bearbeiten'**
  String get editBlock;

  /// No description provided for @blockAdded.
  ///
  /// In de, this message translates to:
  /// **'Block angelegt'**
  String get blockAdded;

  /// No description provided for @blocksAdded.
  ///
  /// In de, this message translates to:
  /// **'{count} Blöcke angelegt'**
  String blocksAdded(int count);

  /// No description provided for @blockDeleted.
  ///
  /// In de, this message translates to:
  /// **'Block gelöscht'**
  String get blockDeleted;

  /// No description provided for @from.
  ///
  /// In de, this message translates to:
  /// **'Von'**
  String get from;

  /// No description provided for @to.
  ///
  /// In de, this message translates to:
  /// **'Bis'**
  String get to;

  /// No description provided for @timeWithDuration.
  ///
  /// In de, this message translates to:
  /// **'Zeit · {duration}'**
  String timeWithDuration(String duration);

  /// No description provided for @day.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get day;

  /// No description provided for @days.
  ///
  /// In de, this message translates to:
  /// **'Tage'**
  String get days;

  /// No description provided for @everyWeek.
  ///
  /// In de, this message translates to:
  /// **'Jede Woche'**
  String get everyWeek;

  /// No description provided for @repeatEveryWeek.
  ///
  /// In de, this message translates to:
  /// **'Jede Woche wiederholen'**
  String get repeatEveryWeek;

  /// No description provided for @errToAfterFrom.
  ///
  /// In de, this message translates to:
  /// **'„Bis“ muss nach „Von“ liegen.'**
  String get errToAfterFrom;

  /// No description provided for @durInvalid.
  ///
  /// In de, this message translates to:
  /// **'„Bis“ muss nach „Von“ liegen'**
  String get durInvalid;

  /// No description provided for @errPickDay.
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens einen Tag.'**
  String get errPickDay;

  /// No description provided for @blockHint.
  ///
  /// In de, this message translates to:
  /// **'Schule, Training …'**
  String get blockHint;

  /// No description provided for @prevWeek.
  ///
  /// In de, this message translates to:
  /// **'Vorige Woche'**
  String get prevWeek;

  /// No description provided for @nextWeek.
  ///
  /// In de, this message translates to:
  /// **'Nächste Woche'**
  String get nextWeek;

  /// No description provided for @prevDay.
  ///
  /// In de, this message translates to:
  /// **'Voriger Tag'**
  String get prevDay;

  /// No description provided for @nextDay.
  ///
  /// In de, this message translates to:
  /// **'Nächster Tag'**
  String get nextDay;

  /// No description provided for @backToWeek.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Woche'**
  String get backToWeek;

  /// No description provided for @showDay.
  ///
  /// In de, this message translates to:
  /// **'{day} anzeigen'**
  String showDay(String day);

  /// No description provided for @weekNumber.
  ///
  /// In de, this message translates to:
  /// **'KW {number}'**
  String weekNumber(int number);

  /// No description provided for @dayAndWeek.
  ///
  /// In de, this message translates to:
  /// **'{day} · {week}'**
  String dayAndWeek(String day, String week);

  /// No description provided for @rangeDash.
  ///
  /// In de, this message translates to:
  /// **'{from} – {to}'**
  String rangeDash(String from, String to);

  /// No description provided for @a11yBlock.
  ///
  /// In de, this message translates to:
  /// **'{name}, {day} {from} bis {to}'**
  String a11yBlock(String name, String day, String from, String to);

  /// No description provided for @durHoursMin.
  ///
  /// In de, this message translates to:
  /// **'{hours} Std. {minutes} Min.'**
  String durHoursMin(int hours, int minutes);

  /// No description provided for @durHours.
  ///
  /// In de, this message translates to:
  /// **'{hours} Std.'**
  String durHours(int hours);

  /// No description provided for @durMin.
  ///
  /// In de, this message translates to:
  /// **'{minutes} Min.'**
  String durMin(int minutes);

  /// No description provided for @quickPlus30.
  ///
  /// In de, this message translates to:
  /// **'+30 Min.'**
  String get quickPlus30;

  /// No description provided for @quickPlus60.
  ///
  /// In de, this message translates to:
  /// **'+1 Std.'**
  String get quickPlus60;

  /// No description provided for @quickPlus90.
  ///
  /// In de, this message translates to:
  /// **'+1½ Std.'**
  String get quickPlus90;

  /// No description provided for @quickPlus120.
  ///
  /// In de, this message translates to:
  /// **'+2 Std.'**
  String get quickPlus120;

  /// No description provided for @activity.
  ///
  /// In de, this message translates to:
  /// **'Aktivität'**
  String get activity;

  /// No description provided for @period.
  ///
  /// In de, this message translates to:
  /// **'Zeitraum'**
  String get period;

  /// No description provided for @less.
  ///
  /// In de, this message translates to:
  /// **'weniger'**
  String get less;

  /// No description provided for @more.
  ///
  /// In de, this message translates to:
  /// **'mehr'**
  String get more;

  /// No description provided for @perDay.
  ///
  /// In de, this message translates to:
  /// **'pro Tag'**
  String get perDay;

  /// No description provided for @tileDone.
  ///
  /// In de, this message translates to:
  /// **'erledigt'**
  String get tileDone;

  /// No description provided for @tileStreak.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Tag Serie} other{Tage Serie}}'**
  String tileStreak(int count);

  /// No description provided for @daysRange.
  ///
  /// In de, this message translates to:
  /// **'{count} Tage'**
  String daysRange(int count);

  /// No description provided for @heatSummary.
  ///
  /// In de, this message translates to:
  /// **'<b>{total}</b> erledigt an <b>{days}</b> Tagen'**
  String heatSummary(int total, int days);

  /// No description provided for @heatDay.
  ///
  /// In de, this message translates to:
  /// **'{date}: <b>{count}</b> erledigt'**
  String heatDay(String date, int count);

  /// No description provided for @a11yHeatDay.
  ///
  /// In de, this message translates to:
  /// **'{date}: {count} erledigt'**
  String a11yHeatDay(String date, int count);

  /// No description provided for @chartA11y.
  ///
  /// In de, this message translates to:
  /// **'{count} erledigte Aufgaben in {days} Tagen'**
  String chartA11y(int count, int days);

  /// No description provided for @barTooltip.
  ///
  /// In de, this message translates to:
  /// **'{day}: {count}'**
  String barTooltip(String day, int count);

  /// No description provided for @byCategory.
  ///
  /// In de, this message translates to:
  /// **'Nach Kategorie'**
  String get byCategory;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get appearance;

  /// No description provided for @light.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @theme.
  ///
  /// In de, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeHimmel.
  ///
  /// In de, this message translates to:
  /// **'Himmel'**
  String get themeHimmel;

  /// No description provided for @themeOzean.
  ///
  /// In de, this message translates to:
  /// **'Ozean'**
  String get themeOzean;

  /// No description provided for @themeMint.
  ///
  /// In de, this message translates to:
  /// **'Mint'**
  String get themeMint;

  /// No description provided for @themeWald.
  ///
  /// In de, this message translates to:
  /// **'Wald'**
  String get themeWald;

  /// No description provided for @themeSonne.
  ///
  /// In de, this message translates to:
  /// **'Sonne'**
  String get themeSonne;

  /// No description provided for @themeAbendrot.
  ///
  /// In de, this message translates to:
  /// **'Abendrot'**
  String get themeAbendrot;

  /// No description provided for @themeBeere.
  ///
  /// In de, this message translates to:
  /// **'Beere'**
  String get themeBeere;

  /// No description provided for @themeLavendel.
  ///
  /// In de, this message translates to:
  /// **'Lavendel'**
  String get themeLavendel;

  /// No description provided for @themeNord.
  ///
  /// In de, this message translates to:
  /// **'Nord'**
  String get themeNord;

  /// No description provided for @themeGraphit.
  ///
  /// In de, this message translates to:
  /// **'Graphit'**
  String get themeGraphit;

  /// No description provided for @colorSkyBlue.
  ///
  /// In de, this message translates to:
  /// **'Himmelblau'**
  String get colorSkyBlue;

  /// No description provided for @colorMintGreen.
  ///
  /// In de, this message translates to:
  /// **'Mintgrün'**
  String get colorMintGreen;

  /// No description provided for @colorSunYellow.
  ///
  /// In de, this message translates to:
  /// **'Sonnengelb'**
  String get colorSunYellow;

  /// No description provided for @colorCoral.
  ///
  /// In de, this message translates to:
  /// **'Koralle'**
  String get colorCoral;

  /// No description provided for @colorLavender.
  ///
  /// In de, this message translates to:
  /// **'Lavendel'**
  String get colorLavender;

  /// No description provided for @reminders.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen'**
  String get reminders;

  /// No description provided for @grid.
  ///
  /// In de, this message translates to:
  /// **'Raster (Minuten)'**
  String get grid;

  /// No description provided for @dayStarts.
  ///
  /// In de, this message translates to:
  /// **'Tag beginnt'**
  String get dayStarts;

  /// No description provided for @dayEnds.
  ///
  /// In de, this message translates to:
  /// **'Tag endet'**
  String get dayEnds;

  /// No description provided for @storage.
  ///
  /// In de, this message translates to:
  /// **'Speicherort'**
  String get storage;

  /// No description provided for @database.
  ///
  /// In de, this message translates to:
  /// **'Datenbank'**
  String get database;

  /// No description provided for @signOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get signOut;

  /// No description provided for @offline.
  ///
  /// In de, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @offlinePending.
  ///
  /// In de, this message translates to:
  /// **'Offline · {count} warten'**
  String offlinePending(int count);

  /// No description provided for @synced.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiert'**
  String get synced;

  /// No description provided for @syncing.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiere …'**
  String get syncing;

  /// No description provided for @allSynced.
  ///
  /// In de, this message translates to:
  /// **'Alles synchronisiert'**
  String get allSynced;

  /// No description provided for @offlineToast.
  ///
  /// In de, this message translates to:
  /// **'Offline – Änderungen werden am Gerät gespeichert'**
  String get offlineToast;

  /// No description provided for @backOnline.
  ///
  /// In de, this message translates to:
  /// **'Wieder online'**
  String get backOnline;

  /// No description provided for @backOnlineSyncing.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Wieder online – synchronisiere 1 Änderung …} other{Wieder online – synchronisiere {count} Änderungen …}}'**
  String backOnlineSyncing(int count);

  /// No description provided for @savedOnDevice.
  ///
  /// In de, this message translates to:
  /// **'Am Gerät gespeichert'**
  String get savedOnDevice;

  /// No description provided for @savedOnDeviceLater.
  ///
  /// In de, this message translates to:
  /// **'Am Gerät gespeichert – wird später synchronisiert'**
  String get savedOnDeviceLater;

  /// No description provided for @noSyncOtherDevices.
  ///
  /// In de, this message translates to:
  /// **'Kein Abgleich mit anderen Geräten'**
  String get noSyncOtherDevices;

  /// No description provided for @connectToDb.
  ///
  /// In de, this message translates to:
  /// **'Mit Datenbank verbinden'**
  String get connectToDb;

  /// No description provided for @connectToDbSub.
  ///
  /// In de, this message translates to:
  /// **'Aufgaben auf Handy und PC abgleichen'**
  String get connectToDbSub;

  /// No description provided for @notifChannelName.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In de, this message translates to:
  /// **'Erinnert an Aufgaben mit Uhrzeit'**
  String get notifChannelDesc;

  /// No description provided for @notifOpen.
  ///
  /// In de, this message translates to:
  /// **'Öffnen'**
  String get notifOpen;

  /// No description provided for @langDe.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get langDe;

  /// No description provided for @langEn.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get langEn;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
