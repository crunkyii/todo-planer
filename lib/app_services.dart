import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/cloud.dart';
import 'data/settings_store.dart';
import 'data/store.dart';
import 'data/sync_service.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/flick_export.dart';
import 'services/home_widgets.dart';
import 'services/launch_commands.dart';
import 'services/reminders.dart';
import 'services/updater.dart';
import 'theme/tokens.dart';
import 'util/dates.dart';
import 'util/fmt.dart';
import 'util/task_logic.dart';
import 'widgets/app_icon.dart';
import 'widgets/snack.dart';

/// Alle Dienste der App an einem Ort; über [AppScope] im Widget-Baum erreichbar.
class AppServices extends ChangeNotifier {
  AppServices({
    required this.settings,
    required this.store,
    required this.cloud,
    required this.sync,
    required this.reminders,
    this.updater,
    LaunchCommands? launch,
    FlickExport? flick,
  }) : launch = launch ?? LaunchCommands(),
       flick = flick ?? FlickExport() {
    updater?.addListener(_announceUpdate);
    store.onLocalChange = _onLocalChange;
    store.addListener(_refreshRemindersAndWidgets);
    settings.addListener(_onSettingsChanged);
    sync.onPulled = _afterPull;
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    store.addListener(_scheduleNextChange);
    _scheduleNextChange();
  }

  /// Startbildschirm-Widgets (Android): bekommen nach jeder Änderung die aktuellen Daten.
  final homeWidgets = HomeWidgets();

  /// Aufrufe von außen (`todoplaner://…`, z. B. aus dem Windows-Launcher Flick).
  final LaunchCommands launch;

  /// Windows: die heutigen Aufgaben als Liste für Flick (nur wenn in den Optionen eingeschaltet).
  final FlickExport flick;

  late final AppLifecycleListener _lifecycle;
  Timer? _nextChangeTimer;
  DateTime _nextChange = clock();

  /// Zurück in der App: Neues vom Server holen und „heute“ neu berechnen.
  void _onResume() {
    if (signedIn) sync.schedule(remote: true);
    // War die App im Hintergrund, kann der Zeitpunkt inzwischen vorbei sein.
    if (!clock().isBefore(_nextChange)) _listChanged();
  }

  /// Neu zeichnen, sobald sich die Liste von selbst ändert: um Mitternacht („Heute“, „Morgen“,
  /// Gewohnheiten) und wenn die Uhrzeit einer Abgabe vorbei ist (ab dann ist sie überfällig).
  void _scheduleNextChange() {
    _nextChangeTimer?.cancel();
    final now = clock();
    _nextChange = nextListChange(store.tasks, now);
    _nextChangeTimer = Timer(_nextChange.difference(now) + const Duration(seconds: 1), _listChanged);
  }

  /// Zeichnet neu; der Zeitgeber wird dabei neu gestellt (der Store meldet die Änderung).
  void _listChanged() => store.touch();

  final SettingsStore settings;
  final Store store;
  final Cloud cloud;
  final SyncService sync;
  final Reminders reminders;
  final snack = SnackController();

  /// Auto-Update (nur die installierte Windows-App; sonst `null` oder ohne Wirkung).
  final Updater? updater;
  bool _updateAnnounced = false;

  /// `true` = Einrichtung „Datenbank verbinden“ wurde aus Login/Optionen geöffnet.
  bool setupOpen = false;

  /// Die Anmeldung nach dem Verbinden im „Konto erstellen“-Modus starten.
  bool registerNext = false;

  StreamSubscription<AuthState>? _authSub;
  String? _userId;
  Timer? _reminderTimer;
  String? _reminderSig;
  AppLocalizations? _l;

  User? get user => cloud.user;
  bool get signedIn => settings.syncMode == SyncMode.cloud && user != null;

  /// Startet Supabase, falls eine Datenbank eingerichtet ist.
  Future<void> boot() async {
    unawaited(updater?.check(silent: true));
    await sync.start();
    if (settings.syncMode == SyncMode.cloud && settings.cloud != null) {
      try {
        await _initCloud(settings.cloud!);
      } on Object catch (e) {
        debugPrint('Supabase-Start fehlgeschlagen: ${e.runtimeType}');
      }
    }
  }

  Future<void> _initCloud(CloudConfig c) async {
    await _authSub?.cancel();
    await cloud.init(c);
    _authSub = cloud.authChanges.listen((_) => _authChanged());
    await _authChanged();
  }

  Future<void> _authChanged() async {
    final id = cloud.user?.id;
    if (id == _userId) return;
    _userId = id;
    if (id != null) {
      await _onSignedIn(id);
    } else {
      await sync.detach();
    }
    notifyListeners();
  }

  /// Gehören die lokalen Daten einem anderen Konto, werden sie verworfen;
  /// lokale Daten ohne Konto („Nur auf diesem Gerät“) werden hochgeladen.
  Future<void> _onSignedIn(String userId) async {
    final owner = '${settings.cloud?.host}|$userId';
    if (settings.owner != owner) {
      if (settings.owner != null) {
        await store.wipe();
      } else {
        await store.markAllDirty();
      }
      await settings.resetCursors();
      await settings.setOwner(owner);
    }
    // Nicht darauf warten, damit der Start bei langsamem Netz nicht hängt. Standard-
    // Kategorien erst nach dem ersten erfolgreichen Abruf (siehe [_afterPull]) – sonst
    // entstehen sie auf jedem Gerät doppelt.
    _firstSyncDone = false;
    unawaited(sync.attach());
  }

  /// Erst nach dem ersten Abruf wissen wir, ob das Konto schon Kategorien hat.
  bool _firstSyncDone = false;

  void _afterPull() {
    if (_firstSyncDone) return;
    _firstSyncDone = true;
    // Gleichnamige Kategorien (z. B. Standard-Kategorien von zwei Geräten) zusammenführen.
    store.mergeDuplicateCategories();
    _ensureDefaults();
  }

  /// Die App braucht mindestens eine Kategorie. Beim allerersten Start werden die
  /// Standard-Kategorien in der gewählten Sprache angelegt (danach sind es eigene Einträge).
  void _ensureDefaults() {
    final l = _l;
    if (l == null) return;
    store.ensureDefaultCategories([
      (name: l.catHomework, color: ColorPreset.skyBlue.hex, offset: 1),
      (name: l.catTask, color: ColorPreset.mintGreen.hex, offset: 0),
      (name: l.catTest, color: ColorPreset.coral.hex, offset: 2),
      (name: l.catAppointment, color: ColorPreset.lavender.hex, offset: 0),
    ]);
  }

  /// Wird vom App-Bildschirm mit den aktuellen Texten aufgerufen.
  void enterApp(AppLocalizations l) {
    final changed = _l?.localeName != l.localeName;
    _l = l;
    _announceUpdate();
    reminders.setTexts(channelName: l.notifChannelName, channelDesc: l.notifChannelDesc);
    if (settings.syncMode == SyncMode.local || (signedIn && _firstSyncDone)) _ensureDefaults();
    if (changed) _refreshRemindersAndWidgets();
  }

  /// Die App braucht mindestens eine Kategorie, um eine Aufgabe anzulegen – notfalls
  /// sofort (auch vor dem ersten Abgleich; Doppelte werden danach zusammengeführt).
  void ensureCategoriesNow(AppLocalizations l) {
    _l = l;
    _ensureDefaults();
  }

  Future<void> chooseLocal() async {
    await settings.setLocalMode();
    setupOpen = false;
    notifyListeners();
  }

  /// Neue Datenbank übernehmen (nach erfolgreichem Verbindungstest).
  /// Danach kommt die Anmeldung – mit [register] als „Konto erstellen“, sonst als „Anmelden“.
  Future<void> connectCloud(CloudConfig c, {bool register = true}) async {
    await sync.detach();
    await settings.setCloud(c);
    setupOpen = false;
    registerNext = register;
    _userId = null;
    await _initCloud(c);
    notifyListeners();
  }

  void openSetup() {
    setupOpen = true;
    notifyListeners();
  }

  void closeSetup() {
    setupOpen = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    snack.clear();
    registerNext = false; // nach dem Abmelden kommt „Anmelden“, nicht „Konto erstellen“
    await sync.idle();
    await sync.sync();
    await sync.idle();
    await sync.detach();
    await cloud.signOut();
    await _authChanged();
  }

  /// Einmal pro Start melden, dass es eine neue Version gibt (installiert wird in den Optionen).
  void _announceUpdate() {
    final l = _l, version = updater?.found?.version;
    if (l == null || version == null || _updateAnnounced || updater?.state != UpdateState.available) return;
    _updateAnnounced = true;
    snack.show(l.updateAvailable(version), icon: Ic.sync);
  }

  void _onLocalChange() {
    if (signedIn) sync.schedule();
  }

  void _onSettingsChanged() {
    if (settings.dirty && signedIn) sync.schedule();
    _refreshRemindersAndWidgets();
  }

  /// Nach jeder Änderung an Daten oder Einstellungen (gebündelt, mit kurzer Pause): die
  /// Startbildschirm-Widgets bekommen den neuen Stand und die Erinnerungen werden neu geplant.
  void _refreshRemindersAndWidgets() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(milliseconds: 800), () {
      final l = _l;
      if (l == null) return;
      unawaited(homeWidgets.push(store, l, themeId: settings.theme));
      unawaited(flick.push(settings.flick ? flickTodayEntries(store, l) : null));
      final f = Fmt(l);
      // Kommt die Benachrichtigung schon an einem anderen Tag, steht das Datum dabei.
      String when(DateTime day, int start, int remind, String time) =>
          remind > start ? l.dayWithTime(f.wdDayMon(day), time) : time;
      final items = mergeReminders(
        upcomingReminders(
          store.tasks,
          (t) =>
              l.dayWithTime(store.catOf(t.categoryId).name, when(t.dueDate, t.dueTime!, t.remind, f.time(t.dueTime!))),
        ),
        upcomingBlockReminders(
          store.blocksOn,
          (b, day) => when(day, b.start, b.remind, l.rangeDash(f.time(b.start), f.time(b.end))),
          taskDone: (id) => store.taskById(id)?.done ?? false,
        ),
      );
      // Nur neu planen, wenn sich an den Erinnerungen wirklich etwas geändert hat
      // (der Store meldet auch Gewohnheiten, Sync-Status usw.) – und einmal am Tag, weil nicht
      // überall beliebig weit vorausgeplant wird.
      final sig =
          '${isoDate(today())}|${settings.remind}|${items.map((r) => '${r.id}@${r.at.millisecondsSinceEpoch}:${r.title}:${r.body}').join(',')}';
      if (sig == _reminderSig) return;
      _reminderSig = sig;
      reminders.reschedule(items, enabled: settings.remind);
    });
  }

  /// Toast-Helfer: „Gespeichert“ bzw. offline „Am Gerät gespeichert“.
  bool get offlineCloud => settings.syncMode == SyncMode.cloud && !sync.online;

  @override
  void dispose() {
    _authSub?.cancel();
    _reminderTimer?.cancel();
    _nextChangeTimer?.cancel();
    store
      ..removeListener(_scheduleNextChange)
      ..removeListener(_refreshRemindersAndWidgets)
      ..onLocalChange = null;
    settings.removeListener(_onSettingsChanged);
    sync.onPulled = null;
    updater
      ?..removeListener(_announceUpdate)
      ..dispose();
    _lifecycle.dispose();
    snack.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});
  final AppServices services;

  static AppServices of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  /// Ohne Abhängigkeit (für Aktionen in Callbacks).
  static AppServices read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}

/// Kurzer Zugriff in Widgets.
extension AppX on BuildContext {
  AppServices get app => AppScope.read(this);
  AppLocalizations get l => AppLocalizations.of(this);
}
