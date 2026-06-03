import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/snippet.dart';
import '../../services/expander.dart';
import '../../state/app_state.dart';

/// Create or edit a single snippet, with a live expansion preview and a
/// built-in "try it" field that runs the real [Expander].
class EditSnippetScreen extends StatefulWidget {
  const EditSnippetScreen({super.key, this.snippet});

  final Snippet? snippet;

  @override
  State<EditSnippetScreen> createState() => _EditSnippetScreenState();
}

class _EditSnippetScreenState extends State<EditSnippetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shortcut;
  late final TextEditingController _expansion;
  late final TextEditingController _label;
  late final TextEditingController _group;
  late final TextEditingController _tryIt;
  bool _enabled = true;

  bool get _isNew => widget.snippet == null;

  @override
  void initState() {
    super.initState();
    final s = widget.snippet;
    _shortcut = TextEditingController(text: s?.shortcut ?? '');
    _expansion = TextEditingController(text: s?.expansion ?? '');
    _label = TextEditingController(text: s?.label ?? '');
    _group = TextEditingController(text: s?.group ?? 'General');
    _tryIt = TextEditingController();
    _enabled = s?.enabled ?? true;
    _expansion.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _shortcut.dispose();
    _expansion.dispose();
    _label.dispose();
    _group.dispose();
    _tryIt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();

    final base = widget.snippet ??
        Snippet(id: Snippet.newId(), shortcut: '', expansion: '');
    final updated = base.copyWith(
      shortcut: _shortcut.text.trim(),
      expansion: _expansion.text,
      label: _label.text.trim(),
      group: _group.text.trim().isEmpty ? 'General' : _group.text.trim(),
      enabled: _enabled,
    );
    await state.upsert(updated);
    if (mounted) Navigator.of(context).pop();
  }

  void _insertToken(String token) {
    final sel = _expansion.selection;
    final text = _expansion.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, token);
    _expansion.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final expander = Expander(state.settings);
    final rendered = expander.render(
      _expansion.text,
      now: DateTime.now(),
      clipboard: '«clipboard»',
    );
    final existingGroups = state.groups;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New snippet' : 'Edit snippet'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Section(
              title: 'Shortcut',
              icon: Icons.keyboard_rounded,
              child: TextFormField(
                controller: _shortcut,
                autofocus: _isNew,
                decoration: const InputDecoration(
                  hintText: 'What you type, e.g. ;email',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter a shortcut';
                  }
                  final clash = state.snippets.any((s) =>
                      s.id != widget.snippet?.id && s.shortcut == v.trim());
                  if (clash) return 'Another snippet already uses this shortcut';
                  return null;
                },
              ),
            ),
            _Section(
              title: 'Expands to',
              icon: Icons.notes_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _expansion,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'The full text this expands into…',
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Enter the expansion text'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text('Insert a dynamic value',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  _TokenBar(onInsert: _insertToken),
                  const SizedBox(height: 12),
                  _PreviewCard(text: rendered.text),
                ],
              ),
            ),
            _Section(
              title: 'Details',
              icon: Icons.tune_rounded,
              child: Column(
                children: [
                  TextFormField(
                    controller: _label,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _group,
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                  ),
                  if (existingGroups.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final g in existingGroups)
                            ActionChip(
                              label: Text(g),
                              onPressed: () =>
                                  setState(() => _group.text = g),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: const Text('Enabled'),
                    subtitle: const Text('Disabled snippets never expand'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Try it out',
              icon: Icons.play_circle_outline_rounded,
              child: TextField(
                controller: _tryIt,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Type your shortcut here to test the expansion…',
                ),
                onChanged: (value) {
                  final result = expander.expand(
                    text: value,
                    cursor: _tryIt.selection.baseOffset >= 0
                        ? _tryIt.selection.baseOffset
                        : value.length,
                    snippets: [
                      Snippet(
                        id: 'preview',
                        shortcut: _shortcut.text.trim(),
                        expansion: _expansion.text,
                      ),
                    ],
                    clipboard: '«clipboard»',
                  );
                  if (result != null) {
                    _tryIt.value = TextEditingValue(
                      text: result.text,
                      selection:
                          TextSelection.collapsed(offset: result.cursor),
                    );
                    HapticFeedback.selectionClick();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isNew ? 'Create snippet' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled section with an icon header and a card body.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenBar extends StatelessWidget {
  const _TokenBar({required this.onInsert});
  final ValueChanged<String> onInsert;

  static const _tokens = {
    '{date}': 'Date',
    '{time}': 'Time',
    '{datetime}': 'Date & time',
    '{clipboard}': 'Clipboard',
    '{cursor}': 'Caret',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final entry in _tokens.entries)
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(entry.value),
            onPressed: () => onInsert(entry.key),
          ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Preview', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            text.isEmpty ? '—' : text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
