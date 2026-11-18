import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_liste/models/todo.dart';
import 'package:todo_liste/screens/login_screen.dart';
import 'package:todo_liste/screens/todo_list_screen.dart';
import 'package:todo_liste/services/auth_service.dart';
import 'package:todo_liste/services/error_messages.dart';

class _FakeAuthService implements AuthService {
  Object? signInError;
  bool signUpSignsIn = false;
  String? lastEmail;

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    lastEmail = email;
    return signUpSignsIn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('Todo.fromMap', () {
    test('liest alle Felder', () {
      final todo = Todo.fromMap({
        'id': 'a1',
        'user_id': 'u1',
        'title': 'Milch kaufen',
        'done': true,
        'created_at': '2026-11-18T10:00:00Z',
        'updated_at': '2026-11-18T11:00:00Z',
      });
      expect(todo.id, 'a1');
      expect(todo.userId, 'u1');
      expect(todo.title, 'Milch kaufen');
      expect(todo.done, isTrue);
      expect(todo.createdAt, DateTime.utc(2026, 11, 18, 10));
    });

    test('done fehlt -> false', () {
      final todo = Todo.fromMap({
        'id': 'a1',
        'user_id': 'u1',
        'title': 'x',
        'done': null,
        'created_at': '2026-11-18T10:00:00Z',
        'updated_at': '2026-11-18T10:00:00Z',
      });
      expect(todo.done, isFalse);
    });
  });

  group('friendlyErrorMessage', () {
    test('kein Internet', () {
      expect(friendlyErrorMessage(const SocketException('Failed host lookup')),
          contains('Internetverbindung'));
      expect(friendlyErrorMessage(AuthRetryableFetchException()),
          contains('Internetverbindung'));
    });

    test('falsches Passwort', () {
      expect(
        friendlyErrorMessage(const AuthException('Invalid login credentials',
            statusCode: '400', code: 'invalid_credentials')),
        'E-Mail oder Passwort ist falsch.',
      );
    });

    test('Konto existiert bereits', () {
      expect(
        friendlyErrorMessage(
            const AuthException('exists', code: 'user_already_exists')),
        contains('bereits ein Konto'),
      );
    });

    test('unbekannter Fehler', () {
      expect(friendlyErrorMessage(StateError('x')), contains('Unerwarteter Fehler'));
    });
  });

  group('LoginScreen', () {
    testWidgets('validiert leere Eingaben', (tester) async {
      final auth = _FakeAuthService();
      await tester.pumpWidget(_wrap(LoginScreen(authService: auth)));

      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pump();

      expect(find.text('Bitte gib deine E-Mail-Adresse ein.'), findsOneWidget);
      expect(find.text('Bitte gib ein Passwort ein.'), findsOneWidget);
      expect(auth.lastEmail, isNull);
    });

    testWidgets('zeigt verständliche Meldung bei falschem Passwort',
        (tester) async {
      final auth = _FakeAuthService()
        ..signInError = const AuthException('Invalid login credentials',
            statusCode: '400', code: 'invalid_credentials');
      await tester.pumpWidget(_wrap(LoginScreen(authService: auth)));

      await tester.enterText(find.byType(TextFormField).at(0), ' max@example.at ');
      await tester.enterText(find.byType(TextFormField).at(1), 'geheim123');
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pumpAndSettle();

      expect(find.text('E-Mail oder Passwort ist falsch.'), findsOneWidget);
    });

    testWidgets('Registrierung verlangt mind. 6 Zeichen und zeigt Bestätigungshinweis',
        (tester) async {
      final auth = _FakeAuthService();
      await tester.pumpWidget(_wrap(LoginScreen(authService: auth)));

      await tester.tap(find.text('Noch kein Konto? Registrieren'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(0), 'max@example.at');
      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrieren'));
      await tester.pump();
      expect(find.text('Mindestens 6 Zeichen.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrieren'));
      await tester.pumpAndSettle();
      expect(find.textContaining('bestätige deine E-Mail-Adresse'), findsOneWidget);
    });
  });

  group('Todo-Dialog', () {
    String? result;

    Future<void> openDialog(WidgetTester tester, {String? initial}) async {
      result = null;
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showTodoTitleDialog(context, initial: initial),
          child: const Text('öffnen'),
        ),
      )));
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
    }

    testWidgets('leerer Titel wird abgelehnt, Text wird getrimmt',
        (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Hinzufügen'));
      await tester.pump();
      expect(find.text('Bitte gib einen Text ein.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '  Brot  ');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(result, 'Brot');
    });

    testWidgets('Bearbeiten zeigt alten Titel', (tester) async {
      await openDialog(tester, initial: 'Alt');
      expect(find.text('Todo bearbeiten'), findsOneWidget);
      expect(find.text('Alt'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });
  });
}
