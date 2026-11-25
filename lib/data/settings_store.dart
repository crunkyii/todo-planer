import 'dart:convert';
import 'dart:io' show File, FileSystemException, Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/dates.dart' as dates;
import '../util/task_logic.dart' show Section;
import 'models.dart';

/// Wo die Daten liegen: noch nicht gewählt, nur lokal oder in der eigenen Supabase-DB.
enum SyncMode { none, local, cloud }

/// Darstellung: hell, dunkel oder wie das System.
enum AppMode { light, dark, system }

/// Supabase-Zugang, der in der Einrichtung eingegeben wurde: Project URL und Publishable Key.
class CloudConfig {
  const CloudConfig(this.url, this.key);
  final String url;
  final String key;

  String get host => Uri.parse(url).host;
}

/// Einstellungen am Gerät (shared_preferences). Die Benutzer-Einstellungen
/// (Theme, Darstellung, Sprache, Raster, Tag beginnt/endet, Erinnerungen) werden
/// zusätzlich über die Tabelle `settings` synchronisiert.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  /// Erlaubte Werte – dieselben Grenzen prüft die Datenbank (`supabase/schema.sql`, Tabelle `settings`).
  static const rasterChoices = [5, 15, 30];
  static const dayStartMin = 4, dayStartMax = 10;
  static const dayEndMin = 16, dayEndMax = 24;

  /// Zwischen „Tag beginnt“ und „Tag endet“ liegen mindestens so viele Stunden.
  static const minDayHours = 6;

  /// Sprachen der App – dieselben erlaubt die Datenbank (`supabase/schema.sql`, Tabelle `settings`).
  static const languages = ['de', 'en', 'es', 'fr', 'it'];

  /// Sprache des Geräts, wenn die App sie kann – sonst Englisch.
  /// [code] = Sprache des Geräts (Standard: wie das System meldet).
  static String deviceLang([String? code]) =>
      _supported(code ?? PlatformDispatcher.instance.locale.languageCode) ?? 'en';

  static String? _supported(String? code) => languages.contains(code) ? code : null;

  /// Windows: Der Installer legt die dort gewählte Sprache neben das Programm
  /// (`tool/release/installer.iss`). Sie gilt beim ersten Start, bis etwas gespeichert ist.
  static String? installerLang() {
    if (kIsWeb || !Platform.isWindows) return null;
    try {
      final f = File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}install-language.txt');
      return f.existsSync() ? _supported(f.readAsStringSync().trim()) : null;
    } on FileSystemException {
      return null;
    }
  }

  static const _kSettings = 'settings.v1';
  static const _kSync = 'sync.v1';
  static const _kDevice = 'device.v1';

  String lang = 'de';
  String theme = 'himmel';
  AppMode mode = AppMode.light;
  int raster = 15;
  int dayStart = 6;
  int dayEnd = 22;
  bool remind = true;

  /// Zeitpunkt der letzten Änderung (für den Sync der Einstellungen).
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  bool dirty = false;

  SyncMode syncMode = SyncMode.none;
  CloudConfig? cloud;

  /// Zu wem die lokalen Daten gehören („host|userId“). `null` = lokale Daten ohne Konto.
  String? owner;

  /// Zeitstempel des letzten Downloads je Tabelle (Server-Zeit `synced_at`).
  Map<String, String> pullCursor = {};

  /// Spalten (`tabelle.spalte`), die dieser Server noch nicht kannte: Ihre Werte sind erst am Gerät.
  Set<String> unsent = {};

  // ---- Nur an diesem Gerät (nicht synchronisiert): [updateDevice] ----

  /// Mit welchem Wochentag die Woche beginnt (0 = Montag … 6 = Sonntag).
  int weekFirstDay = 0;

  /// Aufgaben am PC: wie viele Listen höchstens nebeneinander stehen.
  static const boardVisibleMin = 2, boardVisibleMax = 4;
  int boardVisible = 3;

  /// Aufgaben am PC: ausgeblendete Zeitraum-Listen (`Section.name`).
  Set<String> boardHidden = {};

  /// Aufgaben am PC: Kategorien (IDs), die zusätzlich eine eigene Liste bekommen.
  List<String> boardCats = [];

  /// Aufgaben am PC: Reihenfolge der Listen, wie man sie sich zurechtgezogen hat
  /// (`Section.name` bzw. `k-<Kategorie-ID>`). Leer = Zeiträume der Reihe nach, dann Kategorien.
  List<String> boardOrder = [];

  /// Windows: die heutigen Aufgaben für den Launcher Flick bereitstellen (`lib/services/flick_export.dart`).
  bool flick = false;

  /// Der Hinweis „… Aufgaben ausgeblendet – einstellbar bei der Kategorie“ kam schon einmal.
  bool hiddenHintSeen = false;

  /// Nur für diesen App-Start (nicht gespeichert): Beim ersten Mal bleibt der Hinweis stehen,
  /// bis man ihn schließt oder die App beendet – danach kommt er nicht wieder.
  bool hiddenHintNow = false;

  /// Merkt sich, dass der Hinweis jetzt zum ersten Mal dasteht.
  void markHiddenHintSeen() {
    if (hiddenHintSeen) return;
    hiddenHintNow = true;
    updateDevice((s) => s.hiddenHintSeen = true);
  }

  /// Schließt den Hinweis (er kam schon und kommt nicht wieder).
  void closeHiddenHint() {
    hiddenHintNow = false;
    if (hiddenHintSeen) {
      notifyListeners();
    } else {
      updateDevice((s) => s.hiddenHintSeen = true);
    }
  }

  /// Alle möglichen Listen in der eingestellten Reihenfolge; neue stehen hinten.
  List<String> boardColumnOrder() {
    final all = [for (final s in Section.values) s.name, for (final id in boardCats) 'k-$id'];
    return [...boardOrder.where(all.contains), ...all.where((id) => !boardOrder.contains(id))];
  }

  /// Übernimmt die Reihenfolge der gerade sichtbaren Listen [visible]. Ausgeblendete behalten
  /// ihren Platz zwischen ihnen.
  void reorderBoard(List<String> visible) {
    final order = boardColumnOrder();
    final slots = [
      for (var i = 0; i < order.length; i++)
        if (visible.contains(order[i])) i,
    ];
    final ids = visible.where(order.contains).toList();
    if (ids.length != slots.length) return;
    for (var k = 0; k < slots.length; k++) {
      order[slots[k]] = ids[k];
    }
    if (listEquals(order, boardColumnOrder())) return;
    updateDevice((s) => s.boardOrder = order);
  }

  /// Zieht die Liste [id] an den Platz von [target]; die dazwischen rücken auf.
  void moveBoardColumn(String id, String target) {
    final order = boardColumnOrder();
    final from = order.indexOf(id), to = order.indexOf(target);
    if (from < 0 || to < 0 || from == to) return;
    order
      ..removeAt(from)
      ..insert(to, id);
    updateDevice((s) => s.boardOrder = order);
  }

  void _load() {
    final s = _decode(_kSettings);
    lang = (s == null ? installerLang() : null) ?? deviceLang();
    if (s != null) _apply(s);
    final sync = _decode(_kSync);
    if (sync != null) {
      syncMode = SyncMode.values.asNameMap()[sync['mode']] ?? SyncMode.none;
      final url = sync['url'] as String?, key = sync['key'] as String?;
      if (url != null && key != null) cloud = CloudConfig(url, key);
      owner = sync['owner'] as String?;
      pullCursor = Map<String, String>.from((sync['cursor'] as Map?) ?? const {});
      unsent = {...?(sync['unsent'] as List?)?.whereType<String>()};
    }
    final d = _decode(_kDevice);
    if (d != null) {
      weekFirstDay = ((d['week_first'] as num?)?.toInt() ?? 0).clamp(0, 6);
      boardVisible = ((d['board_visible'] as num?)?.toInt() ?? 3).clamp(boardVisibleMin, boardVisibleMax);
      boardHidden = {...?(d['board_hidden'] as List?)?.whereType<String>()};
      boardCats = [...?(d['board_cats'] as List?)?.whereType<String>()];
      boardOrder = [...?(d['board_order'] as List?)?.whereType<String>()];
      flick = d['flick'] == true;
      hiddenHintSeen = d['hidden_hint_seen'] == true;
    }
    dates.weekFirstDay = weekFirstDay;
  }

  Map<String, Object?>? _decode(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } on FormatException {
      return null;
    }
  }

  void _apply(Map<String, Object?> s) {
    if (_supported(s['lang'] as String?) case final v?) lang = v;
    theme = (s['theme'] as String?) ?? theme;
    mode = AppMode.values.asNameMap()[s['mode']] ?? mode;
    raster = _clampRaster((s['raster'] as num?)?.toInt() ?? raster);
    dayStart = ((s['day_start'] as num?)?.toInt() ?? dayStart).clamp(dayStartMin, dayStartMax);
    dayEnd = ((s['day_end'] as num?)?.toInt() ?? dayEnd).clamp(dayEndMin, dayEndMax);
    remind = switch (s['remind']) {
      final bool b => b,
      1 => true,
      0 => false,
      _ => remind,
    };
    final u = s['updated_at'] as String?;
    if (u != null) updatedAt = DateTime.parse(u).toUtc();
    if (s['dirty'] is bool) dirty = s['dirty'] as bool;
  }

  static int _clampRaster(int r) => rasterChoices.contains(r) ? r : 15;

  /// Einstellungen als Zeile der Tabelle `settings`.
  Map<String, Object?> toRow() => {
    'lang': lang,
    'theme': theme,
    'mode': mode.name,
    'raster': raster,
    'day_start': dayStart,
    'day_end': dayEnd,
    'remind': remind,
    'updated_at': updatedAt.toIso8601String(),
  };

  Future<void> _saveSettings() => _prefs.setString(_kSettings, jsonEncode({...toRow(), 'dirty': dirty}));

  Future<void> _saveSync() => _prefs.setString(
    _kSync,
    jsonEncode({
      'mode': syncMode.name,
      'url': cloud?.url,
      'key': cloud?.key,
      'owner': owner,
      'cursor': pullCursor,
      'unsent': [...unsent],
    }),
  );

  /// Ändert Benutzer-Einstellungen und merkt sie für den Upload vor.
  void update(void Function(SettingsStore s) change) {
    change(this);
    raster = _clampRaster(raster);
    if (dayEnd - dayStart < minDayHours) dayEnd = (dayStart + minDayHours).clamp(dayEndMin, dayEndMax);
    updatedAt = nowUtc();
    dirty = true;
    _saveSettings();
    notifyListeners();
  }

  /// Übernimmt Einstellungen von Supabase, wenn sie neuer sind.
  bool mergeRemote(Map<String, Object?> row) {
    final remoteAt = DateTime.parse(row['updated_at'] as String).toUtc();
    if (!remoteAt.isAfter(updatedAt)) return false;
    _apply(row);
    dirty = false;
    _saveSettings();
    notifyListeners();
    return true;
  }

  void markSettingsClean(DateTime pushedAt) {
    if (updatedAt == pushedAt) {
      dirty = false;
      _saveSettings();
    }
  }

  Future<void> setLocalMode() async {
    syncMode = SyncMode.local;
    await _saveSync();
    notifyListeners();
  }

  Future<void> setCloud(CloudConfig c) async {
    syncMode = SyncMode.cloud;
    cloud = c;
    pullCursor = {};
    unsent = {};
    await _saveSync();
    notifyListeners();
  }

  Future<void> setOwner(String? o) async {
    owner = o;
    await _saveSync();
  }

  Future<void> setCursor(String table, String value) async {
    // Der Abgleich lädt die letzte Zeile jedes Mal wieder (`gte`) – dann nichts neu schreiben.
    if (pullCursor[table] == value) return;
    pullCursor[table] = value;
    await _saveSync();
  }

  Future<void> addUnsent(String column) async {
    if (unsent.add(column)) await _saveSync();
  }

  Future<void> removeUnsent(String column) async {
    if (unsent.remove(column)) await _saveSync();
  }

  Future<void> resetCursors() async {
    pullCursor = {};
    await _saveSync();
  }

  /// Ändert Einstellungen, die nur an diesem Gerät gelten (kein Upload).
  void updateDevice(void Function(SettingsStore s) change) {
    change(this);
    weekFirstDay = weekFirstDay.clamp(0, 6);
    dates.weekFirstDay = weekFirstDay;
    boardVisible = boardVisible.clamp(boardVisibleMin, boardVisibleMax);
    _prefs.setString(
      _kDevice,
      jsonEncode({
        'week_first': weekFirstDay,
        'board_visible': boardVisible,
        'board_hidden': boardHidden.toList(),
        'board_cats': boardCats,
        'board_order': boardOrder,
        'flick': flick,
        'hidden_hint_seen': hiddenHintSeen,
      }),
    );
    notifyListeners();
  }
}
