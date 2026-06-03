import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AppState>().snippets.length;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.bolt_rounded, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('texcut',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          Center(
            child: Text('Version 1.0.0',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 24),
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.celebration_rounded,
                      color: scheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ad-free, forever. Every feature is unlocked — no '
                      'premium tier, no paywalls, no tracking.',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _Bullet('Type a shortcut, get the full text — anywhere on '
              'your device.'),
          const _Bullet('Dynamic tokens: {date}, {time}, {clipboard}, '
              '{cursor} and more.'),
          const _Bullet('Works system-wide via an Android accessibility '
              'service.'),
          const _Bullet('All your data stays on-device.'),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.library_books_rounded),
            title: const Text('Snippets stored'),
            trailing: Text('$count'),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
