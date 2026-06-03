import 'package:flutter/material.dart';

import '../../models/snippet.dart';

/// A single row in the snippet list.
class SnippetTile extends StatelessWidget {
  const SnippetTile({
    super.key,
    required this.snippet,
    required this.onTap,
    required this.onToggle,
  });

  final Snippet snippet;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = snippet.expansion.replaceAll('\n', ' ↵ ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              snippet.enabled ? scheme.primaryContainer : scheme.surfaceVariant,
          foregroundColor: snippet.enabled
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
          child: const Icon(Icons.short_text_rounded),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                snippet.shortcut,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                snippet.group,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Switch(
          value: snippet.enabled,
          onChanged: onToggle,
        ),
      ),
    );
  }
}
