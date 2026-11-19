import 'dart:convert';

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

  // ---- Nur an diesem Gerät (nicht synchronisiert): [updateDevice] ----

  /// Mit welchem Wochentag die Woche beginnt (0 = Montag … 6 = Sonntag).
  int weekFirstDay = 0;

  /// Aufgaben am PC: wie viele Listen höchstens nebeneinander stehen.
  static const boardVisibleMin = 2, boardVisibleMax = 5;
  int boardVisible = 3;

  /// Aufgaben am PC: ausgeblendete Zeitraum-Listen (`Section.name`).
  Set<String> boardHidden = {};

  /// Aufgaben am PC: Kategorien (IDs), die zusätzlich eine eigene Liste bekommen.
  List<String> boardCats = [];

  /// Aufgaben am PC: Reihenfolge der Listen, wie man sie sich zurechtgezogen hat
  /// (`Section.name` bzw. `k-<Kategorie-ID>`). Leer = Zeiträume der Reihe nach, dann Kategorien.
  List<String> boardOrder = [];

  /// Alle möglichen Listen in der eingestellten Reihenfolge; neue stehen hinten.
  List<String> boardColumnOrder() {
    final all = [for (final s in Section.values) s.name, for (final id in boardCats) 'k-$id'];
    return [...boardOrder.where(all.contains), ...all.where((id) => !boardOrder.contains(id))];
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
    final sys = PlatformDispatcher.instance.locale.languageCode;
    lang = sys == 'de' ? 'de' : 'en';
    final s = _decode(_kSettings);
    if (s != null) _apply(s);
    final sync = _decode(_kSync);
    if (sync != null) {
      syncMode = SyncMode.values.asNameMap()[sync['mode']] ?? SyncMode.none;
      final url = sync['url'] as String?, key = sync['key'] as String?;
      if (url != null && key != null) cloud = CloudConfig(url, key);
      owner = sync['owner'] as String?;
      pullCursor = Map<String, String>.from((sync['cursor'] as Map?) ?? const {});
    }
    final d = _decode(_kDevice);
    if (d != null) {
      weekFirstDay = ((d['week_first'] as num?)?.toInt() ?? 0).clamp(0, 6);
      boardVisible = ((d['board_visible'] as num?)?.toInt() ?? 3).clamp(boardVisibleMin, boardVisibleMax);
      boardHidden = {...?(d['board_hidden'] as List?)?.whereType<String>()};
      boardCats = [...?(d['board_cats'] as List?)?.whereType<String>()];
      boardOrder = [...?(d['board_order'] as List?)?.whereType<String>()];
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
    if (s['lang'] case final String v when v == 'de' || v == 'en') lang = v;
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
    jsonEncode({'mode': syncMode.name, 'url': cloud?.url, 'key': cloud?.key, 'owner': owner, 'cursor': pullCursor}),
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
    await _saveSync();
    notifyListeners();
  }

  Future<void> setOwner(String? o) async {
    owner = o;
    await _saveSync();
  }

  Future<void> setCursor(String table, String value) async {
    pullCursor[table] = value;
    await _saveSync();
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
      }),
    );
    notifyListeners();
  }
}
