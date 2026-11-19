import 'package:material_ui/material_ui.dart';

import '../../app_services.dart';
import '../../data/models.dart';
import '../../theme/color_math.dart';
import '../../theme/tokens.dart';
import '../../util/dates.dart';
import '../../util/fmt.dart';
import '../../widgets/pickers.dart';
import '../../widgets/pressable.dart';
import '../../widgets/ui.dart';

/// Öffnet die Seite „Aufgaben für diesen Tag“ und liefert die gewählten Aufgaben-IDs
/// (nach Datum sortiert) – oder `null`, wenn man ohne Übernehmen zurückgeht.
Future<List<String>?> pickTasks(
  BuildContext context, {
  required DateTime from,
  required Set<String> exclude,
  required List<String> initial,
}) => Navigator.of(context).push<List<String>>(
  PageRouteBuilder(
    transitionDuration: Motion.sheet,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => PickTasksPage(from: from, exclude: exclude, initial: initial),
    transitionsBuilder: (context, a, _, child) {
      if (Motion.reduced(context)) return child;
      final curved = CurvedAnimation(parent: a, curve: Motion.sheetUp, reverseCurve: Curves.easeIn);
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  ),
);

/// Alle offenen Aufgaben, die ab [from] fällig sind, nach Datum – mit Filter nach Kategorie.
/// Was man auswählt, kommt im Blatt „Neuer Block“ zu den Aufgaben an diesem Tag dazu.
/// An den Aufgaben selbst wird nichts gespeichert.
class PickTasksPage extends StatefulWidget {
  const PickTasksPage({super.key, required this.from, required this.exclude, required this.initial});

  /// Der Tag des Blocks (oder heute, falls der schon vorbei ist).
  final DateTime from;

  /// Aufgaben, die schon als Chip dastehen.
  final Set<String> exclude;

  /// Schon früher hier gewählte Aufgaben.
  final List<String> initial;

  @override
  State<PickTasksPage> createState() => _PickTasksPageState();
}

class _PickTasksPageState extends State<PickTasksPage> {
  late final Set<String> _picked = {...widget.initial};

  /// Gewählte Kategorie (ID) oder `null` = alle.
  String? _cat;

  List<Task> get _tasks {
    final from = sod(widget.from);
    return context.app.store.tasks
        .where((t) => !t.done && !widget.exclude.contains(t.id) && !sod(t.dueDate).isBefore(from))
        .toList()
      ..sort((a, b) => a.due.compareTo(b.due));
  }

  void _toggle(String id) => setState(() {
    if (!_picked.remove(id)) _picked.add(id);
  });

  void _apply() {
    final ids = [
      for (final t in _tasks)
        if (_picked.contains(t.id)) t.id,
    ];
    Navigator.pop(context, ids);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tok = context.tok;
    final f = Fmt.of(context);
    final store = context.app.store;
    final all = _tasks;
    final cats = [
      for (final c in store.categories)
        if (all.any((t) => t.categoryId == c.id)) c,
    ];
    final cat = cats.any((c) => c.id == _cat) ? _cat : null;
    final shown = cat == null ? all : all.where((t) => t.categoryId == cat).toList();
    final n = _picked.where((id) => all.any((t) => t.id == id)).length;
    return Material(
      color: tok.bg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopBar(title: l.pickTasksTitle, onBack: () => Navigator.pop(context), backLabel: l.back),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    l.pickTasksInfo,
                    style: TextStyle(fontSize: Fs.meta, color: tok.sub),
                  ),
                ),
                if (cats.length > 1)
                  QuickRow(
                    label: l.pickCategory,
                    children: [
                      AppChip(label: l.all, selected: cat == null, onTap: () => setState(() => _cat = null)),
                      for (final c in cats)
                        AppChip(
                          label: c.name,
                          selected: cat == c.id,
                          colors: tok.item(c.color),
                          onTap: () => setState(() => _cat = c.id),
                        ),
                    ],
                  ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l.pickTasksNone,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: tok.sub),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                          children: [
                            for (final t in shown)
                              _Row(
                                task: t,
                                picked: _picked.contains(t.id),
                                colors: tok.item(store.catOf(t.categoryId).color),
                                meta: '${f.dayTime(t.dueDate, t.dueTime)} · ${store.catOf(t.categoryId).name}',
                                onTap: () => _toggle(t.id),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Row(
                    children: [
                      const Spacer(),
                      AppButton(label: l.cancel, kind: BtnKind.text, onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 8),
                      AppButton(label: n > 0 ? l.applyCount(n) : l.apply, onTap: _apply),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.task, required this.picked, required this.colors, required this.meta, required this.onTap});
  final Task task;
  final bool picked;
  final ItemColors colors;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = context.tok;
    return Pressable(
      onTap: onTap,
      selected: picked,
      semanticLabel: '${task.title}, $meta',
      excludeChildSemantics: true,
      radius: BorderRadius.circular(Sizes.rCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            ExcludeSemantics(
              child: CheckMark(on: picked, colors: colors, label: task.title, onTap: onTap),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: tok.text),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: Fs.meta, color: tok.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
