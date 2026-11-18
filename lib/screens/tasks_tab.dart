import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/overlays.dart';
import '../widgets/ui.dart';
import 'task_card.dart';
import 'ui_state.dart';

/// Tab „Aufgaben“: Filter-Chips, ⋮-Menü, Suche, Abschnitte und die feste Gewohnheiten-Aufgabe.
class TasksTab extends StatelessWidget {
  const TasksTab({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.store, app.sync]),
      builder: (context, _) => Column(
        children: [
          ui.search != null ? _SearchBar(ui: ui) : _ChipBar(ui: ui),
          Expanded(child: _TaskList(ui: ui)),
        ],
      ),
    );
  }
}

class _ChipBar extends StatelessWidget {
  const _ChipBar({required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    final tok = context.tok;
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: l.filterByCategory,
              child: SizedBox(
                height: Sizes.chipH + 4,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
                  children: [
                    AppChip(label: l.all, selected: ui.filter == 'alle', onTap: () => ui.set((s) => s.filter = 'alle')),
                    for (final c in store.categories) ...[
                      const SizedBox(width: 8),
                      AppChip(
                        label: c.name,
                        selected: ui.filter == c.id,
                        colors: tok.item(c.color),
                        onTap: () => ui.set((s) => s.filter = c.id),
                      ),
                    ],
                    const SizedBox(width: 8),
                    AppChip(
                      label: l.habits,
                      selected: ui.filter == 'habits',
                      colors: tok.item(habitColorHex),
                      onTap: () => ui.set((s) => s.filter = 'habits'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (btnContext) => IconBtn(
              Ic.more,
              label: l.moreOptions,
              onTap: () {
                final rect = anchorRect(btnContext);
                if (rect != null) _openMenuAt(context, rect);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _mainMenu(BuildContext context, BuildContext menuContext, Rect rect) {
    final l = context.l;
    final app = context.app;
    final items = <(String, String, Ic)>[
      ('search', l.search, Ic.search),
      ('sort', l.sort, Ic.sort),
      ('cats', l.manageCategories, Ic.tag),
      ('hideDone', ui.hideDone ? l.showCompleted : l.hideCompleted, Ic.hide),
      ('clearDone', l.deleteCompleted, Ic.sweep),
    ];
    // Häufig genutzte Einträge wandern nach oben.
    final order = [for (var i = 0; i < items.length; i++) i]
      ..sort((a, b) {
        final n = (app.settings.menuUse[items[b].$1] ?? 0) - (app.settings.menuUse[items[a].$1] ?? 0);
        return n != 0 ? n : a - b;
      });
    return [
      for (final i in order)
        MenuItemRow(
          entry: MenuEntry(
            label: items[i].$2,
            icon: items[i].$3,
            onTap: () {
              Navigator.pop(menuContext);
              _menuItem(context, items[i].$1, rect);
            },
          ),
        ),
    ];
  }

  void _menuItem(BuildContext context, String id, Rect rect) {
    final app = context.app;
    final l = context.l;
    app.settings.countMenu(id);
    switch (id) {
      case 'search':
        ui.set((s) => s.search = '');
      case 'sort':
        Navigator.of(context).push(
          AppMenuRoute(
            anchor: rect,
            label: l.sort,
            builder: (menuContext) => [
              MenuItemRow(
                entry: MenuEntry(
                  label: l.sort,
                  icon: Ic.back,
                  onTap: () {
                    Navigator.pop(menuContext);
                    _openMenuAt(context, rect);
                  },
                ),
              ),
              const MenuSep(),
              for (final o in [
                (SortMode.date, l.sortByDate),
                (SortMode.category, l.sortByCategory),
                (SortMode.name, l.sortByName),
              ])
                MenuItemRow(
                  entry: MenuEntry(
                    label: o.$2,
                    radio: true,
                    checked: ui.sort == o.$1,
                    onTap: () {
                      Navigator.pop(menuContext);
                      ui.set((s) => s.sort = o.$1);
                    },
                  ),
                ),
            ],
          ),
        );
      case 'cats':
        ui.set((s) {
          s.enterDir = 1;
          s.tab = AppTab.settings;
          s.cats = true;
        });
      case 'hideDone':
        ui.set((s) => s.hideDone = !s.hideDone);
        app.snack.show(ui.hideDone ? l.completedHidden : l.completedShown);
      case 'clearDone':
        final r = app.store.clearDone();
        if (r == null) {
          app.snack.show(l.noCompleted);
        } else {
          app.snack.show(l.completedDeleted(r.count), undo: r.undo);
        }
    }
  }

  void _openMenuAt(BuildContext context, Rect rect) {
    Navigator.of(context).push(
      AppMenuRoute(
        anchor: rect,
        label: context.l.moreOptions,
        builder: (menuContext) => _mainMenu(context, menuContext, rect),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.ui});
  final UiState ui;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final _ctrl = TextEditingController(text: widget.ui.search);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          IconBtn(Ic.back, label: l.closeSearch, onTap: () => widget.ui.set((s) => s.search = null)),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              label: l.searchTasks,
              child: AppInput(
                controller: _ctrl,
                hint: l.search,
                filled: true,
                height: 40,
                fontSize: 15,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => widget.ui.set((s) => s.search = v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    final l = context.l;
    int off(Task t) => store.catOf(t.categoryId).offset;
    final searching = ui.search != null && ui.search!.trim().isNotEmpty;
    final list = filterTasks(
      store.tasks,
      filter: ui.filter == 'habits' ? 'alle' : ui.filter,
      hideDone: ui.hideDone,
      search: ui.search,
    )..sort((a, b) => byDo(a, b, off));
    final showHabits = ui.search == null && (ui.filter == 'alle' || ui.filter == 'habits');
    final children = <Widget>[
      if (showHabits) ...[const SizedBox(height: 8), HabitsTaskCard(ui: ui)],
    ];
    TaskCard card(Task t) => TaskCard(key: ValueKey(t.id), task: t, ui: ui);

    if (ui.filter != 'habits') {
      if (list.isEmpty) {
        children.add(EmptyState(icon: searching ? Ic.search : Ic.tasks, text: searching ? l.nothingFound : l.noTasks));
      } else if (ui.search != null || ui.sort == SortMode.name) {
        if (ui.sort == SortMode.name) {
          list.sort((a, b) => doneLast(a, b) ?? a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        }
        children
          ..add(const SizedBox(height: 8))
          ..addAll(list.map(card));
      } else if (ui.sort == SortMode.category) {
        final tok = context.tok;
        for (final c in store.categories) {
          final items = list.where((t) => t.categoryId == c.id).toList()
            ..sort((a, b) => doneLast(a, b) ?? byDo(a, b, off));
          if (items.isEmpty) continue;
          final id = 'k-${c.id}';
          final open = !ui.collapsed.contains(id);
          children.add(
            SectionHead(
              label: c.name,
              count: items.length,
              open: open,
              color: tok.item(c.color).c,
              onTap: () => ui.toggleCollapsed(id),
            ),
          );
          if (open) children.addAll(items.map(card));
        }
      } else {
        final labels = {
          Section.overdue: l.overdue,
          Section.today: l.today,
          Section.tomorrow: l.tomorrow,
          Section.week: l.thisWeek,
          Section.later: l.later,
          Section.done: l.done,
        };
        final now = DateTime.now();
        for (final s in Section.values) {
          var items = list.where((t) => sectionOf(t, off(t), now: now) == s).toList();
          if (items.isEmpty) continue;
          if (s == Section.done) items = items.reversed.toList();
          final id = s.name;
          final open = !ui.collapsed.contains(id);
          children.add(
            SectionHead(
              label: labels[s]!,
              count: items.length,
              open: open,
              overdue: s == Section.overdue,
              onTap: () => ui.toggleCollapsed(id),
            ),
          );
          if (open) children.addAll(items.map(card));
        }
      }
    }
    return ListView(
      padding: EdgeInsets.only(bottom: Sizes.contentBottom + MediaQuery.paddingOf(context).bottom),
      children: children,
    );
  }
}
