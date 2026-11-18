import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/cloud.dart';
import 'data/settings_store.dart';
import 'data/store.dart';
import 'data/sync_service.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/reminders.dart';
import 'util/dates.dart';
import 'util/fmt.dart';
import 'widgets/snack.dart';

/// Alle Dienste der App an einem Ort; über [AppScope] im Widget-Baum erreichbar.
class AppServices extends ChangeNotifier {
  AppServices({
    required this.settings,
    required this.store,
    required this.cloud,
    required this.sync,
    required this.reminders,
  }) {
    store.onLocalChange = _onLocalChange;
    store.addListener(_scheduleReminders);
    settings.addListener(_onSettingsChanged);
    sync.onPulled = _afterPull;
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _scheduleMidnight();
  }

  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  /// Zurück in der App: Neues vom Server holen und „heute“ neu berechnen.
  void _onResume() {
    if (signedIn) sync.schedule(pullOnly: true);
    _dayChanged();
  }

  /// Um Mitternacht neu zeichnen, damit „Heute“, „Morgen“ und Gewohnheiten stimmen.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = clock();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    _midnight = Timer(next.difference(now), () {
      _dayChanged();
      _scheduleMidnight();
    });
  }

  DateTime _shownDay = today();
  void _dayChanged() {
    final d = today();
    if (d == _shownDay) return;
    _shownDay = d;
    store.touch();
  }

  final SettingsStore settings;
  final Store store;
  final Cloud cloud;
  final SyncService sync;
  final Reminders reminders;
  final snack = SnackController();

  /// `true` = Einrichtung „Datenbank verbinden“ wurde aus Login/Optionen geöffnet.
  bool setupOpen = false;

  /// Nach der Registrierung direkt im „Konto erstellen“-Modus starten.
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
        await store.db.markAllDirty();
        await store.refreshPending();
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
      (name: l.catHomework, color: '#3D9BE9', offset: 1),
      (name: l.catTask, color: '#34C38F', offset: 0),
      (name: l.catTest, color: '#F07A5F', offset: 2),
      (name: l.catAppointment, color: '#8E7CF0', offset: 0),
    ]);
  }

  /// Wird vom App-Bildschirm mit den aktuellen Texten aufgerufen.
  void enterApp(AppLocalizations l) {
    final changed = _l?.localeName != l.localeName;
    _l = l;
    reminders.setTexts(channelName: l.notifChannelName, channelDesc: l.notifChannelDesc);
    if (settings.syncMode == SyncMode.local || (signedIn && _firstSyncDone)) _ensureDefaults();
    if (changed) _scheduleReminders();
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
  Future<void> connectCloud(CloudConfig c) async {
    await sync.detach();
    await settings.setCloud(c);
    setupOpen = false;
    registerNext = true;
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
    await sync.idle();
    await sync.sync();
    await sync.idle();
    await sync.detach();
    await cloud.signOut();
    await _authChanged();
  }

  void _onLocalChange() {
    if (signedIn) sync.schedule();
  }

  void _onSettingsChanged() {
    if (settings.dirty && signedIn) sync.schedule();
    _scheduleReminders();
  }

  void _scheduleReminders() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(milliseconds: 800), () {
      final l = _l;
      if (l == null) return;
      final f = Fmt(l, l.localeName);
      final items = upcomingReminders(
        store.tasks,
        (t) => l.dayWithTime(store.catOf(t.categoryId).name, f.time(t.dueTime!)),
      );
      // Nur neu planen, wenn sich an den Erinnerungen wirklich etwas geändert hat
      // (der Store meldet auch Gewohnheiten, Sync-Status usw.).
      final sig =
          '${settings.remind}|${items.map((r) => '${r.id}@${r.at.millisecondsSinceEpoch}:${r.title}:${r.body}').join(',')}';
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
    _midnight?.cancel();
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
