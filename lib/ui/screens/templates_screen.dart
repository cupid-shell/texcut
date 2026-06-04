import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/templates.dart';
import '../../state/app_state.dart';

/// A gallery of ready-made snippet packs the user can add in one tap.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final packs = templatePacks();
    return Scaffold(
      appBar: AppBar(title: const Text('Snippet templates')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: packs.length,
        itemBuilder: (context, i) => _PackTile(pack: packs[i]),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack});
  final TemplatePack pack;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        leading: const Icon(Icons.collections_bookmark_rounded),
        title: Text(pack.name),
        subtitle: Text('${pack.description} · ${pack.snippets.length} snippets'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final s in pack.snippets)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.shortcut,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.expansion.replaceAll('\n', ' ↵ '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text('Add ${pack.snippets.length} snippets'),
              onPressed: () async {
                final count = await context
                    .read<AppState>()
                    .addSnippets(pack.snippets);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $count snippets from '
                      '“${pack.name}”')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
