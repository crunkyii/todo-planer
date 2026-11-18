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
