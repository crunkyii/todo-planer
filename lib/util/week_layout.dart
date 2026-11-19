import 'dart:math' as math;

import '../data/models.dart';

/// Ordnet überlappende Blöcke eines Tages nebeneinander an: `lane` sagt für jeden Block
/// (nach ID), in welcher Spur er steht, `lanes`, in wie viele Spuren sich seine Gruppe teilt.
/// Eine Gruppe sind Blöcke, die sich (auch über Dritte) überlappen – ein Block ohne Überschneidung
/// behält die ganze Breite, auch wenn es später am Tag eng wird.
/// [sorted] muss nach Beginn sortiert sein; ein Block nimmt die erste Spur, die schon frei ist.
({Map<String, int> lane, Map<String, int> lanes}) layoutLanes(List<WeekBlock> sorted) {
  final lane = <String, int>{};
  final lanes = <String, int>{};
  var ends = <int>[];
  var group = <String>[];
  var groupEnd = 0;

  void closeGroup() {
    for (final id in group) {
      lanes[id] = ends.length;
    }
    ends = [];
    group = [];
  }

  for (final b in sorted) {
    if (group.isNotEmpty && b.start >= groupEnd) closeGroup();
    var i = 0;
    while (i < ends.length && ends[i] > b.start) {
      i++;
    }
    if (i == ends.length) {
      ends.add(b.end);
    } else {
      ends[i] = b.end;
    }
    lane[b.id] = i;
    group.add(b.id);
    if (b.end > groupEnd) groupEnd = b.end;
  }
  closeGroup();
  return (lane: lane, lanes: lanes);
}

/// Neuer Beginn von [b] beim Ziehen um [minutes] Minuten (nach oben negativ): in ganzen
/// Schritten des Rasters [raster], auf das Raster gelegt, die Dauer bleibt. Der Block bleibt im
/// sichtbaren Tag ([dayStart]–[dayEnd] Uhr) – außer er stand schon vorher darüber hinaus.
int dragTarget(WeekBlock b, double minutes, int raster, int dayStart, int dayEnd) {
  final steps = (minutes / raster).round();
  if (steps == 0) return b.start;
  final dur = b.end - b.start;
  final lo = math.min(b.start, dayStart * 60), hi = math.max(b.end, dayEnd * 60) - dur;
  return (((b.start + steps * raster) / raster).round() * raster).clamp(lo, hi);
}
