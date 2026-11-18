import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Baut das Material-Theme aus den Prototyp-Tokens. Die Widgets lesen ihre
/// Farben über `context.tok`, Material-Bausteine (Textfelder, Dialoge) über das ColorScheme.
ThemeData buildAppTheme(String themeId, {required bool dark}) {
  final t = AppTokens.build(themeOf(themeId), dark: dark);
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: t.p,
    onPrimary: t.onP,
    primaryContainer: t.pc,
    onPrimaryContainer: t.onPc,
    secondary: t.p,
    onSecondary: t.onP,
    error: t.err,
    onError: t.dark ? t.onErrC : const Color(0xFFFFFFFF),
    errorContainer: t.errC,
    onErrorContainer: t.onErrC,
    surface: t.surf,
    onSurface: t.text,
    onSurfaceVariant: t.sub,
    surfaceContainerHighest: t.surf2,
    outline: t.line,
    outlineVariant: t.lineSoft,
    inverseSurface: t.inv,
    onInverseSurface: t.onInv,
    inversePrimary: t.invP,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.p,
      selectionColor: t.p.withValues(alpha: 0.3),
      selectionHandleColor: t.p,
    ),
    textTheme: Typography.material2021().black.apply(bodyColor: t.text, displayColor: t.text),
    extensions: [t],
  );
}
