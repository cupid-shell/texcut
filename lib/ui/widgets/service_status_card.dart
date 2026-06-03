import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'enable_guide_sheet.dart';

/// Banner that surfaces whether system-wide expansion is active and, when it
/// isn't, opens a guided sheet to turn it on (handles the Android 13+
/// "restricted settings" hurdle).
class ServiceStatusCard extends StatelessWidget {
  const ServiceStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final connected = state.serviceConnected;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final Color bg =
        connected ? scheme.secondaryContainer : scheme.tertiaryContainer;
    final Color fg =
        connected ? scheme.onSecondaryContainer : scheme.onTertiaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: connected
              ? state.refreshServiceStatus
              : () => showEnableGuide(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    connected
                        ? Icons.verified_rounded
                        : Icons.bolt_rounded,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected
                            ? 'System-wide expansion is on'
                            : 'Turn on system-wide expansion',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected
                            ? 'Your shortcuts expand in every app.'
                            : 'Tap to enable it in a couple of steps.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  connected
                      ? Icons.refresh_rounded
                      : Icons.chevron_right_rounded,
                  color: fg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
