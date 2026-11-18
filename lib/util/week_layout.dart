import 'dart:math' as math;

import '../data/models.dart';

/// Ordnet überlappende Blöcke eines Tages nebeneinander an: `lane` sagt für jeden Block
/// (nach ID), in welcher Spur er steht, `lanes`, wie viele Spuren der Tag braucht.
/// [sorted] muss nach Beginn sortiert sein; ein Block nimmt die erste Spur, die schon frei ist.
({Map<String, int> lane, int lanes}) layoutLanes(List<WeekBlock> sorted) {
  final ends = <int>[];
  final lane = <String, int>{};
  for (final b in sorted) {
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
  }
  return (lane: lane, lanes: math.max(1, ends.length));
}
