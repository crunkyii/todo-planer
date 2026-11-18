import 'dart:convert';

import 'local_db.dart';

/// Feldweises Zusammenführen: Zwei Geräte haben dieselbe Zeile geändert.
///
/// Jede Zeile merkt sich in der Spalte `field_times` je Feld-Gruppe (siehe [TableSpec.groups]),
/// wann sie zuletzt geändert wurde. Beim Abgleich gewinnt je Gruppe der neuere Wert – so
/// bleiben der neue Titel vom Handy und das neue Datum vom PC beide erhalten.
///
/// Dieselbe Regel steht im Trigger `sync_guard` in `supabase/schema.sql` – beide Stellen
/// gemeinsam ändern (`test/fake_supabase.dart` bildet den Trigger für die Tests nach).

/// Name der Spalte mit den Zeitstempeln je Feld-Gruppe.
const fieldTimesColumn = 'field_times';

DateTime _time(Object? v) => DateTime.parse(v as String).toUtc();

/// Die Zeitstempel je Gruppe einer Zeile – oder `null`, wenn sie keine brauchbaren hat. Dann
/// gilt für diese Zeile wie früher: Die ganze Zeile mit dem neueren `updated_at` gewinnt.
///
/// Brauchbar heißt: Der jüngste Zeitstempel ist genau `updated_at`. Eine alte App-Version
/// kennt die Spalte nicht und ändert nur `updated_at` – daran erkennt man, dass die
/// Zeitstempel nicht mehr zu den Werten passen. (In der lokalen Datenbank steht die Spalte
/// als JSON-Text, vom Server kommt sie als Map.)
Map<String, DateTime>? validFieldTimes(Map<String, Object?> row) {
  try {
    final raw = decodeFieldTimes(row[fieldTimesColumn]);
    if (raw is! Map || raw.isEmpty) return null;
    final times = {for (final e in raw.entries) e.key as String: _time(e.value)};
    final latest = times.values.reduce((a, b) => a.isAfter(b) ? a : b);
    return latest.isAtSameMomentAs(_time(row['updated_at'])) ? times : null;
  } on Object {
    return null; // unlesbar: wie eine Zeile ohne Zeitstempel behandeln
  }
}

/// Der Inhalt der Spalte als JSON-Wert: lokal steht er als Text, vom Server kommt er fertig.
Object? decodeFieldTimes(Object? value) => value is String ? jsonDecode(value) : value;

/// Zeitstempel in der Form, in der sie gespeichert und hochgeladen werden.
Map<String, String> encodeFieldTimes(Map<String, DateTime> times) => {
  for (final e in times.entries) e.key: e.value.toUtc().toIso8601String(),
};

/// Führt die Server-Zeile [remote] in die lokale Zeile [local] ein.
///
/// [remote] muss dieselbe Schreibweise der Werte haben wie [local] (über das Modell gelesen).
/// Gibt `null` zurück, wenn [remote] nichts Neues bringt. Sonst die zusammengeführte Zeile
/// und ob sie etwas enthält, das der Server noch nicht hat ([ahead]) – dann muss sie (wieder)
/// hochgeladen werden.
({Map<String, Object?> row, bool ahead})? mergeRemote(
  TableSpec t,
  Map<String, Object?> local,
  Map<String, Object?> remote,
) {
  final localAt = _time(local['updated_at']), remoteAt = _time(remote['updated_at']);
  final localTimes = validFieldTimes(local), remoteTimes = validFieldTimes(remote);
  if (t.groups.isEmpty || localTimes == null || remoteTimes == null) {
    // Wie früher: ganze Zeile, der neuere Stand gewinnt.
    if (!remoteAt.isAfter(localAt)) return null;
    final row = {for (final k in t.columns.keys) k: remote[k]};
    if (t.groups.isNotEmpty) row[fieldTimesColumn] = remoteTimes == null ? null : encodeFieldTimes(remoteTimes);
    return (row: row, ahead: false);
  }
  final row = {for (final k in t.columns.keys) k: local[k]};
  final times = <String, DateTime>{};
  var won = false, ahead = false;
  for (final MapEntry(key: group, value: columns) in t.groups.entries) {
    final l = localTimes[group] ?? localAt, r = remoteTimes[group] ?? remoteAt;
    // Bei exakt gleichem Zeitstempel und verschiedenem Wert gilt der Stand am Server (der
    // zuerst dort war) – sonst behielte jedes Gerät für immer seinen eigenen Wert.
    final tie = l.isAtSameMomentAs(r) && columns.any((c) => local[c] != remote[c]);
    if (r.isAfter(l) || tie) {
      won = true;
      for (final c in columns) {
        row[c] = remote[c];
      }
    } else if (l.isAfter(r)) {
      ahead = true;
    }
    times[group] = r.isAfter(l) ? r : l;
  }
  if (!won) return null;
  row['updated_at'] = (remoteAt.isAfter(localAt) ? remoteAt : localAt).toIso8601String();
  row[fieldTimesColumn] = encodeFieldTimes(times);
  return (row: row, ahead: ahead);
}

/// Stempelt eine lokal geänderte Zeile: Gruppen, deren Werte sich gegenüber [previous]
/// geändert haben, bekommen [now]; die übrigen behalten ihren Zeitstempel. Hat sich gar
/// nichts geändert, bleibt auch `updated_at`, wie es war – es ist immer der jüngste
/// Zeitstempel. Gibt das (neue) `updated_at` zurück.
///
/// Geht die Uhr des Geräts nach, bekommt die Änderung trotzdem einen Zeitstempel knapp nach
/// dem bisherigen Stand der Zeile – sonst verlöre sie gegen den Wert, den sie gerade ersetzt.
DateTime stampLocalChange(TableSpec t, Map<String, Object?> row, Map<String, Object?>? previous, DateTime now) {
  if (t.groups.isEmpty) return now;
  if (previous == null) {
    row[fieldTimesColumn] = encodeFieldTimes({for (final g in t.groups.keys) g: now});
    return now;
  }
  final before = _time(previous['updated_at']);
  final stamp = now.isAfter(before) ? now : before.add(const Duration(microseconds: 1));
  final old = validFieldTimes(previous);
  final times = <String, DateTime>{};
  var changed = false;
  for (final MapEntry(key: group, value: columns) in t.groups.entries) {
    final differs = columns.any((c) => previous[c] != row[c]);
    changed = changed || differs;
    times[group] = differs ? stamp : (old?[group] ?? before);
  }
  final at = changed ? stamp : before;
  row['updated_at'] = at.toIso8601String();
  row[fieldTimesColumn] = encodeFieldTimes(times);
  return at;
}
