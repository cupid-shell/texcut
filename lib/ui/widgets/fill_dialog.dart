import 'package:flutter/material.dart';

/// Prompts for the values of {input:Label} fields. Returns label→value, or
/// null if cancelled.
Future<Map<String, String>?> showFillDialog(
  BuildContext context,
  List<String> labels,
) {
  final controllers = {for (final l in labels) l: TextEditingController()};
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Fill in'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in labels)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[label],
                  autofocus: label == labels.first,
                  decoration: InputDecoration(labelText: label),
                ),
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
          onPressed: () => Navigator.pop(
            context,
            {for (final e in controllers.entries) e.key: e.value.text},
          ),
          child: const Text('Insert'),
        ),
      ],
    ),
  );
}
