import 'package:flutter/material.dart';

import '../../services/expander.dart';

/// Prompts for the values of fill-in fields (free-text {input:} and
/// {choice:} pick-lists). Returns label→value, or null if cancelled.
Future<Map<String, String>?> showFillDialog(
  BuildContext context,
  List<FillField> fields,
) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _FillDialog(fields: fields),
  );
}

class _FillDialog extends StatefulWidget {
  const _FillDialog({required this.fields});
  final List<FillField> fields;

  @override
  State<_FillDialog> createState() => _FillDialogState();
}

class _FillDialogState extends State<_FillDialog> {
  late final Map<String, TextEditingController> _text;
  late final Map<String, String> _chosen;

  @override
  void initState() {
    super.initState();
    _text = {
      for (final f in widget.fields)
        if (!f.isChoice) f.label: TextEditingController(),
    };
    // Pre-select the first option for each pick-list so "Insert" always works.
    _chosen = {
      for (final f in widget.fields)
        if (f.isChoice) f.label: f.options.first,
    };
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _firstTextLabel {
    for (final f in widget.fields) {
      if (!f.isChoice) return f.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fill in'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: f.isChoice ? _choice(f) : _input(f),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            for (final e in _text.entries) e.key: e.value.text,
            ..._chosen,
          }),
          child: const Text('Insert'),
        ),
      ],
    );
  }

  Widget _input(FillField f) => TextField(
        controller: _text[f.label],
        autofocus: f.label == _firstTextLabel,
        decoration: InputDecoration(labelText: f.title),
      );

  Widget _choice(FillField f) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final opt in f.options)
                ChoiceChip(
                  label: Text(opt),
                  selected: _chosen[f.label] == opt,
                  onSelected: (_) => setState(() => _chosen[f.label] = opt),
                ),
            ],
          ),
        ],
      );
}
