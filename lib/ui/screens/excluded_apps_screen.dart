import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/snippet_repository.dart';
import '../../state/app_state.dart';

/// Lets the user exclude specific apps from expansion. The list is populated
/// from apps the accessibility service has seen you type in (so no
/// QUERY_ALL_PACKAGES permission is needed); already-excluded apps are always
/// shown even if not seen this session.
class ExcludedAppsScreen extends StatefulWidget {
  const ExcludedAppsScreen({super.key});

  @override
  State<ExcludedAppsScreen> createState() => _ExcludedAppsScreenState();
}

class _ExcludedAppsScreenState extends State<ExcludedAppsScreen> {
  late Future<List<SeenApp>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().refreshSeenApps();
  }

  void _reload() {
    setState(() {
      _future = context.read<AppState>().refreshSeenApps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excluded apps'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<SeenApp>>(
        future: _future,
        builder: (context, snapshot) {
          final seen = snapshot.data ?? const <SeenApp>[];
          // Merge seen apps with any excluded packages not in the seen list.
          final byPackage = {for (final a in seen) a.packageName: a.label};
          for (final pkg in state.excludedApps) {
            byPackage.putIfAbsent(pkg, () => pkg);
          }
          final entries = byPackage.entries.toList()
            ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entries.isEmpty) {
            return const _EmptyHint();
          }

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Snippets won’t expand in the apps you switch on here. '
                  'Apps appear after you’ve typed in them at least once.',
                ),
              ),
              for (final e in entries)
                SwitchListTile(
                  secondary: const Icon(Icons.android_rounded),
                  title: Text(e.value),
                  subtitle: Text(e.key,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  value: state.excludedApps.contains(e.key),
                  onChanged: (v) => state.setAppExcluded(e.key, v),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps_rounded,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('No apps yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Type in a few apps with the service enabled, then come back and '
              'pull to refresh — they’ll show up here to exclude.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
