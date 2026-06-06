import 'package:flutter_test/flutter_test.dart';
import 'package:texcut/models/snippet.dart';
import 'package:texcut/services/snippet_merge.dart';

void main() {
  Snippet snip(String shortcut, {DateTime? updatedAt}) => Snippet(
        id: shortcut,
        shortcut: shortcut,
        expansion: 'x',
        updatedAt: updatedAt,
      );

  group('applyTombstones', () {
    test('removes a snippet deleted after its last edit', () {
      final snippets = [snip(';a', updatedAt: DateTime(2026, 1, 1))];
      final tombs = [
        Tombstone(shortcut: ';a', deletedAt: DateTime(2026, 2, 1)),
      ];
      expect(applyTombstones(snippets, tombs), isEmpty);
    });

    test('keeps a snippet re-created after the deletion', () {
      final snippets = [snip(';a', updatedAt: DateTime(2026, 3, 1))];
      final tombs = [
        Tombstone(shortcut: ';a', deletedAt: DateTime(2026, 2, 1)),
      ];
      expect(applyTombstones(snippets, tombs).length, 1);
    });

    test('leaves untouched shortcuts alone', () {
      final snippets = [snip(';b', updatedAt: DateTime(2026, 1, 1))];
      final tombs = [
        Tombstone(shortcut: ';a', deletedAt: DateTime(2026, 2, 1)),
      ];
      expect(applyTombstones(snippets, tombs).length, 1);
    });
  });

  group('mergeTombstones', () {
    test('keeps the latest deletedAt per shortcut', () {
      final merged = mergeTombstones(
        [Tombstone(shortcut: ';a', deletedAt: DateTime(2026, 1, 1))],
        [Tombstone(shortcut: ';a', deletedAt: DateTime(2026, 2, 1))],
        now: DateTime(2026, 2, 2),
      );
      expect(merged.length, 1);
      expect(merged.first.deletedAt, DateTime(2026, 2, 1));
    });

    test('prunes entries older than the retention window', () {
      final merged = mergeTombstones(
        [Tombstone(shortcut: ';old', deletedAt: DateTime(2020, 1, 1))],
        const [],
        now: DateTime(2026, 1, 1),
      );
      expect(merged, isEmpty);
    });
  });

  group('deletion sync end to end', () {
    test('a deletion on one side propagates through merge', () {
      // Device A has ;a and ;b; device B deleted ;a.
      final localA = [
        snip(';a', updatedAt: DateTime(2026, 1, 1)),
        snip(';b', updatedAt: DateTime(2026, 1, 1)),
      ];
      final incomingB = [snip(';b', updatedAt: DateTime(2026, 1, 1))];
      final incomingTombs = [
        Tombstone(shortcut: ';a', deletedAt: DateTime(2026, 1, 2)),
      ];

      final tombs = mergeTombstones([], incomingTombs, now: DateTime(2026, 1, 3));
      final unioned = mergeSnippets(localA, incomingB);
      final result = applyTombstones(unioned, tombs);

      expect(result.map((s) => s.shortcut), [';b']);
    });
  });
}
