import 'package:material_ui/material_ui.dart';

import 'app_services.dart';
import 'data/settings_store.dart';
import 'l10n/gen/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/shell.dart';
import 'theme/app_theme.dart';

/// Die App: Theme, Sprache und welcher Bildschirm gerade dran ist.
class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = services.settings;
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
          debugShowCheckedModeBanner: false,
          locale: Locale(s.lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          theme: buildAppTheme(s.theme, dark: false),
          darkTheme: buildAppTheme(s.theme, dark: true),
          themeMode: themeModeOf(s.mode),
          themeAnimationDuration: const Duration(milliseconds: 200),
          scrollBehavior: const AppScrollBehavior(),
          builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: maxTextScale, child: child!),
          home: const RootGate(),
        ),
      ),
    );
  }
}

/// Einrichtung → Anmeldung → App, je nach gespeichertem Zustand.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.settings]),
      builder: (context, _) {
        final s = app.settings;
        final Widget screen;
        if (s.syncMode == SyncMode.none || app.setupOpen) {
          screen = SetupScreen(key: ValueKey('setup-${app.setupOpen}'), startAtDb: app.setupOpen);
        } else if (s.syncMode == SyncMode.cloud && app.user == null) {
          screen = LoginScreen(key: ValueKey('login-${s.cloud?.url}'));
        } else {
          screen = const AppShell();
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: screen);
      },
    );
  }
}
