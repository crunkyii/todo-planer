/// Reihenfolge, wie sie während des Ziehens aussieht. Erst beim Loslassen wird sie gespeichert –
/// so baut nicht jeder Platzwechsel die ganze App neu auf, und das Ziehen bleibt flüssig.
class DragOrder {
  List<String>? _ids;

  /// Läuft gerade ein Ziehen, das schon etwas verschoben hat?
  bool get active => _ids != null;

  /// [items] in der Vorschau-Reihenfolge (ohne Ziehen unverändert).
  List<T> apply<T>(List<T> items, String Function(T) id) {
    final ids = _ids;
    if (ids == null || ids.length != items.length || !items.every((x) => ids.contains(id(x)))) return items;
    return [...items]..sort((a, b) => ids.indexOf(id(a)) - ids.indexOf(id(b)));
  }

  /// [dragged] steht über [target]: Sie tauscht in der Vorschau an dessen Platz.
  /// `false`, wenn sich nichts ändert.
  bool move(List<String> current, String dragged, String target) {
    final ids = [...current];
    final from = ids.indexOf(dragged), to = ids.indexOf(target);
    if (from < 0 || to < 0 || from == to) return false;
    ids
      ..removeAt(from)
      ..insert(to, dragged);
    _ids = ids;
    return true;
  }

  /// Ziehen vorbei: die Vorschau (oder `null`, wenn nichts verschoben wurde).
  List<String>? finish() {
    final ids = _ids;
    _ids = null;
    return ids;
  }
}
