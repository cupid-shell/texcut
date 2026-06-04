import '../models/snippet.dart';

/// Merges [incoming] (e.g. pulled from Drive) into [local] without losing
/// edits made on either side.
///
/// Strategy: union by shortcut, newest-wins. For a shortcut present on both
/// sides, the snippet with the later [Snippet.updatedAt] is kept; shortcuts
/// only on one side are preserved. This converges across devices far better
/// than blindly letting the incoming copy overwrite the local one.
///
/// Note: this is intentionally non-destructive — it does not propagate
/// deletions (that needs tombstones). A snippet deleted on one device can
/// reappear from another until deleted there too.
List<Snippet> mergeSnippets(List<Snippet> local, List<Snippet> incoming) {
  final byShortcut = <String, Snippet>{};
  for (final s in local) {
    byShortcut[s.shortcut] = s;
  }
  for (final r in incoming) {
    final existing = byShortcut[r.shortcut];
    if (existing == null || r.updatedAt.isAfter(existing.updatedAt)) {
      byShortcut[r.shortcut] = r;
    }
  }
  final result = byShortcut.values.toList()
    ..sort((a, b) =>
        a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
  return result;
}
