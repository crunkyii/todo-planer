/// Ein Eintrag der Todo-Liste, so wie er in der Tabelle `todos` liegt.
class Todo {
  const Todo({
    required this.id,
    required this.userId,
    required this.title,
    required this.done,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final bool done;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      done: map['done'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
