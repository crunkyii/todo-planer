// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ToDo Planer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get undo => 'Annuler';

  @override
  String get add => 'Ajouter';

  @override
  String get added => 'Ajouté';

  @override
  String get saved => 'Enregistré';

  @override
  String get itemGone => 'Cet élément a été supprimé entre-temps.';

  @override
  String get back => 'Retour';

  @override
  String get all => 'Toutes';

  @override
  String get name => 'Nom';

  @override
  String get color => 'Couleur';

  @override
  String get customColor => 'Couleur perso';

  @override
  String get chooseCustomColor => 'Choisir une couleur perso';

  @override
  String get apply => 'Appliquer';

  @override
  String get hue => 'Teinte';

  @override
  String get saturation => 'Saturation';

  @override
  String get brightness => 'Luminosité';

  @override
  String get none => 'Aucun';

  @override
  String get timeNone => 'Aucune';

  @override
  String get done => 'Fait';

  @override
  String get reopened => 'Rouvert';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get mainNavigation => 'Navigation principale';

  @override
  String get navTasks => 'Tâches';

  @override
  String get navCalendar => 'Calendrier';

  @override
  String get navWeek => 'Semaine';

  @override
  String get navStats => 'Bilan';

  @override
  String get navSettings => 'Réglages';

  @override
  String get weeklyPlan => 'Emploi du temps';

  @override
  String get statistics => 'Statistiques';

  @override
  String get settings => 'Réglages';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get setupLead => 'Où veux-tu stocker tes tâches ?';

  @override
  String get setupCloudText =>
      'Ta propre base Supabase gratuite. Téléphone et PC restent synchronisés, même hors ligne.';

  @override
  String get setupLocalTitle => 'Uniquement sur cet appareil';

  @override
  String get setupLocalText => 'Pas de compte, pas de configuration. Tu pourras changer plus tard dans les réglages.';

  @override
  String get languageBoth => 'Langue · Language';

  @override
  String get connectDb => 'Connecter la base de données';

  @override
  String get connectOtherDb => 'Connecter une autre base de données';

  @override
  String get openSupabase => 'Ouvrir supabase.com';

  @override
  String get connectExistingLead =>
      'Ton compte se trouve dans ta propre base de données. Pour que cet appareil puisse te connecter, il lui faut l\'<b>URL du projet</b> et la <b>clé publiable</b> de la base, les mêmes que sur ton premier appareil. Tu trouves les deux dans ton projet Supabase.';

  @override
  String get copySql => 'Copier le SQL';

  @override
  String get sqlCopied => 'SQL copié – colle-le maintenant dans le SQL Editor';

  @override
  String get connect => 'Connecter';

  @override
  String get connecting => 'Connexion …';

  @override
  String get setupStep1 => 'Inscris-toi gratuitement sur <b>supabase.com</b> et crée un <b>nouveau projet</b>.';

  @override
  String get setupStep2 =>
      'Dans le projet, ouvre le <b>SQL Editor</b>, colle le SQL et appuie sur <b>Run</b>. Cela crée les tables.';

  @override
  String get setupStep3 =>
      '<b>URL du projet</b> : appuie sur <b>Connect</b> en haut du projet ou ouvre <b>Project Settings → Data API</b>. Elle ressemble à ceci : https://abcdefgh.supabase.co – la partie avant « .supabase.co » est l\'<b>ID du projet</b> (Project Settings → General). <b>Clé publiable</b> : sous <b>Project Settings → API Keys</b>, elle commence par sb_publishable_. Copie les deux et colle-les ci-dessous.';

  @override
  String get setupStep4 =>
      'Après ton inscription : désactive <b>Authentication → Sign In / Providers</b> → <b>« Allow new users to sign up »</b>. Ainsi, personne d\'autre ne peut créer de compte dans ta base.';

  @override
  String get secretNote =>
      'Ne saisis jamais la <b>clé secrète</b> (service_role) – elle n\'a pas sa place dans une appli.';

  @override
  String get projectUrl => 'URL du projet';

  @override
  String get publishableKey => 'Clé publiable';

  @override
  String get projectUrlHint => 'https://abcdefgh.supabase.co';

  @override
  String get publishableKeyHint => 'sb_publishable_…';

  @override
  String get errUrl => 'L\'URL du projet ressemble à ceci : https://abcdefgh.supabase.co';

  @override
  String get errKeyFormat => 'La clé commence par « sb_publishable_ » (ou « eyJ » pour les anciens projets).';

  @override
  String get errSecretKey => 'C\'est la clé secrète. Utilise la clé publiable.';

  @override
  String get errNoConnection => 'Pas de connexion. L\'URL est-elle correcte et le SQL a-t-il été exécuté ?';

  @override
  String connectedTo(String host) {
    return 'Connecté à $host';
  }

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get haveAccount => 'J\'ai déjà un compte';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get errEmail => 'Saisis une adresse e-mail valide.';

  @override
  String get errPassword => 'Saisis ton mot de passe.';

  @override
  String get errPasswordShort => 'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String get errPasswordLong => 'Le mot de passe est trop long (72 caractères maximum).';

  @override
  String get errWrongLogin => 'E-mail ou mot de passe incorrect.';

  @override
  String get accountCreatedHint => 'Compte créé. Désactive maintenant « Allow new users to sign up » dans Supabase.';

  @override
  String get confirmEmailHint =>
      'Presque fini : confirme ton adresse e-mail avec le lien reçu par mail, puis connecte-toi.';

  @override
  String get errNetwork => 'Pas de connexion au serveur. Vérifie ta connexion internet.';

  @override
  String get errEmailNotConfirmed => 'Confirme d\'abord ton adresse e-mail (lien dans le mail de confirmation).';

  @override
  String get errAccountExists => 'Il existe déjà un compte pour cette adresse e-mail. Connecte-toi.';

  @override
  String get errWeakPassword => 'Le mot de passe est trop faible. Utilise au moins 6 caractères.';

  @override
  String get errRateLimit => 'Trop de tentatives. Attends un instant et réessaie.';

  @override
  String get errSignupDisabled => 'L\'inscription est désactivée dans cette base de données.';

  @override
  String get errSessionExpired => 'Ta session a expiré. Connecte-toi à nouveau.';

  @override
  String errAuthGeneric(String message) {
    return 'Échec de la connexion : $message';
  }

  @override
  String get errNoPermission => 'Aucune autorisation pour cette action. Connecte-toi à nouveau.';

  @override
  String get errTableMissing =>
      'Des tables manquent dans la base de données. Exécute à nouveau le SQL de la configuration.';

  @override
  String errDbGeneric(String message) {
    return 'Erreur de base de données : $message';
  }

  @override
  String get errUnexpected => 'Erreur inattendue. Réessaie.';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get yesterday => 'Hier';

  @override
  String get overdue => 'En retard';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get later => 'Plus tard';

  @override
  String sectionCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get newTask => 'Nouvelle tâche';

  @override
  String get editTask => 'Modifier la tâche';

  @override
  String get deleteTask => 'Supprimer la tâche';

  @override
  String get task => 'Tâche';

  @override
  String get errTaskTitle => 'Indique ce qu\'il y a à faire.';

  @override
  String get nothingDue => 'Rien à faire.';

  @override
  String get widgetUpcoming => 'À venir';

  @override
  String widgetUntil(String when) {
    return 'pour : $when';
  }

  @override
  String get widgetNoHabits => 'Pas encore d\'habitudes.';

  @override
  String get widgetSettings => 'Réglages du widget';

  @override
  String get widgetContent => 'Contenu';

  @override
  String get widgetContentHint => 'Ce que le widget affiche';

  @override
  String get widgetRange => 'Période';

  @override
  String get widgetRangeHint => 'Jusqu\'à quand';

  @override
  String get widgetRange3d => '3 jours';

  @override
  String get widgetRange1w => '1 semaine';

  @override
  String get widgetRange2w => '2 semaines';

  @override
  String get widgetRange1m => '1 mois';

  @override
  String get widgetRangeAll => 'Tout';

  @override
  String get widgetRangeNote =>
      'Les tâches en retard sont toujours incluses, quelle que soit la période. Le nombre en haut ne compte que ce que le widget affiche.';

  @override
  String widgetUntilDate(String date) {
    return 'jusqu\'à $date';
  }

  @override
  String get widgetBackground => 'Arrière-plan';

  @override
  String get widgetShowBackground => 'Afficher l\'arrière-plan';

  @override
  String get widgetShape => 'Forme';

  @override
  String get widgetShapeRound => 'Ronde';

  @override
  String get widgetShapeSoft => 'Douce';

  @override
  String get widgetShapeSquare => 'Carrée';

  @override
  String get widgetBgColor => 'Couleur d\'arrière-plan';

  @override
  String widgetTransparency(int percent) {
    return 'Transparence : $percent %';
  }

  @override
  String get widgetColorApp => 'Comme le thème de l\'appli';

  @override
  String get widgetPreview => 'Aperçu';

  @override
  String get widgetHint =>
      'Appuie longuement sur le widget sur l\'écran d\'accueil et touche « Réglages » pour le modifier plus tard.';

  @override
  String get nothingFound => 'Aucun résultat.';

  @override
  String get noTasks => 'Aucune tâche.';

  @override
  String get searchTasks => 'Rechercher des tâches';

  @override
  String get search => 'Rechercher';

  @override
  String get closeSearch => 'Fermer la recherche';

  @override
  String get columns => 'Colonnes';

  @override
  String get columnsVisible => 'Affichées côte à côte';

  @override
  String get columnsPeriods => 'Périodes';

  @override
  String get columnsCategories => 'Catégories en colonnes séparées';

  @override
  String get close => 'Fermer';

  @override
  String get columnsAllHidden => 'Toutes les colonnes sont masquées. Réactive-les sous ⋮ → Colonnes.';

  @override
  String get columnsDragHint =>
      'Change l\'ordre : maintiens appuyé le titre d\'une colonne, puis fais-la glisser à l\'endroit voulu.';

  @override
  String get moveLeft => 'Déplacer à gauche';

  @override
  String get moveRight => 'Déplacer à droite';

  @override
  String get columnsNarrowHint => 'Une fenêtre étroite affiche moins de colonnes côte à côte que ce qui est réglé ici.';

  @override
  String get columnsDragHintTouch =>
      'Change l\'ordre : appuie longuement sur un titre et fais-le glisser à l\'endroit voulu.';

  @override
  String get moveUp => 'Déplacer vers le haut';

  @override
  String get moveDown => 'Déplacer vers le bas';

  @override
  String get sort => 'Trier';

  @override
  String get sortByDate => 'Par date';

  @override
  String get sortByCategory => 'Par catégorie';

  @override
  String get sortByName => 'Par nom (A–Z)';

  @override
  String get filterByCategory => 'Filtrer par catégorie';

  @override
  String get showCompleted => 'Afficher les terminées';

  @override
  String get hideCompleted => 'Masquer les terminées';

  @override
  String get completedHidden => 'Terminées masquées';

  @override
  String get completedShown => 'Terminées affichées';

  @override
  String get deleteCompleted => 'Supprimer les terminées';

  @override
  String get noCompleted => 'Aucune tâche terminée';

  @override
  String completedDeleted(int count) {
    return 'Terminées supprimées : $count';
  }

  @override
  String get completedTasks => 'Tâches terminées';

  @override
  String get subtask => 'Sous-tâche';

  @override
  String get subtasks => 'Sous-tâches';

  @override
  String get removeSubtask => 'Retirer la sous-tâche';

  @override
  String get notes => 'Note';

  @override
  String get notesHint => 'Plus de détails sur cette tâche …';

  @override
  String get schemaOutdated =>
      'La base de données est plus ancienne que l\'appli : exécute à nouveau schema.sql dans Supabase.';

  @override
  String get dueOn => 'Pour le';

  @override
  String get dateAndTime => 'Date et heure';

  @override
  String get time => 'Heure';

  @override
  String get hour => 'Heure';

  @override
  String get minute => 'Minute';

  @override
  String get quickDate => 'Date rapide';

  @override
  String get quickTime => 'Heure rapide';

  @override
  String get inOneWeek => 'Dans 1 semaine';

  @override
  String get prevMonth => 'Mois précédent';

  @override
  String get prevLists => 'Listes précédentes';

  @override
  String get nextLists => 'Listes suivantes';

  @override
  String get todayAllDone => 'Tout est fait';

  @override
  String todayOpen(int count) {
    return '$count à faire';
  }

  @override
  String todayOpenLate(int count, int late) {
    return '$count à faire, $late en retard';
  }

  @override
  String get nextMonth => 'Mois suivant';

  @override
  String a11yDone(String title) {
    return 'Fait : $title';
  }

  @override
  String a11yReopen(String title) {
    return 'Rouvrir : $title';
  }

  @override
  String a11yCheckSub(String title) {
    return 'Cocher la sous-tâche : $title';
  }

  @override
  String a11yReopenSub(String title) {
    return 'Rouvrir la sous-tâche : $title';
  }

  @override
  String categoryLabel(String name) {
    return 'Catégorie : $name';
  }

  @override
  String deletedItem(String name) {
    return '« $name » supprimé';
  }

  @override
  String deletedCatMoved(String name, String target) {
    return '« $name » supprimé, tâches → $target';
  }

  @override
  String infoDue(String day) {
    return 'Pour $day';
  }

  @override
  String infoHandIn(String day) {
    return 'À rendre $day';
  }

  @override
  String infoListFrom(String info, String day) {
    return '$info · dans la liste dès $day';
  }

  @override
  String dayWithTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String weekdayWithDate(String weekday, String date) {
    return '$weekday $date';
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
  String get pendingSyncHint => 'Se synchronisera dès que tu seras en ligne';

  @override
  String get habits => 'Habitudes';

  @override
  String get habit => 'Habitude';

  @override
  String get newHabit => 'Nouvelle habitude';

  @override
  String get editHabit => 'Modifier l\'habitude';

  @override
  String get daily => 'Tous les jours';

  @override
  String get habitsCheckAll => 'Cocher toutes les habitudes d\'aujourd\'hui';

  @override
  String get habitsReopenAll => 'Rouvrir toutes les habitudes';

  @override
  String get habitHint => 'p. ex. Boire de l\'eau';

  @override
  String a11yHabitDoneToday(String name) {
    return '$name fait aujourd\'hui';
  }

  @override
  String a11yHabitReopen(String name) {
    return 'Rouvrir $name';
  }

  @override
  String a11yHabitDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get noHabits => 'Pas encore d\'habitudes – appuie sur +.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count jours', one: '1 jour');
    return '$_temp0';
  }

  @override
  String get categories => 'Catégories';

  @override
  String get manageCategories => 'Gérer les catégories';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get editCategory => 'Modifier la catégorie';

  @override
  String get errCategoryExists => 'Cette catégorie existe déjà.';

  @override
  String get errName => 'Saisis un nom.';

  @override
  String get categoryHint => 'p. ex. Exposé';

  @override
  String get catHomework => 'Devoirs';

  @override
  String get catTask => 'Tâche';

  @override
  String get catTest => 'Contrôle';

  @override
  String get catAppointment => 'Rendez-vous';

  @override
  String get doWhen => 'À faire';

  @override
  String get showInTasks => 'Afficher dans les tâches';

  @override
  String get listFromAlways => 'Toujours';

  @override
  String get listFromWeek => 'Dès « Cette semaine »';

  @override
  String get listFromTomorrow => 'Dès « Demain »';

  @override
  String get listFromToday => 'Dès « Aujourd\'hui »';

  @override
  String get listFromNever => 'Jamais';

  @override
  String hiddenByCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches masquées',
      one: '1 tâche masquée',
    );
    return '$_temp0 – modifie-le dans la catégorie';
  }

  @override
  String get offsetSameDay => 'Le jour même';

  @override
  String offsetDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count jours avant', one: '1 jour avant');
    return '$_temp0';
  }

  @override
  String get offsetWeekBefore => '1 semaine avant';

  @override
  String catDoSameDay(int open) {
    return 'À faire le jour même · $open à faire';
  }

  @override
  String catDoDaysBefore(int count, int open) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'À faire $count jours avant · $open à faire',
      one: 'À faire 1 jour avant · $open à faire',
    );
    return '$_temp0';
  }

  @override
  String catDoWeekBefore(int open) {
    return 'À faire 1 semaine avant · $open à faire';
  }

  @override
  String categoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count catégories', one: '1 catégorie');
    return '$_temp0';
  }

  @override
  String get newBlock => 'Nouveau bloc';

  @override
  String get editBlock => 'Modifier le bloc';

  @override
  String get blockView => 'Bloc';

  @override
  String get edit => 'Modifier';

  @override
  String blockOnlyWeek(String range) {
    return 'Uniquement la semaine du $range';
  }

  @override
  String get blockTask => 'Tâche liée';

  @override
  String get blockTaskGone => 'La tâche liée n\'existe plus.';

  @override
  String get blockGone => 'Ce bloc n\'existe plus.';

  @override
  String get blockAdded => 'Bloc ajouté';

  @override
  String blocksAdded(int count) {
    return '$count blocs ajoutés';
  }

  @override
  String get blockDeleted => 'Bloc supprimé';

  @override
  String get from => 'De';

  @override
  String get to => 'À';

  @override
  String timeWithDuration(String duration) {
    return 'Heure · $duration';
  }

  @override
  String get day => 'Jour';

  @override
  String get days => 'Jours';

  @override
  String get everyWeek => 'Chaque semaine';

  @override
  String get repeatEveryWeek => 'Répéter chaque semaine';

  @override
  String get errToAfterFrom => '« À » doit être après « De ».';

  @override
  String get durInvalid => '« À » doit être après « De »';

  @override
  String get errPickDay => 'Choisis au moins un jour.';

  @override
  String get tasksThatDay => 'Tâches de ce jour';

  @override
  String get blockHint => 'École, entraînement …';

  @override
  String get prevWeek => 'Semaine précédente';

  @override
  String get nextWeek => 'Semaine suivante';

  @override
  String get prevDay => 'Jour précédent';

  @override
  String get nextDay => 'Jour suivant';

  @override
  String get backToWeek => 'Retour à la semaine';

  @override
  String showDay(String day) {
    return 'Afficher $day';
  }

  @override
  String weekNumber(int number) {
    return 'Semaine $number';
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
    return '$name, $day de $from à $to';
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
  String get activity => 'Activité';

  @override
  String get period => 'Période';

  @override
  String get less => 'moins';

  @override
  String get more => 'plus';

  @override
  String get perDay => 'par jour';

  @override
  String get tileDone => 'faites';

  @override
  String tileStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'jours d\'affilée', one: 'jour d\'affilée');
    return '$_temp0';
  }

  @override
  String daysRange(int count) {
    return '$count jours';
  }

  @override
  String heatSummary(int total, int days) {
    return '<b>$total</b> faites sur <b>$days</b> jours';
  }

  @override
  String heatDay(String date, int count) {
    return '$date : <b>$count</b> faites';
  }

  @override
  String a11yHeatDay(String date, int count) {
    return '$date : $count faites';
  }

  @override
  String chartA11y(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches faites',
      one: '1 tâche faite',
    );
    return '$_temp0 en $days jours';
  }

  @override
  String barTooltip(String day, int count) {
    return '$day : $count';
  }

  @override
  String get byCategory => 'Par catégorie';

  @override
  String get language => 'Langue';

  @override
  String get appearance => 'Apparence';

  @override
  String get light => 'Clair';

  @override
  String get dark => 'Sombre';

  @override
  String get system => 'Système';

  @override
  String get theme => 'Thème';

  @override
  String get themeHimmel => 'Ciel';

  @override
  String get themeOzean => 'Océan';

  @override
  String get themeMint => 'Menthe';

  @override
  String get themeWald => 'Forêt';

  @override
  String get themeSonne => 'Soleil';

  @override
  String get themeAbendrot => 'Crépuscule';

  @override
  String get themeBeere => 'Baie';

  @override
  String get themeLavendel => 'Lavande';

  @override
  String get themeNord => 'Nord';

  @override
  String get themeGraphit => 'Graphite';

  @override
  String get colorSkyBlue => 'Bleu ciel';

  @override
  String get colorMintGreen => 'Vert menthe';

  @override
  String get colorSunYellow => 'Jaune soleil';

  @override
  String get colorCoral => 'Corail';

  @override
  String get colorLavender => 'Lavande';

  @override
  String get reminders => 'Rappels';

  @override
  String get grid => 'Grille (minutes)';

  @override
  String get weekStartsOn => 'La semaine commence le';

  @override
  String get dayStarts => 'Début de journée';

  @override
  String get dayEnds => 'Fin de journée';

  @override
  String get storage => 'Stockage';

  @override
  String get database => 'Base de données';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get offline => 'Hors ligne';

  @override
  String offlinePending(int count) {
    return 'Hors ligne · $count en attente';
  }

  @override
  String get synced => 'Synchronisé';

  @override
  String get syncing => 'Synchronisation …';

  @override
  String get allSynced => 'Tout est synchronisé';

  @override
  String get offlineToast => 'Hors ligne – les modifications sont enregistrées sur l\'appareil';

  @override
  String get backOnline => 'De nouveau en ligne';

  @override
  String backOnlineSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'De nouveau en ligne – synchronisation de $count modifications …',
      one: 'De nouveau en ligne – synchronisation de 1 modification …',
    );
    return '$_temp0';
  }

  @override
  String get savedOnDevice => 'Enregistré sur l\'appareil';

  @override
  String get savedOnDeviceLater => 'Enregistré sur l\'appareil – sera synchronisé plus tard';

  @override
  String get noSyncOtherDevices => 'Pas de synchronisation avec d\'autres appareils';

  @override
  String get connectToDb => 'Connecter une base de données';

  @override
  String get connectToDbSub => 'Synchroniser les tâches entre téléphone et PC';

  @override
  String get notifChannelName => 'Rappels';

  @override
  String get notifChannelDesc => 'Te rappelle les tâches avec une heure';

  @override
  String get yearly => 'Chaque année';

  @override
  String get yearlyHint => 'Se répète chaque année';

  @override
  String get doneYearly => 'Fait – de retour l\'an prochain';

  @override
  String holidayLine(String name) {
    return 'Jour férié : $name';
  }

  @override
  String get hNewYear => 'Jour de l\'An';

  @override
  String get hEpiphany => 'Épiphanie';

  @override
  String get hEasterMonday => 'Lundi de Pâques';

  @override
  String get hLabourDay => 'Fête du Travail';

  @override
  String get hAscension => 'Ascension';

  @override
  String get hWhitMonday => 'Lundi de Pentecôte';

  @override
  String get hCorpusChristi => 'Fête-Dieu';

  @override
  String get hAssumption => 'Assomption';

  @override
  String get hNationalDay => 'Fête nationale';

  @override
  String get hAllSaints => 'Toussaint';

  @override
  String get hImmaculate => 'Immaculée Conception';

  @override
  String get hChristmas => 'Noël';

  @override
  String get hStStephen => 'Saint-Étienne';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get exportData => 'Exporter les données';

  @override
  String get exportSub => 'Enregistrer en PDF, texte ou tableur';

  @override
  String get exportPdfSub => 'Pour lire et imprimer';

  @override
  String get exportTxtSub => 'Texte brut';

  @override
  String get exportCsvSub => 'Tableur pour Excel';

  @override
  String get exportSaved => 'Export enregistré';

  @override
  String get exportFailed => 'Échec de l\'export';

  @override
  String get colTitle => 'Titre';

  @override
  String get colCategory => 'Catégorie';

  @override
  String get colDue => 'Échéance';

  @override
  String get colDaysDone => 'Jours faits';

  @override
  String get colLastDone => 'Dernière fois';

  @override
  String get colDay => 'Jour';

  @override
  String get colFrom => 'De';

  @override
  String get colTo => 'À';

  @override
  String get colLeadDays => 'Avance (jours)';

  @override
  String exportStamp(String date) {
    return 'Au $date';
  }

  @override
  String exportWeekOf(String date) {
    return 'Uniquement la semaine du $date';
  }

  @override
  String get updates => 'Mises à jour';

  @override
  String updateVersion(String version) {
    return 'Version $version';
  }

  @override
  String updateCurrent(String version) {
    return 'Version $version – à jour';
  }

  @override
  String get updateChecking => 'Recherche de mises à jour …';

  @override
  String updateAvailable(String version) {
    return 'La version $version est disponible';
  }

  @override
  String get updateInstall => 'Installer';

  @override
  String updateDownloading(int percent) {
    return 'Téléchargement … $percent %';
  }

  @override
  String get updateInstalling => 'Installation – l\'appli va redémarrer dans un instant';

  @override
  String get updateConfirm => 'Touche « Mettre à jour » dans la boîte de dialogue Android';

  @override
  String get updateFailed => 'Ça n\'a pas marché – clique ici pour réessayer';

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
  String get langNameDe => 'Allemand';

  @override
  String get langNameEn => 'Anglais';

  @override
  String get langNameEs => 'Espagnol';

  @override
  String get langNameFr => 'Français';

  @override
  String get langNameIt => 'Italien';

  @override
  String get langSameAsDevice => 'Comme l\'appareil';

  @override
  String get finish => 'Terminé';

  @override
  String olderDoneLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Charger $count tâches terminées plus anciennes',
      one: 'Charger 1 tâche terminée plus ancienne',
    );
    return '$_temp0';
  }

  @override
  String olderDoneOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches terminées plus anciennes ne sont visibles qu\'en ligne',
      one: '1 tâche terminée plus ancienne n\'est visible qu\'en ligne',
    );
    return '$_temp0';
  }

  @override
  String get olderDoneFailed => 'Impossible de charger les anciennes tâches';

  @override
  String exportOlderMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sans $count tâches terminées plus anciennes – disponibles uniquement en ligne',
      one: 'Sans 1 tâche terminée plus ancienne – disponible uniquement en ligne',
    );
    return '$_temp0';
  }

  @override
  String flickHeader(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à faire',
      one: '1 à faire',
      zero: 'rien à faire',
    );
    return 'Aujourd\'hui, $date · $_temp0';
  }

  @override
  String flickTimed(String time, String title) {
    return '$time $title';
  }

  @override
  String flickOverdue(String title) {
    return '⚠ $title (en retard)';
  }

  @override
  String get flickToday => 'Tâches du jour pour Flick';

  @override
  String get flickTodaySub => 'Les affiche dans le lanceur Windows Flick quand tu tapes « Aufgaben »';

  @override
  String get flickCopy => 'Copier les raccourcis Flick';

  @override
  String get flickCopySub => 'Tape « flick config » dans Flick et colle-les à la fin';

  @override
  String get flickCopied => 'Raccourcis Flick copiés';

  @override
  String get flickAboutAdd => 'Nouvelle tâche dans ToDo Planer';

  @override
  String get flickAboutToday => 'Tâches du jour de ToDo Planer';

  @override
  String get flickAboutTab => 'Ouvrir ToDo Planer sur un onglet';

  @override
  String get flickGuideTitle => 'Configurer Flick';

  @override
  String get flickGuideIntro => 'Les raccourcis sont copiés. Voici comment les ajouter à Flick :';

  @override
  String get flickStep1 => 'Ouvre Flick';

  @override
  String get flickStep1Sub => 'Appuie sur Alt+Espace.';

  @override
  String get flickStep2 => 'Tape « flick config »';

  @override
  String get flickStep2Sub => 'Appuie sur Entrée – le fichier config.toml s\'ouvre dans ton éditeur.';

  @override
  String get flickStep3 => 'Colle à la fin';

  @override
  String get flickStep3Sub =>
      'Descends tout en bas et appuie sur Ctrl+V. Si tu as déjà ajouté les raccourcis, supprime d\'abord l\'ancien bloc – sinon ils apparaissent en double.';

  @override
  String get flickStep4 => 'Enregistre';

  @override
  String get flickStep4Sub => 'Appuie sur Ctrl+S. Flick prend les raccourcis en compte tout de suite.';

  @override
  String get flickGuideList => 'Liste « Aufgaben »';

  @override
  String get flickGuideTry => 'Ce que tu peux taper ensuite';

  @override
  String get flickCopyAgain => 'Copier à nouveau';

  @override
  String get flickHeading => 'Flick';

  @override
  String get closeHint => 'Fermer l\'astuce';

  @override
  String blockMoved(String time) {
    return 'Bloc déplacé à $time';
  }

  @override
  String get pickCategory => 'Catégorie';

  @override
  String get addTasksToDay => 'Plus de tâches pour ce jour';

  @override
  String get pickTasksTitle => 'Tâches pour ce jour';

  @override
  String get pickTasksInfo =>
      'Toutes les tâches ouvertes à partir de ce jour. Celles que tu choisis apparaissent dans le bloc, à sélectionner.';

  @override
  String get pickTasksNone => 'Aucune tâche ouverte à partir de ce jour.';

  @override
  String applyCount(int count) {
    return 'Ajouter $count';
  }

  @override
  String get allHabitsDone => 'Toutes les habitudes du jour sont faites. Bravo !';
}
