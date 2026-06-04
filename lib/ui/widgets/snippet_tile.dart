import 'package:flutter/material.dart';

import '../../models/snippet.dart';

/// A single row in the snippet list.
class SnippetTile extends StatelessWidget {
  const SnippetTile({
    super.key,
    required this.snippet,
    required this.onTap,
    required this.onToggle,
    this.onLongPress,
  });

  final Snippet snippet;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = snippet.expansion.replaceAll('\n', ' ↵ ');
    final enabled = snippet.enabled;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // The shortcut, shown as a code-style pill.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: enabled
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            snippet.shortcut,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: enabled
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (snippet.pinned) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.push_pin_rounded,
                              size: 14, color: scheme.primary),
                        ],
                        if (snippet.usageCount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '·  ${snippet.usageCount}×',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (snippet.label.trim().isNotEmpty) ...[
                      Text(
                        snippet.label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}
