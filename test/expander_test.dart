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

    test('input labels are extracted in order without duplicates', () {
      const e = Expander(ExpansionSettings());
      expect(
        e.inputLabels('Hi {input:Name}, your code is {input:Code} {input:Name}'),
        ['Name', 'Code'],
      );
    });

    test('input token uses provided value, else a bracketed placeholder', () {
      const e = Expander(ExpansionSettings());
      expect(e.render('Hi {input:Name}', now: fixedNow).text, 'Hi [Name]');
      expect(
        e.render('Hi {input:Name}', now: fixedNow, inputs: {'Name': 'Avi'}).text,
        'Hi Avi',
      );
    });

    test('input values flow through expand', () {
      final result = expander.expand(
        text: ';greet',
        cursor: 6,
        snippets: [snip(';greet', 'Dear {input:Name},')],
        now: fixedNow,
        inputs: {'Name': 'Sam'},
      );
      expect(result!.text, 'Dear Sam,');
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

  group('smart case', () {
    const expander = Expander(ExpansionSettings(
      triggerMode: TriggerMode.instant,
      smartCase: true,
    ));

    test('lowercase typed keeps the authored casing', () {
      final r = expander.expand(
        text: 'btw',
        cursor: 3,
        snippets: [snip('btw', 'by the way')],
        now: fixedNow,
      );
      expect(r!.text, 'by the way');
    });

    test('capitalised typed capitalises the first letter', () {
      final r = expander.expand(
        text: 'Btw',
        cursor: 3,
        snippets: [snip('btw', 'by the way')],
        now: fixedNow,
      );
      expect(r!.text, 'By the way');
    });

    test('all-caps typed uppercases the whole expansion', () {
      final r = expander.expand(
        text: 'BTW',
        cursor: 3,
        snippets: [snip('btw', 'by the way')],
        now: fixedNow,
      );
      expect(r!.text, 'BY THE WAY');
    });
  });

  group('choice fields', () {
    const e = Expander(ExpansionSettings(triggerMode: TriggerMode.instant));

    test('previews the first option when no value is supplied', () {
      expect(
        e.render('Good {choice:Morning|Afternoon|Evening}', now: fixedNow).text,
        'Good Morning',
      );
    });

    test('uses the chosen value, keyed by the raw option list', () {
      expect(
        e.render('Good {choice:Morning|Afternoon|Evening}',
            now: fixedNow,
            inputs: {'Morning|Afternoon|Evening': 'Evening'}).text,
        'Good Evening',
      );
    });

    test('supports an explicit Label=options form', () {
      final r = e.render('Status: {choice:State=Pending|Approved}',
          now: fixedNow, inputs: {'State': 'Approved'});
      expect(r.text, 'Status: Approved');
    });

    test('fillFields lists choice options and labels', () {
      final fields = e.fillFields(
          'Hi {input:Name}, you chose {choice:Pick=Red|Green|Blue}');
      expect(fields.length, 2);
      expect(fields[0].label, 'Name');
      expect(fields[0].isChoice, isFalse);
      expect(fields[1].label, 'Pick');
      expect(fields[1].options, ['Red', 'Green', 'Blue']);
    });

    test('choice value flows through expand', () {
      final result = e.expand(
        text: ';g',
        cursor: 2,
        snippets: [snip(';g', 'Good {choice:Morning|Evening}')],
        now: fixedNow,
        inputs: {'Morning|Evening': 'Evening'},
      );
      expect(result!.text, 'Good Evening');
    });
  });

  group('per-snippet trigger override', () {
    // Global mode is on-delimiter, but this snippet forces instant.
    const expander = Expander(ExpansionSettings(
      triggerMode: TriggerMode.onDelimiter,
    ));

    Snippet instantSnip(String shortcut, String expansion) => Snippet(
          id: shortcut,
          shortcut: shortcut,
          expansion: expansion,
          triggerMode: TriggerMode.instant,
        );

    test('instant override fires without a delimiter', () {
      final r = expander.expand(
        text: ';br',
        cursor: 3,
        snippets: [instantSnip(';br', 'Best regards')],
        now: fixedNow,
      );
      expect(r, isNotNull);
      expect(r!.text, 'Best regards');
    });

    test('no override still requires the global delimiter', () {
      final r = expander.expand(
        text: ';br',
        cursor: 3,
        snippets: [snip(';br', 'Best regards')],
        now: fixedNow,
      );
      expect(r, isNull);
    });
  });
}
