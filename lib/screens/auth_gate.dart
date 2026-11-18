import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/todo_service.dart';
import 'login_screen.dart';
import 'todo_list_screen.dart';

/// Zeigt je nach Anmeldestatus den Login oder die Todo-Liste.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.todoService,
  });

  final AuthService authService;
  final TodoService todoService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? authService.currentSession;
        if (session == null) {
          return LoginScreen(authService: authService);
        }
        return TodoListScreen(
          key: ValueKey(session.user.id),
          userId: session.user.id,
          email: session.user.email ?? '',
          authService: authService,
          todoService: todoService,
        );
      },
    );
  }
}
