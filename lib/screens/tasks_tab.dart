import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';
import '../util/selected.dart';
import '../util/task_logic.dart';
import '../widgets/app_icon.dart';
import '../widgets/overlays.dart';
import '../widgets/layout.dart';
import '../widgets/ui.dart';
import 'older_done.dart';
import 'sheets.dart';
import 'task_card.dart';
import 'movable_section.dart';
import 'tasks_board.dart';
import 'ui_state.dart';

/// Tab „Aufgaben“: Filter-Chips, ⋮-Menü, Suche, Abschnitte und die feste Gewohnheiten-Aufgabe.
class TasksTab extends StatelessWidget {
  const TasksTab({super.key, required this.ui});
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final store = app.store, sync = app.sync;
    return ListenableBuilder(
      listenable: Listenable.merge([
        // Die Zahl der wartenden Zeilen zeigen nur die Optionen – hier zählen Daten und Wolken-Symbole.
        Selected(store, () => (store.revision, store.pendingTaskIds.length)),
        // Vom Abgleich nur, was die Liste zeigt: online (Wolken, „Ältere laden“) und das Nachladen.
        Selected(sync, () => (sync.online, sync.canLoadOlder, sync.loadingOlder)),
        app.settings,
        ui.sectionDragTick,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          // Am PC mit genug Platz: Listen nebeneinander und rechts die Seitenleiste.
          final board = ShellLayout.wideOf(context) && box.maxWidth >= Sizes.boardMin;
          final main = Column(
            children: [
              ui.search != null ? _SearchBar(ui: ui) : _ChipBar(ui: ui, board: board),
              Expanded(
                child: _TaskList(ui: ui, board: board),
              ),
            ],
          );
          if (!board) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.wideList),
                child: main,
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: main),
              SizedBox(
                width: Sizes.boardSide,
                child: TasksSide(ui: ui),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Der Filter, der gerade gilt. Am PC stehen die Gewohnheiten immer in der Seitenleiste –
/// der Chip dafür entfällt dort, ein gemerktes „nur Gewohnheiten“ zählt als „Alle“.
String _filterOf(UiState ui, Iterable<TaskCategory> categories, {required bool board}) {
  final f = ui.filterIn(categories);
  return board && f == filterHabits ? filterAll : f;
}

class _ChipBar extends StatelessWidget {
  const _ChipBar({required this.ui, required this.board});
  final UiState ui;
  final bool board;

  @override
  Widget build(BuildContext context) {
    const fadeLeft = 16.0, fadeRight = 32.0;
    final categories = context.app.store.categories;
    final filter = _filterOf(ui, categories, board: board);
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
                // Chips laufen an beiden Rändern weich aus, statt hart abgeschnitten zu werden.
                // Der Innenabstand ist so groß wie der Verlauf: am Anfang und am Ende der
                // Liste ist der erste bzw. letzte Chip ganz zu sehen.
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => LinearGradient(
                    colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                    stops: [0, fadeLeft / r.width, 1 - fadeRight / r.width, 1],
                  ).createShader(r),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(fadeLeft, 2, fadeRight, 2),
                    children: [
                      AppChip(
                        label: l.all,
                        selected: filter == filterAll,
                        onTap: () => ui.set((s) => s.filter = filterAll),
                      ),
                      for (final c in categories) ...[
                        const SizedBox(width: 8),
                        AppChip(
                          label: c.name,
                          selected: filter == c.id,
                          colors: tok.item(c.color),
                          onTap: () => ui.set((s) => s.filter = c.id),
                        ),
                      ],
                      if (!board) ...[
                        const SizedBox(width: 8),
                        AppChip(
                          label: l.habits,
                          selected: filter == filterHabits,
                          colors: tok.item(habitColorHex),
                          onTap: () => ui.set((s) => s.filter = filterHabits),
                        ),
                      ],
                    ],
                  ),
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
    final items = <(String, String, Ic)>[
      ('search', l.search, Ic.search),
      ('sort', l.sort, Ic.sort),
      ('cats', l.manageCategories, Ic.tag),
      ('hideDone', ui.hideDone ? l.showCompleted : l.hideCompleted, Ic.hide),
      ('columns', l.columns, Ic.week),
      ('clearDone', l.deleteCompleted, Ic.sweep),
    ];
    // Feste Reihenfolge: Jeder Eintrag steht immer an derselben Stelle.
    return [
      for (final (id, label, icon) in items)
        MenuItemRow(
          entry: MenuEntry(
            label: label,
            icon: icon,
            onTap: () {
              Navigator.pop(menuContext);
              _menuItem(context, id, rect);
            },
          ),
        ),
    ];
  }

  void _menuItem(BuildContext context, String id, Rect rect) {
    final app = context.app;
    final l = context.l;
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
      case 'columns':
        Sheets(context, ui).columns(board: board);
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
  const _TaskList({required this.ui, required this.board});
  final UiState ui;

  /// Listen nebeneinander (PC) statt Abschnitte untereinander.
  final bool board;

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    final l = context.l;
    final tok = context.tok;
    int off(Task t) => store.catOf(t.categoryId).offset;
    final searching = ui.search != null && ui.search!.trim().isNotEmpty;
    final filter = _filterOf(ui, store.categories, board: board);
    final now = clock();
    final all = filterTasks(
      store.tasksWithOlder,
      filter: filter == filterHabits ? filterAll : filter,
      hideDone: ui.hideDone,
      search: ui.search,
    );
    // „In Aufgaben zeigen“ der Kategorie gilt nur in der normalen Liste: Die Suche und der
    // Chip einer Kategorie zeigen alles.
    final byFrom = ui.search == null && (filter == filterAll || filter == filterHabits);
    final list = byFrom
        ? all.where((t) => shownInList(store.catOf(t.categoryId).listFrom, sectionOf(t, off(t), now: now))).toList()
        : all;
    final hidden = all.length - list.length;
    list.sort((a, b) => byDo(a, b, off));
    // Am PC stehen die Gewohnheiten in der Seitenleiste.
    final showHabits = !board && ui.search == null && (filter == filterAll || filter == filterHabits);
    // Ältere erledigte liegen nur online: Knopf zum Nachladen bzw. Hinweis am Ende der Liste –
    // außer der Abschnitt „Erledigt“ ist zugeklappt oder Erledigte sind ausgeblendet.
    final olderCat = filter == filterAll || filter == filterHabits ? null : filter;
    var showOlder = filter != filterHabits && !ui.hideDone && store.olderWaiting(categoryId: olderCat) > 0;

    // Gruppen: Zeiträume oder Kategorien. `null` = eine einzige Liste (Suche, nach Name sortiert).
    List<TaskGroup>? groups;
    if (ui.search != null || ui.sort == SortMode.name) {
      if (ui.sort == SortMode.name) {
        list.sort((a, b) => doneLast(a, b) ?? a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
    } else if (ui.sort == SortMode.category) {
      groups = [
        for (final c in store.categories)
          (
            id: 'k-${c.id}',
            label: c.name,
            items: list.where((t) => t.categoryId == c.id).toList()..sort((a, b) => doneLast(a, b) ?? byDo(a, b, off)),
            color: tok.item(c.color).c,
            section: null,
          ),
      ].where((g) => g.items.isNotEmpty).toList();
    } else {
      // Zeiträume lassen sich ausblenden und Kategorien als eigene Listen dazunehmen
      // (⋮ → Spalten) – am PC sind das die Spalten, am Handy die Abschnitte.
      final set = context.app.settings;
      final hiddenSections = set.boardHidden;
      groups =
          <TaskGroup>[
            for (final s in Section.values)
              if (!hiddenSections.contains(s.name))
                (
                  id: s.name,
                  label: sectionLabel(l, s),
                  items: () {
                    final items = list.where((t) => sectionOf(t, off(t), now: now) == s).toList();
                    return s == Section.done ? items.reversed.toList() : items;
                  }(),
                  color: null,
                  section: s,
                ),
            // Leere Abschnitte entfallen. „Erledigt“ steht auch leer da, solange es ältere zum
            // Nachladen gibt; am PC bleibt außerdem „Heute“ immer stehen.
          ].where((g) {
            return g.items.isNotEmpty ||
                (g.section == Section.done && showOlder) ||
                (board && g.section == Section.today);
          }).toList();
      {
        for (final id in set.boardCats) {
          final c = store.categoryById(id);
          if (c == null) continue;
          groups.add((
            id: 'k-${c.id}',
            label: c.name,
            // Alles aus der Kategorie – auch was „In Aufgaben zeigen“ sonst noch zurückhält.
            items: all.where((t) => t.categoryId == c.id).toList()..sort((a, b) => doneLast(a, b) ?? byDo(a, b, off)),
            color: tok.item(c.color).c,
            section: null,
          ));
        }
        // Reihenfolge, wie man sie sich an den Überschriften zurechtgezogen hat.
        final order = set.boardColumnOrder();
        groups.sort((a, b) => order.indexOf(a.id) - order.indexOf(b.id));
      }
    }

    // Der Hinweis kommt nur beim ersten Mal (gemerkt am Gerät) und bleibt dann für diesen
    // App-Start stehen, bis man ihn schließt.
    final set = context.app.settings;
    final showHint = hidden > 0 && filter != filterHabits && (set.hiddenHintNow || !set.hiddenHintSeen);
    if (showHint && !set.hiddenHintSeen) WidgetsBinding.instance.addPostFrameCallback((_) => set.markHiddenHintSeen());
    final hiddenNote = showHint
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    l.hiddenByCategory(hidden),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: Fs.meta, color: tok.sub),
                  ),
                ),
                IconBtn(Ic.x, label: l.closeHint, size: 18, onTap: set.closeHiddenHint),
              ],
            ),
          )
        : null;

    // Alle Spalten ausgeblendet: sagen, woran es liegt, statt eine leere Seite zu zeigen.
    final allHidden = groups != null && groups.isEmpty && list.isNotEmpty;
    if (board && allHidden) {
      return EmptyState(icon: Ic.week, text: l.columnsAllHidden);
    }
    if (board && groups != null && groups.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 0, Sizes.wideBottom - 12),
        child: Column(
          children: [
            Expanded(
              child: TasksBoard(
                ui: ui,
                groups: groups,
                showOlder: showOlder,
                olderCat: olderCat,
                maxVisible: context.app.settings.boardVisible,
                onMove: ui.sort == SortMode.date ? context.app.settings.moveBoardColumn : null,
                onReorder: context.app.settings.reorderBoard,
              ),
            ),
            if (hiddenNote != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: hiddenNote),
          ],
        ),
      );
    }

    final children = <Widget>[
      if (showHabits) ...[const SizedBox(height: 8), HabitsTaskCard(ui: ui)],
    ];
    TaskCard card(Task t) => TaskCard(key: ValueKey(t.id), task: t, ui: ui);
    if (filter != filterHabits) {
      if (allHidden) {
        children.add(EmptyState(icon: Ic.week, text: l.columnsAllHidden));
      } else if (list.isEmpty && !showOlder) {
        children.add(EmptyState(icon: searching ? Ic.search : Ic.tasks, text: searching ? l.nothingFound : l.noTasks));
      } else if (groups == null) {
        children
          ..add(const SizedBox(height: 8))
          ..addAll(list.map(card));
      } else {
        // Nach Datum sortiert lassen sich die Abschnitte mit langem Druck umsortieren.
        final set = context.app.settings;
        final move = ui.sort == SortMode.date && groups.length > 1 ? set.moveBoardColumn : null;
        // Während des Ziehens gilt die Vorschau; gespeichert wird erst beim Loslassen.
        final drag = ui.sectionDrag;
        final gs = drag.apply(groups, (g) => g.id);
        void hover(String id, String target) {
          if (drag.move([for (final x in gs) x.id], id, target)) ui.sectionDragTick.value++;
        }

        void done() {
          final ids = drag.finish();
          if (ids == null) return;
          set.reorderBoard(ids);
          ui.sectionDragTick.value++;
        }

        for (final (i, g) in gs.indexed) {
          final open = !ui.collapsed.contains(g.id);
          if (g.section == Section.done && !open) showOlder = false;
          final head = SectionHead(
            label: g.label,
            count: g.items.length,
            open: open,
            color: g.color,
            overdue: g.section == Section.overdue,
            onTap: () => ui.toggleCollapsed(g.id),
          );
          final items = [if (open) ...g.items.map(card)];
          if (move == null) {
            children
              ..add(head)
              ..addAll(items);
            continue;
          }
          children.add(
            MovableSection(
              key: ValueKey('section-${g.id}'),
              id: g.id,
              head: head,
              onDrop: (id) => hover(id, g.id),
              onDone: done,
              onUp: i == 0 ? null : () => move(g.id, gs[i - 1].id),
              onDown: i == gs.length - 1 ? null : () => move(g.id, gs[i + 1].id),
              children: items,
            ),
          );
        }
      }
    }
    if (hiddenNote != null) children.add(hiddenNote);
    if (showOlder) children.add(OlderDoneHint(categoryId: olderCat));
    final listView = ListView(
      padding: EdgeInsets.only(bottom: ShellLayout.bottomOf(context)),
      children: children,
    );
    // Am PC ohne Gruppen (Suche, nach Name): eine Liste in lesbarer Breite statt über den ganzen Platz.
    if (!board) return listView;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.wideList),
        child: listView,
      ),
    );
  }
}
