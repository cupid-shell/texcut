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
        Snippet(
          id: Snippet.newId(),
          shortcut: '',
          expansion: '',
        );
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
    final settings = context.read<AppState>().settings;
    final expander = Expander(settings);
    final rendered = expander.render(
      _expansion.text,
      now: DateTime.now(),
      clipboard: '«clipboard»',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New snippet' : 'Edit snippet'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _shortcut,
              autofocus: _isNew,
              decoration: const InputDecoration(
                labelText: 'Shortcut',
                helperText: 'What you type, e.g. ;email',
                prefixIcon: Icon(Icons.keyboard_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a shortcut';
                }
                final state = context.read<AppState>();
                final clash = state.snippets.any((s) =>
                    s.id != widget.snippet?.id &&
                    s.shortcut == v.trim());
                if (clash) return 'Another snippet already uses this shortcut';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _expansion,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Expands to',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 64),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter the expansion text' : null,
            ),
            const SizedBox(height: 8),
            _TokenBar(onInsert: _insertToken),
            const SizedBox(height: 16),
            _PreviewCard(text: rendered.text),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _label,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _group,
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const Text('Enabled'),
              subtitle: const Text('Disabled snippets never expand'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 32),
            Text('Try it out', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
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
          ],
        ),
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
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Preview',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              text.isEmpty ? '—' : text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
