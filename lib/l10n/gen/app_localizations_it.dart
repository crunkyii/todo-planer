// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'ToDo Planer';

  @override
  String get cancel => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get delete => 'Elimina';

  @override
  String get undo => 'Annulla';

  @override
  String get add => 'Aggiungi';

  @override
  String get added => 'Aggiunto';

  @override
  String get saved => 'Salvato';

  @override
  String get itemGone => 'Questo elemento nel frattempo è stato eliminato.';

  @override
  String get back => 'Indietro';

  @override
  String get all => 'Tutte';

  @override
  String get name => 'Nome';

  @override
  String get color => 'Colore';

  @override
  String get customColor => 'Colore personalizzato';

  @override
  String get chooseCustomColor => 'Scegli colore personalizzato';

  @override
  String get apply => 'Applica';

  @override
  String get hue => 'Tonalità';

  @override
  String get saturation => 'Saturazione';

  @override
  String get brightness => 'Luminosità';

  @override
  String get none => 'Nessuno';

  @override
  String get timeNone => 'Nessuna';

  @override
  String get done => 'Fatto';

  @override
  String get reopened => 'Riaperto';

  @override
  String get moreOptions => 'Altre opzioni';

  @override
  String get mainNavigation => 'Navigazione principale';

  @override
  String get navTasks => 'Attività';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navWeek => 'Settimana';

  @override
  String get navStats => 'Statistiche';

  @override
  String get navSettings => 'Opzioni';

  @override
  String get weeklyPlan => 'Piano settimanale';

  @override
  String get statistics => 'Statistiche';

  @override
  String get settings => 'Impostazioni';

  @override
  String get welcome => 'Benvenuto';

  @override
  String get setupLead => 'Dove vuoi salvare le tue attività?';

  @override
  String get setupCloudText =>
      'Il tuo database Supabase gratuito. Telefono e PC restano sincronizzati, funziona anche offline.';

  @override
  String get setupLocalTitle => 'Solo su questo dispositivo';

  @override
  String get setupLocalText =>
      'Nessun account, nessuna configurazione. Puoi cambiare tutto più tardi nelle impostazioni.';

  @override
  String get languageBoth => 'Lingua · Language';

  @override
  String get connectDb => 'Collega database';

  @override
  String get connectOtherDb => 'Collega un altro database';

  @override
  String get openSupabase => 'Apri supabase.com';

  @override
  String get connectExistingLead =>
      'Il tuo account si trova nel tuo database. Prima che questo dispositivo possa farti accedere, servono il <b>Project URL</b> e la <b>Publishable Key</b> del database – gli stessi del tuo primo dispositivo. Trovi entrambi nel tuo progetto Supabase.';

  @override
  String get copySql => 'Copia SQL';

  @override
  String get sqlCopied => 'SQL copiato – ora incollalo nell\'SQL Editor';

  @override
  String get connect => 'Collega';

  @override
  String get connecting => 'Connessione …';

  @override
  String get setupStep1 => 'Registrati gratis su <b>supabase.com</b> e crea un <b>nuovo progetto</b>.';

  @override
  String get setupStep2 =>
      'Nel progetto apri l\'<b>SQL Editor</b>, incolla l\'SQL e tocca <b>Run</b>. Così vengono create le tabelle.';

  @override
  String get setupStep3 =>
      '<b>Project URL</b>: tocca <b>Connect</b> in alto nel progetto oppure apri <b>Project Settings → Data API</b>. Ha questo aspetto: https://abcdefgh.supabase.co – la parte prima di \".supabase.co\" è il <b>Project ID</b> (Project Settings → General). <b>Publishable Key</b>: in <b>Project Settings → API Keys</b>, inizia con sb_publishable_. Copia entrambi e incollali qui sotto.';

  @override
  String get setupStep4 =>
      'Dopo la registrazione: disattiva <b>Authentication → Sign In / Providers</b> → <b>\"Allow new users to sign up\"</b>. Così nessun altro può creare un account nel tuo database.';

  @override
  String get secretNote => 'Non inserire mai la <b>Secret Key</b> (service_role) – non va usata in un\'app.';

  @override
  String get projectUrl => 'Project URL';

  @override
  String get publishableKey => 'Publishable Key';

  @override
  String get projectUrlHint => 'https://abcdefgh.supabase.co';

  @override
  String get publishableKeyHint => 'sb_publishable_…';

  @override
  String get errUrl => 'Il Project URL ha questo aspetto: https://abcdefgh.supabase.co';

  @override
  String get errKeyFormat => 'La chiave inizia con \"sb_publishable_\" (o \"eyJ\" per i progetti più vecchi).';

  @override
  String get errSecretKey => 'Questa è la chiave segreta. Usa la Publishable Key.';

  @override
  String get errNoConnection => 'Nessuna connessione. L\'URL è corretto e l\'SQL è stato eseguito?';

  @override
  String connectedTo(String host) {
    return 'Collegato a $host';
  }

  @override
  String get signIn => 'Accedi';

  @override
  String get signUp => 'Registrati';

  @override
  String get createAccount => 'Crea account';

  @override
  String get haveAccount => 'Ho già un account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Mostra password';

  @override
  String get hidePassword => 'Nascondi password';

  @override
  String get errEmail => 'Inserisci un indirizzo email valido.';

  @override
  String get errPassword => 'Inserisci la tua password.';

  @override
  String get errPasswordShort => 'La password deve avere almeno 6 caratteri.';

  @override
  String get errPasswordLong => 'La password è troppo lunga (massimo 72 caratteri).';

  @override
  String get errWrongLogin => 'Email o password errata.';

  @override
  String get accountCreatedHint => 'Account creato. Ora disattiva \"Allow new users to sign up\" in Supabase.';

  @override
  String get confirmEmailHint => 'Quasi fatto: conferma il tuo indirizzo email con il link nella mail, poi accedi.';

  @override
  String get errNetwork => 'Nessuna connessione al server. Controlla la tua connessione a internet.';

  @override
  String get errEmailNotConfirmed => 'Conferma prima il tuo indirizzo email (link nella mail di conferma).';

  @override
  String get errAccountExists => 'Esiste già un account con questo indirizzo email. Accedi.';

  @override
  String get errWeakPassword => 'La password è troppo debole. Usa almeno 6 caratteri.';

  @override
  String get errRateLimit => 'Troppi tentativi. Attendi un attimo e riprova.';

  @override
  String get errSignupDisabled => 'La registrazione è disattivata in questo database.';

  @override
  String get errSessionExpired => 'La sessione è scaduta. Accedi di nuovo.';

  @override
  String errAuthGeneric(String message) {
    return 'Accesso non riuscito: $message';
  }

  @override
  String get errNoPermission => 'Nessuna autorizzazione per questa azione. Accedi di nuovo.';

  @override
  String get errTableMissing => 'Mancano le tabelle nel database. Esegui di nuovo l\'SQL della configurazione.';

  @override
  String errDbGeneric(String message) {
    return 'Errore del database: $message';
  }

  @override
  String get errUnexpected => 'Errore imprevisto. Riprova.';

  @override
  String get today => 'Oggi';

  @override
  String get tomorrow => 'Domani';

  @override
  String get yesterday => 'Ieri';

  @override
  String get overdue => 'In ritardo';

  @override
  String get thisWeek => 'Questa settimana';

  @override
  String get later => 'Più avanti';

  @override
  String sectionCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get newTask => 'Nuova attività';

  @override
  String get editTask => 'Modifica attività';

  @override
  String get deleteTask => 'Elimina attività';

  @override
  String get task => 'Attività';

  @override
  String get errTaskTitle => 'Inserisci cosa c\'è da fare.';

  @override
  String get nothingDue => 'Niente in scadenza.';

  @override
  String get widgetUpcoming => 'In arrivo';

  @override
  String widgetUntil(String when) {
    return 'entro: $when';
  }

  @override
  String get widgetNoHabits => 'Ancora nessuna abitudine.';

  @override
  String get widgetSettings => 'Impostazioni widget';

  @override
  String get widgetContent => 'Contenuto';

  @override
  String get widgetContentHint => 'Cosa mostra il widget';

  @override
  String get widgetRange => 'Periodo';

  @override
  String get widgetRangeHint => 'Quanto avanti';

  @override
  String get widgetRange3d => '3 giorni';

  @override
  String get widgetRange1w => '1 settimana';

  @override
  String get widgetRange2w => '2 settimane';

  @override
  String get widgetRange1m => '1 mese';

  @override
  String get widgetRangeAll => 'Tutto';

  @override
  String get widgetRangeNote =>
      'Le attività in ritardo sono sempre incluse, qualunque sia il periodo. Il numero in alto conta solo ciò che il widget mostra.';

  @override
  String widgetUntilDate(String date) {
    return 'fino a $date';
  }

  @override
  String get widgetBackground => 'Sfondo';

  @override
  String get widgetShowBackground => 'Mostra sfondo';

  @override
  String get widgetShape => 'Forma';

  @override
  String get widgetShapeRound => 'Rotonda';

  @override
  String get widgetShapeSoft => 'Morbida';

  @override
  String get widgetShapeSquare => 'Quadrata';

  @override
  String get widgetBgColor => 'Colore dello sfondo';

  @override
  String widgetTransparency(int percent) {
    return 'Trasparenza: $percent%';
  }

  @override
  String get widgetColorApp => 'Come il tema dell\'app';

  @override
  String get widgetPreview => 'Anteprima';

  @override
  String get widgetHint =>
      'Tieni premuto il widget nella schermata iniziale e tocca “Impostazioni” per modificarlo più tardi.';

  @override
  String get nothingFound => 'Nessun risultato.';

  @override
  String get noTasks => 'Nessuna attività.';

  @override
  String get searchTasks => 'Cerca attività';

  @override
  String get search => 'Cerca';

  @override
  String get closeSearch => 'Chiudi ricerca';

  @override
  String get columns => 'Colonne';

  @override
  String get columnsVisible => 'Visibili affiancate';

  @override
  String get columnsPeriods => 'Periodi';

  @override
  String get columnsOwn => 'Colonne personali';

  @override
  String get addColumn => 'Aggiungi colonna';

  @override
  String get newColumn => 'Nuova colonna';

  @override
  String get editColumn => 'Modifica colonna';

  @override
  String get columnHint => 'es. Scuola';

  @override
  String get columnStatus => 'Stato';

  @override
  String get columnOnlyOpen => 'Solo aperte';

  @override
  String get columnOnlyDone => 'Solo completate';

  @override
  String get columnText => 'Il testo contiene';

  @override
  String get columnTextHint => 'es. Matematica';

  @override
  String get columnFilterNote =>
      'Tutti i filtri sono facoltativi. Le attività restano anche nelle loro colonne abituali.';

  @override
  String editNamed(String name) {
    return 'Modifica “$name”';
  }

  @override
  String get columnsCategories => 'Categorie come colonna a sé';

  @override
  String get close => 'Chiudi';

  @override
  String get columnsAllHidden => 'Tutte le colonne sono nascoste. Riattivale in ⋮ → Colonne.';

  @override
  String get columnsDragHint =>
      'Cambia l\'ordine: tieni premuta l\'intestazione di una colonna e trascinala dove vuoi.';

  @override
  String get moveLeft => 'Sposta a sinistra';

  @override
  String get moveRight => 'Sposta a destra';

  @override
  String get columnsNarrowHint => 'Una finestra stretta affianca meno colonne di quelle impostate qui.';

  @override
  String get columnsDragHintTouch => 'Cambia l\'ordine: tieni premuta un\'intestazione e trascinala dove vuoi.';

  @override
  String get moveUp => 'Sposta su';

  @override
  String get moveDown => 'Sposta giù';

  @override
  String get sort => 'Ordina';

  @override
  String get sortByDate => 'Per data';

  @override
  String get sortByCategory => 'Per categoria';

  @override
  String get sortByName => 'Per nome (A–Z)';

  @override
  String get filterByCategory => 'Filtra per categoria';

  @override
  String get showCompleted => 'Mostra completate';

  @override
  String get hideCompleted => 'Nascondi completate';

  @override
  String get completedHidden => 'Completate nascoste';

  @override
  String get completedShown => 'Completate visibili';

  @override
  String get deleteCompleted => 'Elimina completate';

  @override
  String get noCompleted => 'Nessuna attività completata';

  @override
  String completedDeleted(int count) {
    return 'Completate eliminate: $count';
  }

  @override
  String get completedTasks => 'Attività completate';

  @override
  String get subtask => 'Sottoattività';

  @override
  String get subtasks => 'Sottoattività';

  @override
  String get removeSubtask => 'Rimuovi sottoattività';

  @override
  String get notes => 'Nota';

  @override
  String get notesHint => 'Altro su questa attività …';

  @override
  String get schemaOutdated => 'Il database è più vecchio dell\'app: esegui di nuovo schema.sql in Supabase.';

  @override
  String get dueOn => 'Scade il';

  @override
  String get dateAndTime => 'Data e ora';

  @override
  String get time => 'Ora';

  @override
  String get hour => 'Ore';

  @override
  String get minute => 'Minuti';

  @override
  String get quickDate => 'Data rapida';

  @override
  String get quickTime => 'Ora rapida';

  @override
  String get inOneWeek => 'Tra 1 settimana';

  @override
  String get prevMonth => 'Mese precedente';

  @override
  String get prevLists => 'Liste precedenti';

  @override
  String get nextLists => 'Liste successive';

  @override
  String get todayAllDone => 'Tutto fatto';

  @override
  String todayOpen(int count) {
    return 'Aperte: $count';
  }

  @override
  String todayOpenLate(int count, int late) {
    return 'Aperte: $count · in ritardo: $late';
  }

  @override
  String get nextMonth => 'Mese successivo';

  @override
  String a11yDone(String title) {
    return 'Fatto: $title';
  }

  @override
  String a11yReopen(String title) {
    return 'Riapri: $title';
  }

  @override
  String a11yCheckSub(String title) {
    return 'Spunta sottoattività: $title';
  }

  @override
  String a11yReopenSub(String title) {
    return 'Riapri sottoattività: $title';
  }

  @override
  String categoryLabel(String name) {
    return 'Categoria: $name';
  }

  @override
  String deletedItem(String name) {
    return '\"$name\" eliminato';
  }

  @override
  String deletedCatMoved(String name, String target) {
    return '\"$name\" eliminata, attività → $target';
  }

  @override
  String infoDue(String day) {
    return 'Scade $day';
  }

  @override
  String infoHandIn(String day) {
    return 'Scade $day';
  }

  @override
  String infoListFrom(String info, String day) {
    return '$info · in lista da $day';
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
  String get pendingSyncHint => 'Verrà sincronizzato appena sei online';

  @override
  String get habits => 'Abitudini';

  @override
  String get habit => 'Abitudine';

  @override
  String get newHabit => 'Nuova abitudine';

  @override
  String get editHabit => 'Modifica abitudine';

  @override
  String get daily => 'Ogni giorno';

  @override
  String get habitsCheckAll => 'Spunta tutte le abitudini di oggi';

  @override
  String get habitsReopenAll => 'Riapri tutte le abitudini';

  @override
  String get habitHint => 'es. Bere acqua';

  @override
  String a11yHabitDoneToday(String name) {
    return '$name fatto oggi';
  }

  @override
  String a11yHabitReopen(String name) {
    return 'Riapri $name';
  }

  @override
  String a11yHabitDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get noHabits => 'Ancora nessuna abitudine – tocca +.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count giorni', one: '1 giorno');
    return '$_temp0';
  }

  @override
  String get categories => 'Categorie';

  @override
  String get manageCategories => 'Gestisci categorie';

  @override
  String get newCategory => 'Nuova categoria';

  @override
  String get editCategory => 'Modifica categoria';

  @override
  String get errCategoryExists => 'Questa categoria esiste già.';

  @override
  String get errName => 'Inserisci un nome.';

  @override
  String get categoryHint => 'es. Presentazione';

  @override
  String get catHomework => 'Compiti';

  @override
  String get catTask => 'Attività';

  @override
  String get catTest => 'Verifica';

  @override
  String get catAppointment => 'Appuntamento';

  @override
  String get doWhen => 'Da fare';

  @override
  String get showInTasks => 'Mostra nelle attività';

  @override
  String get listFromAlways => 'Sempre';

  @override
  String get listFromWeek => 'Da “Questa settimana”';

  @override
  String get listFromTomorrow => 'Da “Domani”';

  @override
  String get listFromToday => 'Da “Oggi”';

  @override
  String get listFromNever => 'Mai';

  @override
  String hiddenByCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività nascoste',
      one: '1 attività nascosta',
    );
    return '$_temp0 – cambia nella categoria';
  }

  @override
  String get offsetSameDay => 'Stesso giorno';

  @override
  String offsetDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni prima',
      one: '1 giorno prima',
    );
    return '$_temp0';
  }

  @override
  String get offsetWeekBefore => '1 settimana prima';

  @override
  String catDoSameDay(int open) {
    return 'Da fare lo stesso giorno · aperte: $open';
  }

  @override
  String catDoDaysBefore(int count, int open) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Da fare $count giorni prima · aperte: $open',
      one: 'Da fare 1 giorno prima · aperte: $open',
    );
    return '$_temp0';
  }

  @override
  String catDoWeekBefore(int open) {
    return 'Da fare 1 settimana prima · $open aperte';
  }

  @override
  String categoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count categorie', one: '1 categoria');
    return '$_temp0';
  }

  @override
  String get newBlock => 'Nuovo blocco';

  @override
  String get editBlock => 'Modifica blocco';

  @override
  String get blockView => 'Blocco';

  @override
  String get edit => 'Modifica';

  @override
  String blockOnlyWeek(String range) {
    return 'Solo nella settimana del $range';
  }

  @override
  String get blockTask => 'Attività collegata';

  @override
  String get blockTaskGone => 'L\'attività collegata non esiste più.';

  @override
  String get blockGone => 'Questo blocco non esiste più.';

  @override
  String get blockAdded => 'Blocco aggiunto';

  @override
  String blocksAdded(int count) {
    return '$count blocchi aggiunti';
  }

  @override
  String get blockDeleted => 'Blocco eliminato';

  @override
  String get from => 'Da';

  @override
  String get to => 'A';

  @override
  String timeWithDuration(String duration) {
    return 'Ora · $duration';
  }

  @override
  String get day => 'Giorno';

  @override
  String get days => 'Giorni';

  @override
  String get everyWeek => 'Ogni settimana';

  @override
  String get repeatEveryWeek => 'Ripeti ogni settimana';

  @override
  String get errToAfterFrom => '\"A\" deve essere dopo \"Da\".';

  @override
  String get durInvalid => '\"A\" deve essere dopo \"Da\"';

  @override
  String get errPickDay => 'Scegli almeno un giorno.';

  @override
  String get tasksThatDay => 'Attività di questo giorno';

  @override
  String get blockHint => 'Scuola, allenamento …';

  @override
  String get prevWeek => 'Settimana precedente';

  @override
  String get nextWeek => 'Settimana successiva';

  @override
  String get prevDay => 'Giorno precedente';

  @override
  String get nextDay => 'Giorno successivo';

  @override
  String get backToWeek => 'Torna alla settimana';

  @override
  String showDay(String day) {
    return 'Mostra $day';
  }

  @override
  String weekNumber(int number) {
    return 'Settimana $number';
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
    return '$name, $day dalle $from alle $to';
  }

  @override
  String durHoursMin(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durHours(int hours) {
    return '$hours h';
  }

  @override
  String durMin(int minutes) {
    return '$minutes min';
  }

  @override
  String get quickPlus30 => '+30 min';

  @override
  String get quickPlus60 => '+1 h';

  @override
  String get quickPlus90 => '+1½ h';

  @override
  String get quickPlus120 => '+2 h';

  @override
  String get activity => 'Andamento';

  @override
  String get period => 'Periodo';

  @override
  String get less => 'meno';

  @override
  String get more => 'più';

  @override
  String get perDay => 'al giorno';

  @override
  String get tileDone => 'fatte';

  @override
  String tileStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'giorni di fila', one: 'giorno di fila');
    return '$_temp0';
  }

  @override
  String daysRange(int count) {
    return '$count giorni';
  }

  @override
  String heatSummary(int total, int days) {
    return '<b>$total</b> fatte in <b>$days</b> giorni';
  }

  @override
  String heatDay(String date, int count) {
    return '$date: <b>$count</b> fatte';
  }

  @override
  String a11yHeatDay(String date, int count) {
    return '$date: $count fatte';
  }

  @override
  String chartA11y(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count attività', one: '1 attività');
    return '$_temp0 fatte in $days giorni';
  }

  @override
  String barTooltip(String day, int count) {
    return '$day: $count';
  }

  @override
  String get byCategory => 'Per categoria';

  @override
  String get language => 'Lingua';

  @override
  String get appearance => 'Aspetto';

  @override
  String get light => 'Chiaro';

  @override
  String get dark => 'Scuro';

  @override
  String get system => 'Sistema';

  @override
  String get theme => 'Tema';

  @override
  String get themeHimmel => 'Cielo';

  @override
  String get themeOzean => 'Oceano';

  @override
  String get themeMint => 'Menta';

  @override
  String get themeWald => 'Bosco';

  @override
  String get themeSonne => 'Sole';

  @override
  String get themeAbendrot => 'Tramonto';

  @override
  String get themeBeere => 'Bacche';

  @override
  String get themeLavendel => 'Lavanda';

  @override
  String get themeNord => 'Nord';

  @override
  String get themeGraphit => 'Grafite';

  @override
  String get colorSkyBlue => 'Azzurro cielo';

  @override
  String get colorMintGreen => 'Verde menta';

  @override
  String get colorSunYellow => 'Giallo sole';

  @override
  String get colorCoral => 'Corallo';

  @override
  String get colorLavender => 'Lavanda';

  @override
  String get reminders => 'Promemoria';

  @override
  String get grid => 'Griglia (minuti)';

  @override
  String get weekStartsOn => 'Inizio settimana';

  @override
  String get dayStarts => 'Il giorno inizia';

  @override
  String get dayEnds => 'Il giorno finisce';

  @override
  String get storage => 'Archiviazione';

  @override
  String get database => 'Database';

  @override
  String get signOut => 'Esci';

  @override
  String get offline => 'Offline';

  @override
  String offlinePending(int count) {
    return 'Offline · $count in attesa';
  }

  @override
  String get synced => 'Sincronizzato';

  @override
  String get syncing => 'Sincronizzazione …';

  @override
  String get allSynced => 'Tutto sincronizzato';

  @override
  String get offlineToast => 'Offline – le modifiche sono salvate sul dispositivo';

  @override
  String get backOnline => 'Di nuovo online';

  @override
  String backOnlineSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Di nuovo online – sincronizzo $count modifiche …',
      one: 'Di nuovo online – sincronizzo 1 modifica …',
    );
    return '$_temp0';
  }

  @override
  String get savedOnDevice => 'Salvato sul dispositivo';

  @override
  String get savedOnDeviceLater => 'Salvato sul dispositivo – verrà sincronizzato più tardi';

  @override
  String get noSyncOtherDevices => 'Nessuna sincronizzazione con altri dispositivi';

  @override
  String get connectToDb => 'Collegati a un database';

  @override
  String get connectToDbSub => 'Sincronizza le attività tra telefono e PC';

  @override
  String get notifChannelName => 'Promemoria';

  @override
  String get notification => 'Notifica';

  @override
  String get remindNone => 'Nessuna';

  @override
  String get remindAtTime => 'All\'ora esatta';

  @override
  String remindBefore(String duration) {
    return '$duration prima';
  }

  @override
  String get remindCustom => 'Altro tempo …';

  @override
  String get remindMinutes => 'Minuti prima';

  @override
  String get remindNeedsTime => 'Solo con un orario';

  @override
  String get remindOff => 'Disattivata nelle opzioni';

  @override
  String get exactRemind => 'Notifiche puntuali';

  @override
  String get exactRemindSub => 'Facoltativo. Senza permesso arrivano comunque, a volte un po\' più tardi.';

  @override
  String get errRemindMinutes => 'Inserisci da 1 a 10080 minuti (massimo 7 giorni).';

  @override
  String get notifChannelDesc => 'Ti ricorda le attività con un orario e i blocchi';

  @override
  String get yearly => 'Ogni anno';

  @override
  String get yearlyHint => 'Si ripete ogni anno';

  @override
  String get doneYearly => 'Fatto – torna l\'anno prossimo';

  @override
  String holidayLine(String name) {
    return 'Festivo: $name';
  }

  @override
  String get hNewYear => 'Capodanno';

  @override
  String get hEpiphany => 'Epifania';

  @override
  String get hEasterMonday => 'Lunedì dell\'Angelo';

  @override
  String get hLabourDay => 'Festa del Lavoro';

  @override
  String get hAscension => 'Ascensione';

  @override
  String get hWhitMonday => 'Lunedì di Pentecoste';

  @override
  String get hCorpusChristi => 'Corpus Domini';

  @override
  String get hAssumption => 'Assunzione';

  @override
  String get hNationalDay => 'Festa nazionale';

  @override
  String get hAllSaints => 'Ognissanti';

  @override
  String get hImmaculate => 'Immacolata Concezione';

  @override
  String get hChristmas => 'Natale';

  @override
  String get hStStephen => 'Santo Stefano';

  @override
  String get yes => 'Sì';

  @override
  String get no => 'No';

  @override
  String get exportData => 'Esporta dati';

  @override
  String get exportSub => 'Salva come PDF, testo o foglio di calcolo';

  @override
  String get exportPdfSub => 'Per leggere e stampare';

  @override
  String get exportTxtSub => 'Testo semplice';

  @override
  String get exportCsvSub => 'Foglio di calcolo per Excel';

  @override
  String get exportSaved => 'Esportazione salvata';

  @override
  String get exportFailed => 'Esportazione non riuscita';

  @override
  String get colTitle => 'Titolo';

  @override
  String get colCategory => 'Categoria';

  @override
  String get colDue => 'Scadenza';

  @override
  String get colDaysDone => 'Giorni fatti';

  @override
  String get colLastDone => 'Ultima volta';

  @override
  String get colDay => 'Giorno';

  @override
  String get colFrom => 'Da';

  @override
  String get colTo => 'A';

  @override
  String get colLeadDays => 'Anticipo (giorni)';

  @override
  String exportStamp(String date) {
    return 'Aggiornato al $date';
  }

  @override
  String exportWeekOf(String date) {
    return 'Solo settimana del $date';
  }

  @override
  String get updates => 'Aggiornamenti';

  @override
  String updateVersion(String version) {
    return 'Versione $version';
  }

  @override
  String updateCurrent(String version) {
    return 'Versione $version – aggiornata';
  }

  @override
  String get updateChecking => 'Controllo aggiornamenti …';

  @override
  String updateAvailable(String version) {
    return 'È disponibile la versione $version';
  }

  @override
  String get updateInstall => 'Installa';

  @override
  String updateDownloading(int percent) {
    return 'Download … $percent %';
  }

  @override
  String get updateInstalling => 'Installazione – l\'app si riavvierà a breve';

  @override
  String get updateConfirm => 'Tocca “Aggiorna” nella finestra di Android';

  @override
  String get updateFailed => 'Non ha funzionato – clicca qui per riprovare';

  @override
  String get langDe => 'Deutsch';

  @override
  String get langEn => 'English';

  @override
  String get langEs => 'Español';

  @override
  String get langFr => 'Français';

  @override
  String get langIt => 'Italiano';

  @override
  String get langNameDe => 'Tedesco';

  @override
  String get langNameEn => 'Inglese';

  @override
  String get langNameEs => 'Spagnolo';

  @override
  String get langNameFr => 'Francese';

  @override
  String get langNameIt => 'Italiano';

  @override
  String get langSameAsDevice => 'Come il dispositivo';

  @override
  String get finish => 'Fatto';

  @override
  String olderDoneLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Carica $count attività completate meno recenti',
      one: 'Carica 1 attività completata meno recente',
    );
    return '$_temp0';
  }

  @override
  String olderDoneOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività completate meno recenti sono visibili solo online',
      one: '1 attività completata meno recente è visibile solo online',
    );
    return '$_temp0';
  }

  @override
  String get olderDoneFailed => 'Impossibile caricare le attività meno recenti';

  @override
  String exportOlderMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Senza $count attività completate meno recenti – disponibili solo online',
      one: 'Senza 1 attività completata meno recente – disponibile solo online',
    );
    return '$_temp0';
  }

  @override
  String flickHeader(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aperte',
      one: '1 aperta',
      zero: 'niente di aperto',
    );
    return 'Oggi, $date · $_temp0';
  }

  @override
  String flickTimed(String time, String title) {
    return '$time $title';
  }

  @override
  String flickOverdue(String title) {
    return '⚠ $title (in ritardo)';
  }

  @override
  String get flickToday => 'Attività di oggi per Flick';

  @override
  String get flickTodaySub => 'Le mostra nel launcher per Windows Flick quando scrivi “Aufgaben”';

  @override
  String get flickCopy => 'Copia scorciatoie Flick';

  @override
  String get flickCopySub => 'Scrivi “flick config” in Flick e incollale in fondo';

  @override
  String get flickCopied => 'Scorciatoie Flick copiate';

  @override
  String get flickAboutAdd => 'Nuova attività in ToDo Planer';

  @override
  String get flickAboutToday => 'Attività di oggi da ToDo Planer';

  @override
  String get flickAboutTab => 'Apri ToDo Planer in una scheda';

  @override
  String get flickGuideTitle => 'Configura Flick';

  @override
  String get flickGuideIntro => 'Le scorciatoie sono copiate. Ecco come aggiungerle a Flick:';

  @override
  String get flickStep1 => 'Apri Flick';

  @override
  String get flickStep1Sub => 'Premi Alt+Spazio.';

  @override
  String get flickStep2 => 'Scrivi “flick config”';

  @override
  String get flickStep2Sub => 'Premi Invio – il file config.toml si apre nel tuo editor.';

  @override
  String get flickStep3 => 'Incolla in fondo';

  @override
  String get flickStep3Sub =>
      'Scorri fino in fondo e premi Ctrl+V. Se hai già aggiunto le scorciatoie, elimina prima il vecchio blocco – altrimenti compaiono due volte.';

  @override
  String get flickStep4 => 'Salva';

  @override
  String get flickStep4Sub => 'Premi Ctrl+S. Flick riconosce subito le scorciatoie.';

  @override
  String get flickGuideList => 'Elenco “Aufgaben”';

  @override
  String get flickGuideTry => 'Cosa puoi scrivere poi';

  @override
  String get flickCopyAgain => 'Copia di nuovo';

  @override
  String get flickHeading => 'Flick';

  @override
  String get closeHint => 'Chiudi suggerimento';

  @override
  String blockMoved(String time) {
    return 'Blocco spostato alle $time';
  }

  @override
  String get pickCategory => 'Categoria';

  @override
  String get addTasksToDay => 'Altre attività per questo giorno';

  @override
  String get pickTasksTitle => 'Attività per questo giorno';

  @override
  String get pickTasksInfo =>
      'Tutte le attività aperte da questo giorno in poi. Quelle che scegli compaiono nel blocco da cui selezionarle.';

  @override
  String get pickTasksNone => 'Nessuna attività aperta da questo giorno in poi.';

  @override
  String applyCount(int count) {
    return 'Aggiungi $count';
  }

  @override
  String get allHabitsDone => 'Tutte le abitudini di oggi fatte. Ottimo lavoro!';
}
