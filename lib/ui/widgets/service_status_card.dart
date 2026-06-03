import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// Banner that surfaces whether system-wide expansion is currently active and
/// lets the user jump to the OS accessibility settings to enable it.
class ServiceStatusCard extends StatelessWidget {
  const ServiceStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final connected = state.serviceConnected;
    final scheme = Theme.of(context).colorScheme;

    final bg = connected ? scheme.secondaryContainer : scheme.errorContainer;
    final fg =
        connected ? scheme.onSecondaryContainer : scheme.onErrorContainer;

    return Card(
      color: bg,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              connected ? Icons.verified_rounded : Icons.error_outline_rounded,
              color: fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected
                        ? 'System-wide expansion is active'
                        : 'Enable system-wide expansion',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? 'Your shortcuts expand in any app.'
                        : 'Turn on the texcut accessibility service to expand text anywhere.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
            if (!connected)
              TextButton(
                onPressed: () async {
                  await state.openSystemSettings();
                },
                style: TextButton.styleFrom(foregroundColor: fg),
                child: const Text('Open'),
              )
            else
              IconButton(
                tooltip: 'Refresh status',
                onPressed: state.refreshServiceStatus,
                icon: Icon(Icons.refresh_rounded, color: fg),
              ),
          ],
        ),
      ),
    );
  }
}
