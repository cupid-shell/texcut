import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/snippet_repository.dart';
import '../../state/app_state.dart';
import 'edit_snippet_screen.dart';

/// A simple clipboard manager: saved clips you can paste anywhere via the
/// `;;` search launcher, copy back to the clipboard, or turn into a snippet.
class ClipsScreen extends StatelessWidget {
  const ClipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final clips = state.clips;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clips'),
        actions: [
          if (clips.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () async {
                final s = context.read<AppState>();
                final ok = await _confirm(context, 'Clear all clips?');
                if (ok) await s.clearClips();
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await context.read<AppState>().saveCurrentClipboard();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(saved == null
                ? 'Clipboard is empty (or not text)'
                : 'Saved clip'),
          ));
        },
        icon: const Icon(Icons.content_paste_rounded),
        label: const Text('Save clipboard'),
      ),
      body: clips.isEmpty
          ? const _EmptyClips()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: clips.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _ClipTile(clip: clips[i]),
            ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({required this.clip});
  final ClipEntry clip;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(clip),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => context.read<AppState>().deleteClip(clip),
      child: ListTile(
        leading: const Icon(Icons.notes_rounded),
        title: Text(
          clip.text.replaceAll('\n', ' ↵ '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: clip.text));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        },
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'copy':
                Clipboard.setData(ClipboardData(text: clip.text));
              case 'snippet':
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      EditSnippetScreen(initialExpansion: clip.text),
                ));
              case 'delete':
                context.read<AppState>().deleteClip(clip);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'copy', child: Text('Copy')),
            PopupMenuItem(value: 'snippet', child: Text('Make snippet')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _EmptyClips extends StatelessWidget {
  const _EmptyClips();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.content_paste_search_rounded,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('No clips yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Copy something and tap “Save clipboard”, or select text in any '
              'app and share it to texcut. Then paste any clip via the “;;” '
              'search launcher.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
