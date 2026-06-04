import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expansion_settings.dart';
import '../../models/snippet.dart';
import '../../state/app_state.dart';
import '../widgets/service_status_card.dart';
import '../widgets/snippet_tile.dart';
import 'edit_snippet_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  void _toggleSelect(Snippet s) {
    setState(() {
      if (!_selected.add(s.id)) _selected.remove(s.id);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AppState>().needsOnboarding) {
        Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const OnboardingScreen(),
        ));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().refreshServiceStatus();
    }
  }

  Future<void> _openEditor([Snippet? snippet]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditSnippetScreen(snippet: snippet)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final grouped = state.visibleByGroup;
    final hasAnySnippets = state.totalCount > 0;

    return Scaffold(
      appBar: _selecting ? _selectionAppBar(state) : _mainAppBar(state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New snippet'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: ServiceStatusCard()),
          if (hasAnySnippets)
            SliverToBoxAdapter(child: _StatsBar(state: state)),
          SliverToBoxAdapter(child: _SearchField(controller: _searchController)),
          if (state.groups.length > 1)
            SliverToBoxAdapter(child: _GroupFilterChips(state: state)),
          if (grouped.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                hasFilter: state.query.isNotEmpty || state.groupFilter != null,
              ),
            )
          else
            ..._buildGroupedSlivers(context, state, grouped),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  AppBar _mainAppBar(AppState state) {
    return AppBar(
      title: const Text('texcut'),
      actions: [
        PopupMenuButton<SortMode>(
          tooltip: 'Sort',
          icon: const Icon(Icons.sort_rounded),
          initialValue: state.settings.sortMode,
          onSelected: state.setSortMode,
          itemBuilder: (context) => [
            for (final m in SortMode.values)
              PopupMenuItem(value: m, child: Text(m.label)),
          ],
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  AppBar _selectionAppBar(AppState state) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearSelection,
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          tooltip: 'Pin',
          icon: const Icon(Icons.push_pin_rounded),
          onPressed: () async {
            await state.setPinnedMany(_selected, true);
            _clearSelection();
          },
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_rounded),
          onPressed: () => _bulkDelete(state),
        ),
        PopupMenuButton<String>(
          onSelected: (v) => _bulkMenu(state, v),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'enable', child: Text('Enable')),
            PopupMenuItem(value: 'disable', child: Text('Disable')),
            PopupMenuItem(value: 'unpin', child: Text('Unpin')),
            PopupMenuItem(value: 'move', child: Text('Move to group…')),
          ],
        ),
      ],
    );
  }

  Future<void> _bulkMenu(AppState state, String action) async {
    switch (action) {
      case 'enable':
        await state.setEnabledMany(_selected, true);
      case 'disable':
        await state.setEnabledMany(_selected, false);
      case 'unpin':
        await state.setPinnedMany(_selected, false);
      case 'move':
        final group = await _pickGroup(state);
        if (group != null) await state.moveMany(_selected, group);
    }
    if (mounted) _clearSelection();
  }

  Future<void> _bulkDelete(AppState state) async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $n snippet(s)?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteMany(_selected);
      _clearSelection();
    }
  }

  Future<String?> _pickGroup(AppState state) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            if (state.groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final g in state.groups)
                      ActionChip(
                        label: Text(g),
                        onPressed: () => Navigator.pop(context, g),
                      ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSlivers(
    BuildContext context,
    AppState state,
    Map<String, List<Snippet>> grouped,
  ) {
    final slivers = <Widget>[];
    grouped.forEach((group, items) {
      slivers.add(
        SliverToBoxAdapter(
          child: _GroupHeader(name: group, count: items.length),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final s = items[index];
              final tile = SnippetTile(
                snippet: s,
                selected: _selected.contains(s.id),
                selectionMode: _selecting,
                onTap: () =>
                    _selecting ? _toggleSelect(s) : _openEditor(s),
                onToggle: (v) => state.toggleEnabled(s.id, v),
                onLongPress: () => _toggleSelect(s),
              );
              // No swipe-to-delete while multi-selecting.
              if (_selecting) return tile;
              return Dismissible(
                key: ValueKey(s.id),
                direction: DismissDirection.endToStart,
                background: _deleteBackground(context),
                confirmDismiss: (_) => _confirmDelete(s),
                onDismissed: (_) => state.delete(s.id),
                child: tile,
              );
            },
            childCount: items.length,
          ),
        ),
      );
    });
    return slivers;
  }

  Widget _deleteBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.delete_rounded, color: scheme.onErrorContainer),
    );
  }

  Future<bool> _confirmDelete(Snippet s) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete snippet?'),
        content: Text('“${s.displayTitle}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '${state.totalCount} snippets',
            style: theme.textTheme.labelLarge,
          ),
          Text(
            '  •  ${state.enabledCount} active',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SearchBar(
        controller: controller,
        hintText: 'Search shortcuts or text',
        leading: const Icon(Icons.search_rounded),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        onChanged: state.setQuery,
        trailing: [
          if (state.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                controller.clear();
                state.setQuery('');
              },
            ),
        ],
      ),
    );
  }
}

class _GroupFilterChips extends StatelessWidget {
  const _GroupFilterChips({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final groups = state.groups;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: state.groupFilter == null,
              onSelected: (_) => state.setGroupFilter(null),
            ),
          ),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(g),
                selected: state.groupFilter == g,
                onSelected: (sel) => state.setGroupFilter(sel ? g : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.name, required this.count});
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Icon(Icons.folder_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            name.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.search_off_rounded : Icons.bolt_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'No matches' : 'No snippets yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try a different search or group.'
                  : 'Tap “New snippet” to create your first expansion.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
