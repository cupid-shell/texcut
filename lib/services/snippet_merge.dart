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

/// A record that a snippet (identified by its [shortcut]) was deleted at
/// [deletedAt]. Tombstones travel with the synced library so a deletion on one
/// device propagates to the others instead of the snippet silently reappearing.
class Tombstone {
  const Tombstone({required this.shortcut, required this.deletedAt});

  final String shortcut;
  final DateTime deletedAt;

  Map<String, dynamic> toJson() => {
        'shortcut': shortcut,
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory Tombstone.fromJson(Map<String, dynamic> json) => Tombstone(
        shortcut: json['shortcut'] as String? ?? '',
        deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Unions two tombstone lists keeping the latest [Tombstone.deletedAt] per
/// shortcut, and drops entries older than [keepFor] so the list can't grow
/// forever (by then every device has long since applied the deletion).
List<Tombstone> mergeTombstones(
  List<Tombstone> a,
  List<Tombstone> b, {
  Duration keepFor = const Duration(days: 90),
  DateTime? now,
}) {
  final cutoff = (now ?? DateTime.now()).subtract(keepFor);
  final byShortcut = <String, Tombstone>{};
  for (final t in [...a, ...b]) {
    if (t.shortcut.isEmpty) continue;
    final existing = byShortcut[t.shortcut];
    if (existing == null || t.deletedAt.isAfter(existing.deletedAt)) {
      byShortcut[t.shortcut] = t;
    }
  }
  return byShortcut.values.where((t) => t.deletedAt.isAfter(cutoff)).toList();
}

/// Removes snippets that a tombstone says were deleted — unless the snippet was
/// (re)created/edited *after* the deletion, in which case the resurrection wins.
List<Snippet> applyTombstones(
    List<Snippet> snippets, List<Tombstone> tombstones) {
  if (tombstones.isEmpty) return snippets;
  final deletedAt = <String, DateTime>{};
  for (final t in tombstones) {
    final existing = deletedAt[t.shortcut];
    if (existing == null || t.deletedAt.isAfter(existing)) {
      deletedAt[t.shortcut] = t.deletedAt;
    }
  }
  return snippets.where((s) {
    final d = deletedAt[s.shortcut];
    return d == null || s.updatedAt.isAfter(d);
  }).toList();
}
