import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Sagt den Tabs, ob die App gerade im breiten Layout läuft (Navigation links, wie am PC)
/// oder im schmalen (Navigation unten, wie am Handy).
class ShellLayout extends InheritedWidget {
  const ShellLayout({super.key, required this.wide, required super.child});
  final bool wide;

  static bool wideOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellLayout>()?.wide ?? false;

  /// Freier Platz am Ende einer Liste: schmal liegen Leiste und +-Knopf darüber ([narrow]),
  /// breit nichts.
  static double bottomOf(BuildContext context, {double narrow = Sizes.contentBottom}) =>
      (wideOf(context) ? Sizes.wideBottom : narrow) + MediaQuery.paddingOf(context).bottom;

  @override
  bool updateShouldNotify(ShellLayout old) => old.wide != wide;
}
