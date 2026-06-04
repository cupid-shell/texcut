import 'package:flutter_test/flutter_test.dart';
import 'package:texcut/models/snippet.dart';
import 'package:texcut/services/snippet_merge.dart';

void main() {
  Snippet s(String shortcut, String expansion, DateTime updated) => Snippet(
        id: shortcut,
        shortcut: shortcut,
        expansion: expansion,
        updatedAt: updated,
      );

  final t1 = DateTime(2026, 1, 1);
  final t2 = DateTime(2026, 2, 1);

  group('mergeSnippets', () {
    test('keeps shortcuts unique to each side', () {
      final local = [s(';a', 'A', t1)];
      final incoming = [s(';b', 'B', t1)];
      final merged = mergeSnippets(local, incoming);
      expect(merged.map((e) => e.shortcut).toSet(), {';a', ';b'});
    });

    test('newer incoming overwrites older local', () {
      final local = [s(';a', 'old', t1)];
      final incoming = [s(';a', 'new', t2)];
      final merged = mergeSnippets(local, incoming);
      expect(merged.single.expansion, 'new');
    });

    test('older incoming does not clobber newer local', () {
      final local = [s(';a', 'localnew', t2)];
      final incoming = [s(';a', 'remoteold', t1)];
      final merged = mergeSnippets(local, incoming);
      expect(merged.single.expansion, 'localnew');
    });

    test('union does not duplicate a shared shortcut', () {
      final local = [s(';a', 'A', t1), s(';b', 'B', t1)];
      final incoming = [s(';a', 'A2', t2), s(';c', 'C', t1)];
      final merged = mergeSnippets(local, incoming);
      expect(merged.length, 3);
      expect(merged.firstWhere((e) => e.shortcut == ';a').expansion, 'A2');
    });
  });
}
