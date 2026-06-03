import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// A guided, step-by-step sheet that walks the user through enabling the
/// system-wide accessibility service — including the "Allow restricted
/// settings" hop that Android 13+ forces on sideloaded apps.
Future<void> showEnableGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _EnableGuideSheet(),
  );
}

class _EnableGuideSheet extends StatelessWidget {
  const _EnableGuideSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<AppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Turn on system-wide expansion',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Android blocks sideloaded apps from accessibility until you '
              'unlock it. It only takes a minute — follow these steps:',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            const _Step(
              number: 1,
              title: 'Allow restricted settings',
              body: 'Open texcut’s App info, tap the ⋮ menu (top-right), '
                  'then tap “Allow restricted settings”. Enter your PIN if asked.',
            ),
            const _Step(
              number: 2,
              title: 'Enable the service',
              body: 'Open Accessibility settings, find “texcut text expander”, '
                  'and switch it on.',
            ),
            const _Step(
              number: 3,
              title: 'Come back to texcut',
              body: 'The banner turns green and your shortcuts expand in any app.',
              isLast: true,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => state.openAppSettings(),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('1. Open App info'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => state.openSystemSettings(),
              icon: const Icon(Icons.accessibility_new_rounded),
              label: const Text('2. Open Accessibility settings'),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final int number;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                child: Text('$number',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
