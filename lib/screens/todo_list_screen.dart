import 'package:material_ui/material_ui.dart';

import '../models/todo.dart';
import '../services/auth_service.dart';
import '../services/error_messages.dart';
import '../services/todo_service.dart';

/// Die Todo-Liste des angemeldeten Users mit Live-Synchronisation.
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.authService,
    required this.todoService,
  });

  final String userId;
  final String email;
  final AuthService authService;
  final TodoService todoService;

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late Stream<List<Todo>> _todos;

  /// IDs, die per Wischen entfernt wurden, deren Löschung der Server aber noch
  /// nicht über Realtime bestätigt hat. Sie werden sofort ausgeblendet.
  final Set<String> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _todos = widget.todoService.watchTodos(widget.userId);
  }

  void _retry() => setState(_subscribe);

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _add() async {
    final title = await showTodoTitleDialog(context);
    if (title != null) await _run(() => widget.todoService.add(title));
  }

  Future<void> _edit(Todo todo) async {
    final title = await showTodoTitleDialog(context, initial: todo.title);
    if (title != null && title != todo.title) {
      await _run(() => widget.todoService.rename(todo.id, title));
    }
  }

  Future<void> _delete(Todo todo) async {
    setState(() => _pendingDeletes.add(todo.id));
    try {
      await widget.todoService.delete(todo.id);
    } catch (e) {
      if (mounted) setState(() => _pendingDeletes.remove(todo.id));
      _showError(e);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('„${todo.title}“ gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            setState(() => _pendingDeletes.remove(todo.id));
            await _run(() => widget.todoService.restore(todo));
          },
        ),
      ));
  }

  Future<void> _signOut() async {
    await _run(widget.authService.signOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Todos'),
        actions: [
          IconButton(
            tooltip: 'Abmelden (${widget.email})',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Neues Todo'),
      ),
      body: StreamBuilder<List<Todo>>(
        stream: _todos,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.cloud_off_outlined,
              text: friendlyErrorMessage(snapshot.error!),
              action: FilledButton.tonalIcon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final serverIds = snapshot.data!.map((t) => t.id).toSet();
          // Vom Server bestätigte Löschungen nicht mehr merken.
          _pendingDeletes.retainAll(serverIds);
          final todos = snapshot.data!
              .where((t) => !_pendingDeletes.contains(t.id))
              .toList();

          if (todos.isEmpty) {
            return const _CenteredMessage(
              icon: Icons.task_alt,
              text: 'Noch keine Todos.\nTippe auf „Neues Todo“, um loszulegen.',
            );
          }

          final openCount = todos.where((t) => !t.done).length;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: todos.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '$openCount von ${todos.length} offen',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                );
              }
              final todo = todos[index - 1];
              return _TodoTile(
                key: ValueKey(todo.id),
                todo: todo,
                onToggle: (done) =>
                    _run(() => widget.todoService.setDone(todo.id, done)),
                onEdit: () => _edit(todo),
                onDelete: () => _delete(todo),
              );
            },
          );
        },
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Todo todo;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${todo.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: colors.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      child: ListTile(
        leading: Checkbox(
          value: todo.done,
          onChanged: (value) => onToggle(value ?? false),
        ),
        title: Text(
          todo.title,
          style: todo.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: colors.onSurfaceVariant,
                )
              : null,
        ),
        trailing: IconButton(
          tooltip: 'Bearbeiten',
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
        onTap: () => onToggle(!todo.done),
        onLongPress: onEdit,
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Dialog zum Anlegen oder Bearbeiten eines Todo-Titels.
/// Gibt den neuen Titel zurück oder `null`, wenn abgebrochen wurde.
Future<String?> showTodoTitleDialog(BuildContext context, {String? initial}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TodoTitleDialog(initial: initial),
  );
}

class _TodoTitleDialog extends StatefulWidget {
  const _TodoTitleDialog({this.initial});

  final String? initial;

  @override
  State<_TodoTitleDialog> createState() => _TodoTitleDialogState();
}

class _TodoTitleDialogState extends State<_TodoTitleDialog> {
  static const _maxLength = 500;

  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(isEdit ? 'Todo bearbeiten' : 'Neues Todo'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: _maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Was ist zu tun?'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Bitte gib einen Text ein.'
              : null,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEdit ? 'Speichern' : 'Hinzufügen'),
        ),
      ],
    );
  }
}
