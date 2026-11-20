import 'package:flutter/foundation.dart';

/// Hört auf [source], weckt die eigenen Zuhörer aber nur, wenn sich [select] dabei geändert
/// hat (Vergleich mit `==`, also gut mit Records). So baut z. B. ein Abgleich, der nur
/// „synchronisiere gerade“ an- und ausschaltet, nicht die ganze Aufgabenliste neu.
///
/// Hat außer den angemeldeten Zuhörern keinen Zustand – braucht also kein `dispose` und darf
/// in jedem `build` neu entstehen (wie `Listenable.merge`).
class Selected<T> implements Listenable {
  Selected(this.source, this.select);

  final Listenable source;
  final T Function() select;

  /// Je angemeldetem Zuhörer der Haken, der an [source] hängt.
  final _hooks = <(VoidCallback, VoidCallback)>[];

  @override
  void addListener(VoidCallback listener) {
    var last = select();
    void hook() {
      final now = select();
      if (now == last) return;
      last = now;
      listener();
    }

    _hooks.add((listener, hook));
    source.addListener(hook);
  }

  @override
  void removeListener(VoidCallback listener) {
    final i = _hooks.indexWhere((h) => h.$1 == listener);
    if (i < 0) return;
    source.removeListener(_hooks.removeAt(i).$2);
  }
}
