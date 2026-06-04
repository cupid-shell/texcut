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
    final paused = connected && state.paused;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final Color bg = !connected
        ? scheme.tertiaryContainer
        : paused
            ? scheme.errorContainer
            : scheme.secondaryContainer;
    final Color fg = !connected
        ? scheme.onTertiaryContainer
        : paused
            ? scheme.onErrorContainer
            : scheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: !connected
              ? () => showEnableGuide(context)
              : paused
                  ? () => state.setPaused(false)
                  : state.refreshServiceStatus,
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
                    !connected
                        ? Icons.bolt_rounded
                        : paused
                            ? Icons.pause_circle_rounded
                            : Icons.verified_rounded,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !connected
                            ? 'Turn on system-wide expansion'
                            : paused
                                ? 'Expansion is paused'
                                : 'System-wide expansion is on',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !connected
                            ? 'Tap to enable it in a couple of steps.'
                            : paused
                                ? 'Tap to resume expanding everywhere.'
                                : 'Your shortcuts expand in every app.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  !connected
                      ? Icons.chevron_right_rounded
                      : paused
                          ? Icons.play_arrow_rounded
                          : Icons.refresh_rounded,
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
