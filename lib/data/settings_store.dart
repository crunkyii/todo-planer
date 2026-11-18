import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Wo die Daten liegen: noch nicht gewählt, nur lokal oder in der eigenen Supabase-DB.
enum SyncMode { none, local, cloud }

/// Darstellung: hell, dunkel oder wie das System.
enum AppMode { light, dark, system }

/// Supabase-Zugang, der in der Einrichtung eingegeben wurde (ersetzt `lib/config.dart`).
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

  static const _kSettings = 'settings.v1';
  static const _kSync = 'sync.v1';
  static const _kMenu = 'menu_use.v1';

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

  /// Wie oft welcher Eintrag im ⋮-Menü benutzt wurde (häufig = weiter oben).
  Map<String, int> menuUse = {};

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
    final m = _decode(_kMenu);
    if (m != null) menuUse = m.map((k, v) => MapEntry(k, (v as num).toInt()));
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
    lang = s['lang'] == 'en' ? 'en' : (s['lang'] == 'de' ? 'de' : lang);
    theme = (s['theme'] as String?) ?? theme;
    mode = AppMode.values.asNameMap()[s['mode']] ?? mode;
    raster = _clampRaster((s['raster'] as num?)?.toInt() ?? raster);
    dayStart = ((s['day_start'] as num?)?.toInt() ?? dayStart).clamp(4, 10);
    dayEnd = ((s['day_end'] as num?)?.toInt() ?? dayEnd).clamp(16, 24);
    remind = s['remind'] is bool
        ? s['remind'] as bool
        : (s['remind'] == 1 ? true : (s['remind'] == 0 ? false : remind));
    final u = s['updated_at'] as String?;
    if (u != null) updatedAt = DateTime.parse(u).toUtc();
    if (s['dirty'] is bool) dirty = s['dirty'] as bool;
  }

  static int _clampRaster(int r) => const [5, 15, 30].contains(r) ? r : 15;

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
    // Mindestens 6 Stunden zwischen „Tag beginnt“ und „Tag endet“ (wie im Prototyp)
    if (dayEnd - dayStart < 6) dayEnd = (dayStart + 6).clamp(16, 24);
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

  void countMenu(String id) {
    menuUse[id] = (menuUse[id] ?? 0) + 1;
    _prefs.setString(_kMenu, jsonEncode(menuUse));
  }
}
