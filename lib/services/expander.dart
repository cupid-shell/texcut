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
  }) {
    if (cursor < 0 || cursor > text.length) return null;

    final mode = settings.triggerMode;
    var head = text.substring(0, cursor);

    // In on-delimiter mode the firing character is the last typed char; we
    // match the shortcut that sits immediately before it.
    String trailing = '';
    if (mode == TriggerMode.onDelimiter) {
      if (head.isEmpty) return null;
      final last = head[head.length - 1];
      if (!_delimiters.contains(last)) return null;
      trailing = last;
      head = head.substring(0, head.length - 1);
    }

    final candidates = snippets
        .where((s) => s.enabled && s.shortcut.isNotEmpty)
        // Longest shortcut first so "addr2" wins over "addr".
        .toList()
      ..sort((a, b) => b.shortcut.length.compareTo(a.shortcut.length));

    for (final s in candidates) {
      final shortcut = s.shortcut;
      final hay = settings.caseSensitive ? head : head.toLowerCase();
      final needle = settings.caseSensitive ? shortcut : shortcut.toLowerCase();
      if (!hay.endsWith(needle)) continue;

      final matchStart = head.length - shortcut.length;
      if (settings.requireWordBoundary && matchStart > 0) {
        final before = head[matchStart - 1];
        // Only block when both sides of the seam are word chars (so a real
        // word wouldn't be split). Symbol-prefixed shortcuts always pass.
        if (_isWordChar(before) && _isWordChar(shortcut[0])) continue;
      }

      final rendered = render(
        s.expansion,
        now: now ?? DateTime.now(),
        clipboard: clipboard,
        snippets: {for (final e in snippets) e.shortcut: e.expansion},
        counter: counter,
      );

      final newText =
          text.substring(0, matchStart) + rendered.text + trailing + text.substring(cursor);
      final cursorOffset = rendered.cursorOffset ?? rendered.text.length;
      return ExpansionResult(
        text: newText,
        cursor: matchStart + cursorOffset,
        snippet: s,
      );
    }
    return null;
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
              _resolveToken(token, now, clipboard, snippets, counter, depth);
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

  _TokenResult _resolveToken(
    String token,
    DateTime now,
    String clipboard,
    Map<String, String> snippets,
    int counter,
    int depth,
  ) {
    final lower = token.toLowerCase();
    if (lower == 'cursor') return const _TokenResult.cursor();
    if (lower == 'clipboard') return _TokenResult.value(clipboard);
    if (lower == 'counter') return _TokenResult.value(counter.toString());

    // Nested snippet: {snippet:;sig} or {s:;sig}
    if (lower.startsWith('snippet:') || lower.startsWith('s:')) {
      final shortcut = token.substring(token.indexOf(':') + 1).trim();
      final body = snippets[shortcut];
      if (body == null || depth >= 5) return const _TokenResult.unknown();
      final nested = render(body,
          now: now,
          clipboard: clipboard,
          snippets: snippets,
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
