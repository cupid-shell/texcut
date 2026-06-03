import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/snippet.dart';
import '../../state/app_state.dart';
import '../widgets/service_status_card.dart';
import '../widgets/snippet_tile.dart';
import 'edit_snippet_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check whether the user enabled the service while we were backgrounded.
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().refreshServiceStatus();
    }
  }

  Future<void> _openEditor([Snippet? snippet]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditSnippetScreen(snippet: snippet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final snippets = state.visibleSnippets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('texcut'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New snippet'),
      ),
      body: Column(
        children: [
          const ServiceStatusCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: state.setQuery,
              decoration: InputDecoration(
                hintText: 'Search shortcuts, text or groups',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          state.setQuery('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: snippets.isEmpty
                ? _EmptyState(hasQuery: state.query.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: snippets.length,
                    itemBuilder: (context, index) {
                      final s = snippets[index];
                      return Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 28),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.delete_rounded,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) => _confirmDelete(s),
                        onDismissed: (_) => state.delete(s.id),
                        child: SnippetTile(
                          snippet: s,
                          onTap: () => _openEditor(s),
                          onToggle: (v) => state.toggleEnabled(s.id, v),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.bolt_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No matches' : 'No snippets yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search.'
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
