import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/todo.dart';

/// Zugriff auf die Tabelle `todos`. Row Level Security sorgt in der Datenbank
/// dafür, dass jeder nur seine eigenen Einträge sieht und ändert.
class TodoService {
  TodoService(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder get _todos => _client.from('todos');

  /// Live-Liste der eigenen Todos (Realtime), älteste zuerst.
  Stream<List<Todo>> watchTodos(String userId) {
    return _todos
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(Todo.fromMap).toList());
  }

  Future<void> add(String title) {
    return _todos.insert({'title': title.trim()});
  }

  /// Stellt ein gelöschtes Todo mit derselben ID und Position wieder her.
  Future<void> restore(Todo todo) {
    return _todos.insert({
      'id': todo.id,
      'title': todo.title,
      'done': todo.done,
      'created_at': todo.createdAt.toIso8601String(),
    });
  }

  Future<void> setDone(String id, bool done) {
    return _todos.update({'done': done}).eq('id', id);
  }

  Future<void> rename(String id, String title) {
    return _todos.update({'title': title.trim()}).eq('id', id);
  }

  Future<void> delete(String id) {
    return _todos.delete().eq('id', id);
  }
}
