import 'package:flutter_test/flutter_test.dart';
import 'package:texcut/models/expansion_settings.dart';
import 'package:texcut/models/snippet.dart';
import 'package:texcut/services/expander.dart';

void main() {
  Snippet snip(String shortcut, String expansion, {bool enabled = true}) =>
      Snippet(
        id: shortcut,
        shortcut: shortcut,
        expansion: expansion,
        enabled: enabled,
      );

  final fixedNow = DateTime(2026, 6, 3, 14, 5);

  group('instant trigger', () {
    const settings = ExpansionSettings(triggerMode: TriggerMode.instant);
    const expander = Expander(settings);

    test('expands an exact shortcut suffix', () {
      final result = expander.expand(
        text: 'hello ;br',
        cursor: 9,
        snippets: [snip(';br', 'Best regards')],
        now: fixedNow,
      );
      expect(result, isNotNull);
      expect(result!.text, 'hello Best regards');
      expect(result.cursor, 'hello Best regards'.length);
    });

    test('returns null when nothing matches', () {
      final result = expander.expand(
        text: 'nothing here',
        cursor: 12,
        snippets: [snip(';br', 'Best regards')],
        now: fixedNow,
      );
      expect(result, isNull);
    });

    test('longest shortcut wins', () {
      final result = expander.expand(
        text: ';addr2',
        cursor: 6,
        snippets: [
          snip(';addr', 'short'),
          snip(';addr2', 'long'),
        ],
        now: fixedNow,
      );
      expect(result!.snippet.shortcut, ';addr2');
      expect(result.text, 'long');
    });

    test('disabled snippets never fire', () {
      final result = expander.expand(
        text: ';br',
        cursor: 3,
        snippets: [snip(';br', 'Best regards', enabled: false)],
        now: fixedNow,
      );
      expect(result, isNull);
    });
  });

  group('on-delimiter trigger', () {
    const settings = ExpansionSettings(triggerMode: TriggerMode.onDelimiter);
    const expander = Expander(settings);

    test('expands only when a delimiter is typed', () {
      final noDelim = expander.expand(
        text: 'btw',
        cursor: 3,
        snippets: [snip('btw', 'by the way')],
        now: fixedNow,
      );
      expect(noDelim, isNull);

      final withDelim = expander.expand(
        text: 'btw ',
        cursor: 4,
        snippets: [snip('btw', 'by the way')],
        now: fixedNow,
      );
      expect(withDelim, isNotNull);
      expect(withDelim!.text, 'by the way ');
    });
  });

  group('word boundary', () {
    const settings = ExpansionSettings(
      triggerMode: TriggerMode.instant,
      requireWordBoundary: true,
    );
    const expander = Expander(settings);

    test('does not split a real word', () {
      // "br" sits inside "abr" — both seam chars are letters, so no expansion.
      final result = expander.expand(
        text: 'abr',
        cursor: 3,
        snippets: [snip('br', 'Best regards')],
        now: fixedNow,
      );
      expect(result, isNull);
    });

    test('symbol-prefixed shortcuts always pass the boundary check', () {
      final result = expander.expand(
        text: 'word;br',
        cursor: 7,
        snippets: [snip(';br', 'Best regards')],
        now: fixedNow,
      );
      expect(result, isNotNull);
      expect(result!.text, 'wordBest regards');
    });
  });

  group('case sensitivity', () {
    test('case-insensitive matches differing case', () {
      const expander = Expander(ExpansionSettings(
        triggerMode: TriggerMode.instant,
        caseSensitive: false,
      ));
      final result = expander.expand(
        text: ';BR',
        cursor: 3,
        snippets: [snip(';br', 'Best regards')],
        now: fixedNow,
      );
      expect(result, isNotNull);
    });
  });

  group('token rendering', () {
    const expander = Expander(ExpansionSettings(
      dateFormat: 'yyyy-MM-dd',
      timeFormat: 'HH:mm',
    ));

    test('renders date and time tokens', () {
      final r = expander.render('{date} at {time}', now: fixedNow);
      expect(r.text, '2026-06-03 at 14:05');
    });

    test('renders clipboard token', () {
      final r = expander.render('paste: {clipboard}', now: fixedNow, clipboard: 'XYZ');
      expect(r.text, 'paste: XYZ');
    });

    test('cursor token sets offset and is removed', () {
      final r = expander.render('ab{cursor}cd', now: fixedNow);
      expect(r.text, 'abcd');
      expect(r.cursorOffset, 2);
    });

    test('custom date pattern', () {
      final r = expander.render('{date:yyyy}', now: fixedNow);
      expect(r.text, '2026');
    });

    test('escaped braces are literal', () {
      final r = expander.render('{{not a token}}', now: fixedNow);
      expect(r.text, '{not a token}');
    });

    test('unknown tokens are kept verbatim', () {
      final r = expander.render('{mystery}', now: fixedNow);
      expect(r.text, '{mystery}');
    });

    test('date math shifts days/months', () {
      expect(expander.render('{date+1d}', now: fixedNow).text, '2026-06-04');
      expect(expander.render('{date-2d}', now: fixedNow).text, '2026-06-01');
      expect(expander.render('{date+1mo}', now: fixedNow).text, '2026-07-03');
    });

    test('time math shifts minutes/hours', () {
      expect(expander.render('{time+30m}', now: fixedNow).text, '14:35');
      expect(expander.render('{time+1h}', now: fixedNow).text, '15:05');
    });

    test('offset combines with a custom pattern', () {
      expect(expander.render('{date+1d:yyyy-MM-dd}', now: fixedNow).text,
          '2026-06-04');
    });

    test('counter token uses the provided value', () {
      expect(expander.render('{counter}', now: fixedNow, counter: 7).text, '7');
    });

    test('nested snippet token expands another snippet', () {
      final r = expander.render(
        'Sign: {snippet:;sig}',
        now: fixedNow,
        snippets: {';sig': 'Best, A'},
      );
      expect(r.text, 'Sign: Best, A');
    });

    test('nested snippets do not recurse infinitely', () {
      final r = expander.render(
        '{snippet:;loop}',
        now: fixedNow,
        snippets: {';loop': 'x{snippet:;loop}'},
      );
      // Depth-limited: should terminate and contain some x's, not hang.
      expect(r.text.contains('x'), isTrue);
    });
  });

  group('tokens via expand', () {
    const expander = Expander(ExpansionSettings(triggerMode: TriggerMode.instant));

    test('nested snippet resolves through expand', () {
      final result = expander.expand(
        text: ';full',
        cursor: 5,
        snippets: [
          snip(';sig', 'Best'),
          snip(';full', 'Hi {snippet:;sig}'),
        ],
        now: fixedNow,
      );
      expect(result!.text, 'Hi Best');
    });

    test('counter flows through expand', () {
      final result = expander.expand(
        text: ';n',
        cursor: 2,
        snippets: [snip(';n', 'No {counter}')],
        now: fixedNow,
        counter: 3,
      );
      expect(result!.text, 'No 3');
    });
  });

  test('cursor token positions caret after expansion', () {
    const expander = Expander(ExpansionSettings(triggerMode: TriggerMode.instant));
    final result = expander.expand(
      text: ';wrap',
      cursor: 5,
      snippets: [snip(';wrap', '<b>{cursor}</b>')],
      now: fixedNow,
    );
    expect(result!.text, '<b></b>');
    expect(result.cursor, 3);
  });
}
