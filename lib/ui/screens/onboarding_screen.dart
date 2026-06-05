import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/enable_guide_sheet.dart';
import '../widgets/texcut_mark.dart';
import 'templates_screen.dart';

/// A short first-run walkthrough: what texcut does, enabling the service,
/// the fill-in overlay permission, and adding starter snippets.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<AppState>().markOnboarded();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _next() {
    if (_page >= 3) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _Page(
                    glyph: TexcutMark(
                        size: 56,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    title: 'Welcome to texcut',
                    body: 'Create short triggers like ;br or ;email and texcut '
                        'types the full text for you — in this app and across '
                        'your whole phone. Ad-free, every feature unlocked.',
                  ),
                  _Page(
                    icon: Icons.public_rounded,
                    title: 'Turn on system-wide expansion',
                    body: 'texcut uses an accessibility service to expand text '
                        'in any app. Tap below to enable it (Android needs you '
                        'to allow it once).',
                    action: FilledButton.icon(
                      onPressed: () => showEnableGuide(context),
                      icon: Icon(state.serviceConnected
                          ? Icons.check_rounded
                          : Icons.tune_rounded),
                      label: Text(state.serviceConnected
                          ? 'Service connected'
                          : 'Enable the service'),
                    ),
                  ),
                  _Page(
                    icon: Icons.edit_note_rounded,
                    title: 'Fill-in prompts (optional)',
                    body: 'Snippets can ask you for values with {input:Label}. '
                        'For that to work in other apps, allow texcut to draw '
                        'over them. You can skip this and set it up later.',
                    action: FilledButton.tonalIcon(
                      onPressed: () => state.openOverlaySettings(),
                      icon: Icon(state.overlayGranted
                          ? Icons.check_rounded
                          : Icons.layers_rounded),
                      label: Text(state.overlayGranted
                          ? 'Overlay allowed'
                          : 'Allow drawing over apps'),
                    ),
                  ),
                  _Page(
                    icon: Icons.collections_bookmark_rounded,
                    title: 'Add some snippets',
                    body: 'Start from a ready-made pack — emails, support '
                        'replies, coding, dates and more — or just create your '
                        'own from the home screen.',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const TemplatesScreen()),
                      ),
                      icon: const Icon(Icons.collections_bookmark_rounded),
                      label: const Text('Browse templates'),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_page >= 3 ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    this.icon,
    this.glyph,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData? icon;
  final Widget? glyph;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: glyph ?? Icon(icon, size: 44),
          ),
          const SizedBox(height: 28),
          Text(title, style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(body,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}
