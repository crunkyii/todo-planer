// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ToDo Planer';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get undo => 'Undo';

  @override
  String get add => 'Add';

  @override
  String get added => 'Added';

  @override
  String get saved => 'Saved';

  @override
  String get itemGone => 'This item was deleted in the meantime.';

  @override
  String get back => 'Back';

  @override
  String get all => 'All';

  @override
  String get name => 'Name';

  @override
  String get color => 'Colour';

  @override
  String get customColor => 'Custom colour';

  @override
  String get chooseCustomColor => 'Choose custom colour';

  @override
  String get apply => 'Apply';

  @override
  String get hue => 'Hue';

  @override
  String get saturation => 'Saturation';

  @override
  String get brightness => 'Brightness';

  @override
  String get none => 'None';

  @override
  String get timeNone => 'None';

  @override
  String get done => 'Done';

  @override
  String get reopened => 'Reopened';

  @override
  String get moreOptions => 'More options';

  @override
  String get mainNavigation => 'Main navigation';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navWeek => 'Week';

  @override
  String get navStats => 'Statistics';

  @override
  String get navSettings => 'Settings';

  @override
  String get weeklyPlan => 'Weekly plan';

  @override
  String get statistics => 'Statistics';

  @override
  String get settings => 'Settings';

  @override
  String get welcome => 'Welcome';

  @override
  String get setupLead => 'Where should your tasks be stored?';

  @override
  String get setupCloudText => 'Your own free Supabase database. Phone and PC stay in sync, works offline too.';

  @override
  String get setupLocalTitle => 'Only on this device';

  @override
  String get setupLocalText => 'No account, no setup. You can change this later in the settings.';

  @override
  String get languageBoth => 'Sprache · Language';

  @override
  String get connectDb => 'Connect database';

  @override
  String get connectOtherDb => 'Connect another database';

  @override
  String get openSupabase => 'Open supabase.com';

  @override
  String get connectExistingLead =>
      'Your account lives in your own database. Before this device can sign you in, it needs the database\'s <b>Project URL</b> and <b>Publishable Key</b> – the same ones as on your first device. You find both in your Supabase project.';

  @override
  String get copySql => 'Copy SQL';

  @override
  String get sqlCopied => 'SQL copied – now paste it into the SQL Editor';

  @override
  String get connect => 'Connect';

  @override
  String get connecting => 'Connecting …';

  @override
  String get setupStep1 => 'Sign up for free on <b>supabase.com</b> and create a <b>new project</b>.';

  @override
  String get setupStep2 =>
      'In the project, open the <b>SQL Editor</b>, paste the SQL and tap <b>Run</b>. This creates the tables.';

  @override
  String get setupStep3 =>
      '<b>Project URL</b>: tap <b>Connect</b> at the top of the project or open <b>Project Settings → Data API</b>. It looks like this: https://abcdefgh.supabase.co – the part before \".supabase.co\" is the <b>Project ID</b> (Project Settings → General). <b>Publishable Key</b>: under <b>Project Settings → API Keys</b>, starts with sb_publishable_. Copy both and paste them below.';

  @override
  String get setupStep4 =>
      'After you have signed up: turn off <b>Authentication → Sign In / Providers</b> → <b>\"Allow new users to sign up\"</b>. Then nobody else can create an account in your database.';

  @override
  String get secretNote => 'Never enter the <b>Secret Key</b> (service_role) – it does not belong in an app.';

  @override
  String get projectUrl => 'Project URL';

  @override
  String get publishableKey => 'Publishable Key';

  @override
  String get projectUrlHint => 'https://abcdefgh.supabase.co';

  @override
  String get publishableKeyHint => 'sb_publishable_…';

  @override
  String get errUrl => 'The Project URL looks like this: https://abcdefgh.supabase.co';

  @override
  String get errKeyFormat => 'The key starts with \"sb_publishable_\" (or \"eyJ\" for older projects).';

  @override
  String get errSecretKey => 'That is the secret key. Please use the Publishable Key.';

  @override
  String get errNoConnection => 'No connection. Is the URL correct and was the SQL run?';

  @override
  String connectedTo(String host) {
    return 'Connected to $host';
  }

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get errEmail => 'Please enter a valid email address.';

  @override
  String get errPassword => 'Please enter your password.';

  @override
  String get errPasswordShort => 'The password needs at least 6 characters.';

  @override
  String get errPasswordLong => 'The password is too long (72 characters at most).';

  @override
  String get errWrongLogin => 'Email or password is wrong.';

  @override
  String get accountCreatedHint => 'Account created. Now turn off \"Allow new users to sign up\" in Supabase.';

  @override
  String get confirmEmailHint =>
      'Almost done: please confirm your email address with the link in the mail, then sign in.';

  @override
  String get errNetwork => 'No connection to the server. Please check your internet connection.';

  @override
  String get errEmailNotConfirmed => 'Please confirm your email address first (link in the confirmation mail).';

  @override
  String get errAccountExists => 'There is already an account for this email address. Please sign in.';

  @override
  String get errWeakPassword => 'The password is too weak. Use at least 6 characters.';

  @override
  String get errRateLimit => 'Too many attempts. Please wait a moment and try again.';

  @override
  String get errSignupDisabled => 'Sign-up is turned off in this database.';

  @override
  String get errSessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String errAuthGeneric(String message) {
    return 'Sign-in failed: $message';
  }

  @override
  String get errNoPermission => 'No permission for this action. Please sign in again.';

  @override
  String get errTableMissing => 'Tables are missing in the database. Please run the SQL from the setup again.';

  @override
  String errDbGeneric(String message) {
    return 'Database error: $message';
  }

  @override
  String get errUnexpected => 'Unexpected error. Please try again.';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get overdue => 'Overdue';

  @override
  String get thisWeek => 'This week';

  @override
  String get later => 'Later';

  @override
  String sectionCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get newTask => 'New task';

  @override
  String get editTask => 'Edit task';

  @override
  String get deleteTask => 'Delete task';

  @override
  String get task => 'Task';

  @override
  String get errTaskTitle => 'Please enter what needs to be done.';

  @override
  String get nothingDue => 'Nothing due.';

  @override
  String get widgetUpcoming => 'Upcoming';

  @override
  String widgetUntil(String when) {
    return 'by: $when';
  }

  @override
  String get widgetNoHabits => 'No habits yet.';

  @override
  String get widgetSettings => 'Widget settings';

  @override
  String get widgetBackground => 'Background';

  @override
  String get widgetShowBackground => 'Show background';

  @override
  String get widgetShape => 'Shape';

  @override
  String get widgetShapeRound => 'Round';

  @override
  String get widgetShapeSoft => 'Soft';

  @override
  String get widgetShapeSquare => 'Square';

  @override
  String get widgetBgColor => 'Background colour';

  @override
  String widgetTransparency(int percent) {
    return 'Transparency: $percent%';
  }

  @override
  String get widgetColorApp => 'Same as app theme';

  @override
  String get widgetPreview => 'Preview';

  @override
  String get widgetHint => 'Touch and hold the widget on the home screen and tap “Settings” to change it later.';

  @override
  String get nothingFound => 'Nothing found.';

  @override
  String get noTasks => 'No tasks.';

  @override
  String get searchTasks => 'Search tasks';

  @override
  String get search => 'Search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get columns => 'Columns';

  @override
  String get columnsVisible => 'Visible side by side';

  @override
  String get columnsPeriods => 'Time periods';

  @override
  String get columnsCategories => 'Categories as their own column';

  @override
  String get close => 'Close';

  @override
  String get columnsAllHidden => 'All columns are hidden. Turn them back on under ⋮ → Columns.';

  @override
  String get columnsDragHint => 'Change the order: drag a column by its heading to where you want it.';

  @override
  String get moveLeft => 'Move left';

  @override
  String get moveRight => 'Move right';

  @override
  String get columnsNarrowHint => 'A narrow window fits fewer columns side by side than set here.';

  @override
  String get columnsDragHintTouch => 'Change the order: long-press a heading and drag it to where you want it.';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get sort => 'Sort';

  @override
  String get sortByDate => 'By date';

  @override
  String get sortByCategory => 'By category';

  @override
  String get sortByName => 'By name (A–Z)';

  @override
  String get filterByCategory => 'Filter by category';

  @override
  String get showCompleted => 'Show completed';

  @override
  String get hideCompleted => 'Hide completed';

  @override
  String get completedHidden => 'Completed hidden';

  @override
  String get completedShown => 'Completed shown';

  @override
  String get deleteCompleted => 'Delete completed';

  @override
  String get noCompleted => 'No completed tasks';

  @override
  String completedDeleted(int count) {
    return '$count completed deleted';
  }

  @override
  String get completedTasks => 'Completed tasks';

  @override
  String get subtask => 'Subtask';

  @override
  String get subtasks => 'Subtasks';

  @override
  String get removeSubtask => 'Remove subtask';

  @override
  String get notes => 'Note';

  @override
  String get notesHint => 'More about this task …';

  @override
  String get schemaOutdated => 'The database is older than the app: run schema.sql in Supabase again.';

  @override
  String get dueOn => 'Due on';

  @override
  String get dateAndTime => 'Date and time';

  @override
  String get time => 'Time';

  @override
  String get hour => 'Hour';

  @override
  String get minute => 'Minute';

  @override
  String get quickDate => 'Quick date';

  @override
  String get quickTime => 'Quick time';

  @override
  String get inOneWeek => 'In 1 week';

  @override
  String get prevMonth => 'Previous month';

  @override
  String get prevLists => 'Previous lists';

  @override
  String get nextLists => 'Next lists';

  @override
  String get todayAllDone => 'All done';

  @override
  String todayOpen(int count) {
    return '$count open';
  }

  @override
  String todayOpenLate(int count, int late) {
    return '$count open, $late overdue';
  }

  @override
  String get nextMonth => 'Next month';

  @override
  String a11yDone(String title) {
    return 'Done: $title';
  }

  @override
  String a11yReopen(String title) {
    return 'Reopen: $title';
  }

  @override
  String a11yCheckSub(String title) {
    return 'Check subtask: $title';
  }

  @override
  String a11yReopenSub(String title) {
    return 'Reopen subtask: $title';
  }

  @override
  String categoryLabel(String name) {
    return 'Category: $name';
  }

  @override
  String deletedItem(String name) {
    return '\"$name\" deleted';
  }

  @override
  String deletedCatMoved(String name, String target) {
    return '\"$name\" deleted, tasks → $target';
  }

  @override
  String infoDue(String day) {
    return 'Due $day';
  }

  @override
  String infoHandIn(String day) {
    return 'Due $day';
  }

  @override
  String infoListFrom(String info, String day) {
    return '$info · in list from $day';
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
  String get pendingSyncHint => 'Will sync as soon as you are online';

  @override
  String get habits => 'Habits';

  @override
  String get habit => 'Habit';

  @override
  String get newHabit => 'New habit';

  @override
  String get editHabit => 'Edit habit';

  @override
  String get daily => 'Daily';

  @override
  String get habitsCheckAll => 'Check off all habits for today';

  @override
  String get habitsReopenAll => 'Reopen all habits';

  @override
  String get habitHint => 'e.g. Drink water';

  @override
  String a11yHabitDoneToday(String name) {
    return '$name done today';
  }

  @override
  String a11yHabitReopen(String name) {
    return 'Reopen $name';
  }

  @override
  String a11yHabitDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get noHabits => 'No habits yet – tap +.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days', one: '1 day');
    return '$_temp0';
  }

  @override
  String get categories => 'Categories';

  @override
  String get manageCategories => 'Manage categories';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get errCategoryExists => 'This category already exists.';

  @override
  String get errName => 'Please enter a name.';

  @override
  String get categoryHint => 'e.g. Presentation';

  @override
  String get catHomework => 'Homework';

  @override
  String get catTask => 'Task';

  @override
  String get catTest => 'Test';

  @override
  String get catAppointment => 'Appointment';

  @override
  String get doWhen => 'Complete';

  @override
  String get showInTasks => 'Show in tasks';

  @override
  String get listFromAlways => 'Always';

  @override
  String get listFromWeek => 'From “This week”';

  @override
  String get listFromTomorrow => 'From “Tomorrow”';

  @override
  String get listFromToday => 'From “Today”';

  @override
  String get listFromNever => 'Never';

  @override
  String hiddenByCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks hidden',
      one: '1 task hidden',
    );
    return '$_temp0 – change it in the category';
  }

  @override
  String get offsetSameDay => 'Same day';

  @override
  String offsetDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days before', one: '1 day before');
    return '$_temp0';
  }

  @override
  String get offsetWeekBefore => '1 week before';

  @override
  String catDoSameDay(int open) {
    return 'Do on the same day · $open open';
  }

  @override
  String catDoDaysBefore(int count, int open) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Do $count days before · $open open',
      one: 'Do 1 day before · $open open',
    );
    return '$_temp0';
  }

  @override
  String catDoWeekBefore(int open) {
    return 'Do 1 week before · $open open';
  }

  @override
  String categoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count categories', one: '1 category');
    return '$_temp0';
  }

  @override
  String get newBlock => 'New block';

  @override
  String get editBlock => 'Edit block';

  @override
  String get blockAdded => 'Block added';

  @override
  String blocksAdded(int count) {
    return '$count blocks added';
  }

  @override
  String get blockDeleted => 'Block deleted';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String timeWithDuration(String duration) {
    return 'Time · $duration';
  }

  @override
  String get day => 'Day';

  @override
  String get days => 'Days';

  @override
  String get everyWeek => 'Every week';

  @override
  String get repeatEveryWeek => 'Repeat every week';

  @override
  String get errToAfterFrom => '\"To\" must be after \"From\".';

  @override
  String get durInvalid => '\"To\" must be after \"From\"';

  @override
  String get errPickDay => 'Please pick at least one day.';

  @override
  String get tasksThatDay => 'Tasks on this day';

  @override
  String get blockHint => 'School, training …';

  @override
  String get prevWeek => 'Previous week';

  @override
  String get nextWeek => 'Next week';

  @override
  String get prevDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get backToWeek => 'Back to week';

  @override
  String showDay(String day) {
    return 'Show $day';
  }

  @override
  String weekNumber(int number) {
    return 'Week $number';
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
    return '$name, $day $from to $to';
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
  String get activity => 'Activity';

  @override
  String get period => 'Period';

  @override
  String get less => 'less';

  @override
  String get more => 'more';

  @override
  String get perDay => 'per day';

  @override
  String get tileDone => 'done';

  @override
  String tileStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'day streak', one: 'day streak');
    return '$_temp0';
  }

  @override
  String daysRange(int count) {
    return '$count days';
  }

  @override
  String heatSummary(int total, int days) {
    return '<b>$total</b> done on <b>$days</b> days';
  }

  @override
  String heatDay(String date, int count) {
    return '$date: <b>$count</b> done';
  }

  @override
  String a11yHeatDay(String date, int count) {
    return '$date: $count done';
  }

  @override
  String chartA11y(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tasks', one: '1 task');
    return '$_temp0 done in $days days';
  }

  @override
  String barTooltip(String day, int count) {
    return '$day: $count';
  }

  @override
  String get byCategory => 'By category';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get themeHimmel => 'Sky';

  @override
  String get themeOzean => 'Ocean';

  @override
  String get themeMint => 'Mint';

  @override
  String get themeWald => 'Forest';

  @override
  String get themeSonne => 'Sun';

  @override
  String get themeAbendrot => 'Sunset';

  @override
  String get themeBeere => 'Berry';

  @override
  String get themeLavendel => 'Lavender';

  @override
  String get themeNord => 'Nord';

  @override
  String get themeGraphit => 'Graphite';

  @override
  String get colorSkyBlue => 'Sky blue';

  @override
  String get colorMintGreen => 'Mint green';

  @override
  String get colorSunYellow => 'Sun yellow';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorLavender => 'Lavender';

  @override
  String get reminders => 'Reminders';

  @override
  String get grid => 'Grid (minutes)';

  @override
  String get weekStartsOn => 'Week starts on';

  @override
  String get dayStarts => 'Day starts';

  @override
  String get dayEnds => 'Day ends';

  @override
  String get storage => 'Storage';

  @override
  String get database => 'Database';

  @override
  String get signOut => 'Sign out';

  @override
  String get offline => 'Offline';

  @override
  String offlinePending(int count) {
    return 'Offline · $count pending';
  }

  @override
  String get synced => 'Synced';

  @override
  String get syncing => 'Syncing …';

  @override
  String get allSynced => 'Everything synced';

  @override
  String get offlineToast => 'Offline – changes are saved on the device';

  @override
  String get backOnline => 'Back online';

  @override
  String backOnlineSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Back online – syncing $count changes …',
      one: 'Back online – syncing 1 change …',
    );
    return '$_temp0';
  }

  @override
  String get savedOnDevice => 'Saved on the device';

  @override
  String get savedOnDeviceLater => 'Saved on the device – will sync later';

  @override
  String get noSyncOtherDevices => 'No sync with other devices';

  @override
  String get connectToDb => 'Connect to a database';

  @override
  String get connectToDbSub => 'Sync tasks between phone and PC';

  @override
  String get notifChannelName => 'Reminders';

  @override
  String get notifChannelDesc => 'Reminds you of tasks with a time';

  @override
  String get yearly => 'Yearly';

  @override
  String get yearlyHint => 'Repeats every year';

  @override
  String get doneYearly => 'Done – back next year';

  @override
  String holidayLine(String name) {
    return 'Public holiday: $name';
  }

  @override
  String get hNewYear => 'New Year\'s Day';

  @override
  String get hEpiphany => 'Epiphany';

  @override
  String get hEasterMonday => 'Easter Monday';

  @override
  String get hLabourDay => 'Labour Day';

  @override
  String get hAscension => 'Ascension Day';

  @override
  String get hWhitMonday => 'Whit Monday';

  @override
  String get hCorpusChristi => 'Corpus Christi';

  @override
  String get hAssumption => 'Assumption Day';

  @override
  String get hNationalDay => 'National Day';

  @override
  String get hAllSaints => 'All Saints\' Day';

  @override
  String get hImmaculate => 'Immaculate Conception';

  @override
  String get hChristmas => 'Christmas Day';

  @override
  String get hStStephen => 'St. Stephen\'s Day';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get exportData => 'Export data';

  @override
  String get exportSub => 'Save as PDF, text or spreadsheet';

  @override
  String get exportPdfSub => 'For reading and printing';

  @override
  String get exportTxtSub => 'Plain text';

  @override
  String get exportCsvSub => 'Spreadsheet for Excel';

  @override
  String get exportSaved => 'Export saved';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get colTitle => 'Title';

  @override
  String get colCategory => 'Category';

  @override
  String get colDue => 'Due';

  @override
  String get colDaysDone => 'Days done';

  @override
  String get colLastDone => 'Last done';

  @override
  String get colDay => 'Day';

  @override
  String get colFrom => 'From';

  @override
  String get colTo => 'To';

  @override
  String get colLeadDays => 'Lead time (days)';

  @override
  String exportStamp(String date) {
    return 'As of $date';
  }

  @override
  String exportWeekOf(String date) {
    return 'Only week of $date';
  }

  @override
  String get updates => 'Updates';

  @override
  String updateVersion(String version) {
    return 'Version $version';
  }

  @override
  String updateCurrent(String version) {
    return 'Version $version – up to date';
  }

  @override
  String get updateChecking => 'Checking for updates …';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateInstall => 'Install';

  @override
  String updateDownloading(int percent) {
    return 'Downloading … $percent %';
  }

  @override
  String get updateInstalling => 'Installing – the app will restart shortly';

  @override
  String get updateConfirm => 'Please tap “Update” in the Android dialog';

  @override
  String get updateFailed => 'That did not work – click here to try again';

  @override
  String get langDe => 'Deutsch';

  @override
  String get langEn => 'English';

  @override
  String olderDoneLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Load $count older completed tasks',
      one: 'Load 1 older completed task',
    );
    return '$_temp0';
  }

  @override
  String olderDoneOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count older completed tasks are only visible online',
      one: '1 older completed task is only visible online',
    );
    return '$_temp0';
  }

  @override
  String get olderDoneFailed => 'Could not load older tasks';

  @override
  String exportOlderMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Without $count older completed tasks – only available online',
      one: 'Without 1 older completed task – only available online',
    );
    return '$_temp0';
  }

  @override
  String flickHeader(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open',
      one: '1 open',
      zero: 'nothing open',
    );
    return 'Today, $date · $_temp0';
  }

  @override
  String flickTimed(String time, String title) {
    return '$time $title';
  }

  @override
  String flickOverdue(String title) {
    return '⚠ $title (overdue)';
  }

  @override
  String get flickToday => 'Today\'s tasks for Flick';

  @override
  String get flickTodaySub => 'Shows them in the Windows launcher Flick when you type “Aufgaben”';

  @override
  String get flickCopy => 'Copy Flick shortcuts';

  @override
  String get flickCopySub => 'Type “flick config” in Flick and paste them at the end';

  @override
  String get flickCopied => 'Flick shortcuts copied';

  @override
  String get flickAboutAdd => 'New task in ToDo Planer';

  @override
  String get flickAboutAddTitle => 'New task with a title, e.g. aufgabe Learn maths';

  @override
  String get flickAboutToday => 'Today\'s tasks from ToDo Planer';

  @override
  String get flickAboutTab => 'Open ToDo Planer on a tab';

  @override
  String get flickGuideTitle => 'Set up Flick';

  @override
  String get flickGuideIntro => 'The shortcuts are copied. Here is how to add them to Flick:';

  @override
  String get flickStep1 => 'Open Flick';

  @override
  String get flickStep1Sub => 'Press Alt+Space.';

  @override
  String get flickStep2 => 'Type “flick config”';

  @override
  String get flickStep2Sub => 'Press Enter – the file config.toml opens in your editor.';

  @override
  String get flickStep3 => 'Paste at the end';

  @override
  String get flickStep3Sub =>
      'Scroll all the way down and press Ctrl+V. If you added the shortcuts before, delete the old block first – otherwise they show up twice.';

  @override
  String get flickStep4 => 'Save';

  @override
  String get flickStep4Sub => 'Press Ctrl+S. Flick picks up the shortcuts right away.';

  @override
  String get flickGuideList => '“Aufgaben” list';

  @override
  String get flickGuideTry => 'What you can type then';

  @override
  String get flickCopyAgain => 'Copy again';

  @override
  String get flickHeading => 'Flick';

  @override
  String get closeHint => 'Close hint';

  @override
  String blockMoved(String time) {
    return 'Block moved to $time';
  }

  @override
  String get pickCategory => 'Category';

  @override
  String get addTasksToDay => 'More tasks for this day';

  @override
  String get pickTasksTitle => 'Tasks for this day';

  @override
  String get pickTasksInfo => 'All open tasks from this day on. The ones you pick show up in the block to choose from.';

  @override
  String get pickTasksNone => 'No open tasks from this day on.';

  @override
  String applyCount(int count) {
    return 'Add $count';
  }
}
