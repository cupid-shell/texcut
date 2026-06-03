import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/expansion_settings.dart';
import '../../state/app_state.dart';
import '../widgets/enable_guide_sheet.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader(context, 'System-wide expansion'),
          SwitchListTile(
            secondary: const Icon(Icons.public_rounded),
            title: const Text('Enable expansion everywhere'),
            subtitle: const Text(
                'Master switch for the accessibility service. Also requires '
                'the OS toggle.'),
            value: s.serviceEnabled,
            onChanged: (v) =>
                state.updateSettings(s.copyWith(serviceEnabled: v)),
          ),
          ListTile(
            leading: Icon(
              state.serviceConnected
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: state.serviceConnected
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
            ),
            title: const Text('Accessibility service'),
            subtitle: Text(state.serviceConnected
                ? 'Connected'
                : 'Not connected — tap for setup help'),
            trailing: Icon(state.serviceConnected
                ? Icons.open_in_new_rounded
                : Icons.help_outline_rounded),
            onTap: () => state.serviceConnected
                ? state.openSystemSettings()
                : showEnableGuide(context),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('How to enable on Android 13+'),
            subtitle: const Text(
                'Walks you through the “Allow restricted settings” step'),
            onTap: () => showEnableGuide(context),
          ),
          _sectionHeader(context, 'Triggering'),
          ListTile(
            leading: const Icon(Icons.bolt_rounded),
            title: const Text('Trigger mode'),
            subtitle: Text(s.triggerMode.label),
            onTap: () => _pickTriggerMode(context, state),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.text_fields_rounded),
            title: const Text('Require word boundary'),
            subtitle: const Text(
                'Avoid expanding shortcuts inside longer words'),
            value: s.requireWordBoundary,
            onChanged: (v) =>
                state.updateSettings(s.copyWith(requireWordBoundary: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.text_format_rounded),
            title: const Text('Case sensitive'),
            subtitle: const Text('“;BR” and “;br” are treated as different'),
            value: s.caseSensitive,
            onChanged: (v) =>
                state.updateSettings(s.copyWith(caseSensitive: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Haptic feedback'),
            subtitle: const Text('Vibrate when a shortcut expands'),
            value: s.hapticFeedback,
            onChanged: (v) =>
                state.updateSettings(s.copyWith(hapticFeedback: v)),
          ),
          _sectionHeader(context, 'Formats'),
          ListTile(
            leading: const Icon(Icons.calendar_today_rounded),
            title: const Text('Date format'),
            subtitle: Text(s.dateFormat),
            onTap: () => _editFormat(
              context,
              title: 'Date format',
              initial: s.dateFormat,
              onSave: (v) =>
                  state.updateSettings(s.copyWith(dateFormat: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.access_time_rounded),
            title: const Text('Time format'),
            subtitle: Text(s.timeFormat),
            onTap: () => _editFormat(
              context,
              title: 'Time format',
              initial: s.timeFormat,
              onSave: (v) =>
                  state.updateSettings(s.copyWith(timeFormat: v)),
            ),
          ),
          _sectionHeader(context, 'Backup'),
          ListTile(
            leading: const Icon(Icons.upload_rounded),
            title: const Text('Export library'),
            subtitle: const Text('Copy all snippets as JSON to the clipboard'),
            onTap: () => _export(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Import library'),
            subtitle: const Text('Paste a previously exported JSON document'),
            onTap: () => _import(context, state),
          ),
          _sectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About texcut'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1,
              ),
        ),
      );

  void _pickTriggerMode(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<TriggerMode>(
          groupValue: state.settings.triggerMode,
          onChanged: (v) {
            if (v != null) {
              state.updateSettings(state.settings.copyWith(triggerMode: v));
            }
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in TriggerMode.values)
                RadioListTile<TriggerMode>(
                  value: mode,
                  title: Text(mode.label),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editFormat(
    BuildContext context, {
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            helperText: 'Uses intl date patterns, e.g. yyyy-MM-dd',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onSave(result);
  }

  Future<void> _export(BuildContext context, AppState state) async {
    final json = state.exportToJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Library copied to clipboard as JSON')),
    );
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null) controller.text = clip!.text!;

    if (!context.mounted) return;
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import library'),
        content: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'Paste exported JSON here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (raw == null || raw.trim().isEmpty) return;
    try {
      final count = await state.importFromJson(raw);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count snippets')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That doesn’t look like a valid export')),
      );
    }
  }
}
