import 'package:intl/intl.dart';

import '../models/expansion_settings.dart';
import '../models/snippet.dart';

/// The result of expanding a shortcut inside a piece of text.
class ExpansionResult {
  const ExpansionResult({
    required this.text,
    required this.cursor,
    required this.snippet,
  });

  /// The full text after the shortcut was replaced.
  final String text;

  /// Where the caret should sit after expansion.
  final int cursor;

  /// The snippet that fired.
  final Snippet snippet;
}

/// Pure, side-effect free expansion engine.
///
/// This is the canonical implementation used by the in-app editor. The native
/// Android accessibility service mirrors this behaviour so that expansions feel
/// identical whether you type inside texcut or anywhere else on the device.
class Expander {
  const Expander(this.settings);

  final ExpansionSettings settings;

  static const Set<String> _delimiters = {
    ' ', '\n', '\t', '.', ',', ';', ':', '!', '?', ')', ']', '}', '"', "'",
  };

  /// Characters that count as part of a "word" when deciding boundaries.
  bool _isWordChar(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    final isDigit = code >= 0x30 && code <= 0x39;
    final isUpper = code >= 0x41 && code <= 0x5A;
    final isLower = code >= 0x61 && code <= 0x7A;
    return isDigit || isUpper || isLower;
  }

  /// Attempts to expand the text ending at [cursor].
  ///
  /// Returns `null` when nothing matched. [now] and [clipboard] are injectable
  /// so the logic stays deterministic and testable.
  ExpansionResult? expand({
    required String text,
    required int cursor,
    required List<Snippet> snippets,
    DateTime? now,
    String clipboard = '',
    int counter = 0,
    Map<String, String> inputs = const {},
  }) {
    if (cursor < 0 || cursor > text.length) return null;

    final head = text.substring(0, cursor);
    // Smart case implies case-insensitive matching so "BTW" can match "btw".
    final caseInsensitive = !settings.caseSensitive || settings.smartCase;

    final candidates = snippets
        .where((s) => s.enabled && s.shortcut.isNotEmpty)
        // Longest shortcut first so "addr2" wins over "addr".
        .toList()
      ..sort((a, b) => b.shortcut.length.compareTo(a.shortcut.length));

    for (final s in candidates) {
      // Each snippet may override the global trigger mode.
      final mode = s.triggerMode ?? settings.triggerMode;
      var matchHead = head;
      String trailing = '';
      if (mode == TriggerMode.onDelimiter) {
        if (head.isEmpty) continue;
        final last = head[head.length - 1];
        if (!_delimiters.contains(last)) continue;
        trailing = last;
        matchHead = head.substring(0, head.length - 1);
      }

      final shortcut = s.shortcut;
      final hay = caseInsensitive ? matchHead.toLowerCase() : matchHead;
      final needle = caseInsensitive ? shortcut.toLowerCase() : shortcut;
      if (!hay.endsWith(needle)) continue;

      final matchStart = matchHead.length - shortcut.length;
      if (settings.requireWordBoundary && matchStart > 0) {
        final before = matchHead[matchStart - 1];
        // Only block when both sides of the seam are word chars (so a real
        // word wouldn't be split). Symbol-prefixed shortcuts always pass.
        if (_isWordChar(before) && _isWordChar(shortcut[0])) continue;
      }

      final rendered = render(
        s.expansion,
        now: now ?? DateTime.now(),
        clipboard: clipboard,
        snippets: {for (final e in snippets) e.shortcut: e.expansion},
        inputs: inputs,
        counter: counter,
      );

      var outText = rendered.text;
      if (settings.smartCase) {
        final typed = matchHead.substring(matchStart);
        outText = applySmartCase(typed, shortcut, outText);
      }

      final newText =
          text.substring(0, matchStart) + outText + trailing + text.substring(cursor);
      // Smart-case transforms preserve length, so the caret offset still holds.
      final cursorOffset = rendered.cursorOffset ?? outText.length;
      return ExpansionResult(
        text: newText,
        cursor: matchStart + cursorOffset,
        snippet: s,
      );
    }
    return null;
  }

  /// Mirrors the typed shortcut's casing onto [text]:
  ///   ALLCAPS typed → uppercase; Capitalised typed → capitalise first letter.
  /// Returns [text] unchanged when the typed casing matches the authored
  /// shortcut or carries no clear casing signal.
  static String applySmartCase(String typed, String shortcut, String text) {
    if (text.isEmpty || typed == shortcut) return text;
    final letters = typed.replaceAll(RegExp('[^A-Za-z]'), '');
    if (letters.isEmpty) return text;
    final isAllUpper =
        letters == letters.toUpperCase() && letters != letters.toLowerCase();
    if (isAllUpper) return text.toUpperCase();
    // First alphabetic char of the typed text is uppercase → capitalise.
    if (letters[0] == letters[0].toUpperCase() &&
        letters[0] != letters[0].toLowerCase()) {
      for (var i = 0; i < text.length; i++) {
        final ch = text[i];
        if (RegExp('[A-Za-z]').hasMatch(ch)) {
          return text.substring(0, i) + ch.toUpperCase() + text.substring(i + 1);
        }
      }
    }
    return text;
  }

  /// Expands the dynamic placeholders inside an expansion body.
  ///
  /// Supported tokens:
  ///   {date}      current date (using [ExpansionSettings.dateFormat])
  ///   {time}      current time (using [ExpansionSettings.timeFormat])
  ///   {datetime}  date + time
  ///   {date:FMT}  custom intl date pattern
  ///   {clipboard} current clipboard contents
  ///   {cursor}    final caret position (removed from output)
  ///   {{ }}       literal braces
  RenderedExpansion render(
    String body, {
    required DateTime now,
    String clipboard = '',
    Map<String, String> snippets = const {},
    Map<String, String> inputs = const {},
    int counter = 0,
    int depth = 0,
  }) {
    final buffer = StringBuffer();
    int? cursorOffset;
    var i = 0;

    while (i < body.length) {
      final c = body[i];

      // Escaped literal braces.
      if (c == '{' && i + 1 < body.length && body[i + 1] == '{') {
        buffer.write('{');
        i += 2;
        continue;
      }
      if (c == '}' && i + 1 < body.length && body[i + 1] == '}') {
        buffer.write('}');
        i += 2;
        continue;
      }

      if (c == '{') {
        final end = body.indexOf('}', i + 1);
        if (end != -1) {
          final token = body.substring(i + 1, end).trim();
          final replacement =
              _resolveToken(token, now, clipboard, snippets, inputs, counter, depth);
          if (replacement.isCursor) {
            cursorOffset = buffer.length;
          } else if (replacement.handled) {
            buffer.write(replacement.value);
          } else {
            // Unknown token: keep it verbatim so users don't silently lose text.
            buffer.write(body.substring(i, end + 1));
          }
          i = end + 1;
          continue;
        }
      }

      buffer.write(c);
      i++;
    }

    return RenderedExpansion(text: buffer.toString(), cursorOffset: cursorOffset);
  }

  /// Returns the ordered, de-duplicated list of {input:Label} field labels in
  /// [body]. Used to prompt the user before expanding.
  List<String> inputLabels(String body) {
    final labels = <String>[];
    for (final m
        in RegExp(r'\{input:([^}]*)\}', caseSensitive: false).allMatches(body)) {
      final label = m.group(1)!.trim();
      if (label.isNotEmpty && !labels.contains(label)) labels.add(label);
    }
    return labels;
  }

  /// Returns the ordered, de-duplicated set of fill-in fields in [body] —
  /// both free-text {input:Label} fields and {choice:…} pick-lists. The
  /// returned [FillField.label] is the key to use in the `inputs` map.
  List<FillField> fillFields(String body) {
    final fields = <FillField>[];
    final seen = <String>{};
    final re = RegExp(r'\{(input|choice):([^}]*)\}', caseSensitive: false);
    for (final m in re.allMatches(body)) {
      final kind = m.group(1)!.toLowerCase();
      if (kind == 'input') {
        final label = m.group(2)!.trim();
        if (label.isEmpty || !seen.add(label)) continue;
        fields.add(FillField(label: label, title: label, options: const []));
      } else {
        final (label, options) = parseChoice(m.group(2)!);
        if (options.isEmpty || !seen.add(label)) continue;
        final title = label.contains('|') ? 'Choose' : label;
        fields.add(FillField(label: label, title: title, options: options));
      }
    }
    return fields;
  }

  /// Parses the text after `choice:` into a (label, options) pair.
  ///
  /// `Greeting=A|B|C` → ('Greeting', [A, B, C]); `A|B|C` → ('A|B|C', [A, B, C]),
  /// where the raw option list doubles as the (stable) map key.
  static (String, List<String>) parseChoice(String inner) {
    final eq = inner.indexOf('=');
    final String label;
    final String optsPart;
    if (eq >= 0) {
      label = inner.substring(0, eq).trim();
      optsPart = inner.substring(eq + 1);
    } else {
      label = inner.trim();
      optsPart = inner;
    }
    final options = optsPart
        .split('|')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    return (label, options);
  }

  _TokenResult _resolveToken(
    String token,
    DateTime now,
    String clipboard,
    Map<String, String> snippets,
    Map<String, String> inputs,
    int counter,
    int depth,
  ) {
    final lower = token.toLowerCase();
    if (lower == 'cursor') return const _TokenResult.cursor();
    if (lower == 'clipboard') return _TokenResult.value(clipboard);
    if (lower == 'counter') return _TokenResult.value(counter.toString());

    // Fill-in field: {input:Label}. Uses the provided value, or shows the
    // label in brackets when previewing (no value supplied yet).
    if (lower.startsWith('input:')) {
      final label = token.substring(token.indexOf(':') + 1).trim();
      return _TokenResult.value(inputs[label] ?? '[$label]');
    }

    // Pick-list field: {choice:A|B|C} or {choice:Label=A|B|C}. Uses the chosen
    // value, falling back to the first option when none was supplied yet.
    if (lower.startsWith('choice:')) {
      final inner = token.substring(token.indexOf(':') + 1);
      final (label, options) = parseChoice(inner);
      if (options.isEmpty) return const _TokenResult.unknown();
      final v = inputs[label];
      return _TokenResult.value(
          (v != null && v.isNotEmpty) ? v : options.first);
    }

    // Nested snippet: {snippet:;sig} or {s:;sig}
    if (lower.startsWith('snippet:') || lower.startsWith('s:')) {
      final shortcut = token.substring(token.indexOf(':') + 1).trim();
      final body = snippets[shortcut];
      if (body == null || depth >= 5) return const _TokenResult.unknown();
      final nested = render(body,
          now: now,
          clipboard: clipboard,
          snippets: snippets,
          inputs: inputs,
          counter: counter,
          depth: depth + 1);
      return _TokenResult.value(nested.text);
    }

    // Date/time with optional offset and pattern, e.g. {date}, {date:EEE},
    // {date+1d}, {date-1w:EEE}, {time+30m}, {datetime+1d}.
    final m = RegExp(
      r'^(date|time|datetime)([+-]\d+(?:y|mo|w|d|h|m))?(?::(.*))?$',
      caseSensitive: false,
    ).firstMatch(token);
    if (m != null) {
      final name = m.group(1)!.toLowerCase();
      final when = _shift(now, m.group(2));
      final pattern = m.group(3);
      try {
        if (pattern != null && pattern.isNotEmpty) {
          return _TokenResult.value(DateFormat(pattern).format(when));
        }
        switch (name) {
          case 'date':
            return _TokenResult.value(
                DateFormat(settings.dateFormat).format(when));
          case 'time':
            return _TokenResult.value(
                DateFormat(settings.timeFormat).format(when));
          case 'datetime':
            return _TokenResult.value(
                '${DateFormat(settings.dateFormat).format(when)} '
                '${DateFormat(settings.timeFormat).format(when)}');
        }
      } catch (_) {
        return const _TokenResult.unknown();
      }
    }
    return const _TokenResult.unknown();
  }

  /// Applies an offset like "+1d", "-2w", "+3mo" to [base].
  DateTime _shift(DateTime base, String? offset) {
    if (offset == null || offset.isEmpty) return base;
    final m = RegExp(r'^([+-])(\d+)(y|mo|w|d|h|m)$').firstMatch(offset);
    if (m == null) return base;
    final sign = m.group(1) == '-' ? -1 : 1;
    final amount = sign * int.parse(m.group(2)!);
    switch (m.group(3)!) {
      case 'y':
        return DateTime(base.year + amount, base.month, base.day, base.hour,
            base.minute, base.second);
      case 'mo':
        return DateTime(base.year, base.month + amount, base.day, base.hour,
            base.minute, base.second);
      case 'w':
        return base.add(Duration(days: 7 * amount));
      case 'd':
        return base.add(Duration(days: amount));
      case 'h':
        return base.add(Duration(hours: amount));
      case 'm':
        return base.add(Duration(minutes: amount));
    }
    return base;
  }
}

class RenderedExpansion {
  const RenderedExpansion({required this.text, this.cursorOffset});
  final String text;
  final int? cursorOffset;
}

/// A value the user supplies before a snippet expands. [options] empty means a
/// free-text {input:} field; non-empty means a {choice:} pick-list.
class FillField {
  const FillField({
    required this.label,
    required this.title,
    required this.options,
  });

  /// Key used in the `inputs` map passed to [Expander.expand]/[Expander.render].
  final String label;

  /// Human-friendly heading shown above the field.
  final String title;

  /// The choices for a pick-list; empty for a free-text field.
  final List<String> options;

  bool get isChoice => options.isNotEmpty;
}

class _TokenResult {
  const _TokenResult.value(this.value)
      : handled = true,
        isCursor = false;
  const _TokenResult.cursor()
      : value = '',
        handled = true,
        isCursor = true;
  const _TokenResult.unknown()
      : value = '',
        handled = false,
        isCursor = false;

  final String value;
  final bool handled;
  final bool isCursor;
}
