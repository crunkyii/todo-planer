import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/todo_service.dart';

const _seedColor = Colors.indigo;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!isConfigured) {
    runApp(const _ConfigMissingApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Nimmt sowohl den klassischen "anon" Key als auch den neuen
    // "publishable" Key (sb_publishable_…) an.
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final client = Supabase.instance.client;

  runApp(TodoApp(
    authService: AuthService(client.auth),
    todoService: TodoService(client),
  ));
}

/// `false`, solange lib/config.dart noch die Platzhalter der Vorlage enthält.
bool get isConfigured =>
    !AppConfig.supabaseUrl.contains('DEIN-PROJEKT') &&
    !AppConfig.supabaseAnonKey.contains('DEIN-ANON-KEY');

ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ),
  );
}

class TodoApp extends StatelessWidget {
  const TodoApp({
    super.key,
    required this.authService,
    required this.todoService,
  });

  final AuthService authService;
  final TodoService todoService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo-Liste',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: AuthGate(authService: authService, todoService: todoService),
    );
  }
}

class _ConfigMissingApp extends StatelessWidget {
  const _ConfigMissingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo-Liste',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Supabase ist noch nicht konfiguriert.\n\n'
              'Bitte trage in lib/config.dart deine Project URL und den '
              'anon key ein (siehe README) und baue die App neu.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
