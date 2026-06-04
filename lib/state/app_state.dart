import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/expansion_settings.dart';
import '../models/snippet.dart';
import '../services/native_bridge.dart';
import '../services/seed_data.dart';
import '../services/snippet_merge.dart';
import '../services/snippet_repository.dart';

/// Central, observable application state. Owns the snippet list and settings,
/// persists every change, and keeps the native service in sync.
class AppState extends ChangeNotifier {
  AppState({
    required SnippetRepository repository,
    NativeBridge? bridge,
  })  : _repo = repository,
        _bridge = bridge ?? NativeBridge();

  final SnippetRepository _repo;
  final NativeBridge _bridge;

  /// Invoked after any snippet/settings change is persisted, so an external
  /// syncer (e.g. Google Drive) can push the latest data. Set by the sync
  /// layer; null when sync is off.
  VoidCallback? onDataChanged;

  List<Snippet> _snippets = [];
  ExpansionSettings _settings = const ExpansionSettings();
  bool _serviceConnected = false;
  bool _paused = false;
  bool _overlayGranted = false;
  bool _onboarded = false;
  List<String> _excludedApps = [];

  bool get needsOnboarding => !_onboarded;
  String _query = '';
  String? _groupFilter;

  bool get paused => _paused;
  bool get overlayGranted => _overlayGranted;
  List<String> get excludedApps => List.unmodifiable(_excludedApps);

  List<Snippet> get snippets => List.unmodifiable(_snippets);
  ExpansionSettings get settings => _settings;
  bool get serviceConnected => _serviceConnected;
  String get query => _query;

  /// The currently selected group filter, or null for "All".
  String? get groupFilter => _groupFilter;

  int get totalCount => _snippets.length;
  int get enabledCount => _snippets.where((s) => s.enabled).length;

  /// Snippets filtered by the current search query and group filter,
  /// ordered with pinned items first then by the chosen sort mode.
  List<Snippet> get visibleSnippets {
    final q = _query.trim().toLowerCase();
    final list = _snippets.where((s) {
      if (_groupFilter != null && s.group != _groupFilter) return false;
      if (q.isEmpty) return true;
      return s.shortcut.toLowerCase().contains(q) ||
          s.expansion.toLowerCase().contains(q) ||
          s.label.toLowerCase().contains(q) ||
          s.group.toLowerCase().contains(q);
    }).toList();
    list.sort(_compare);
    return list;
  }

  int _compare(Snippet a, Snippet b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    switch (_settings.sortMode) {
      case SortMode.mostUsed:
        final c = b.usageCount.compareTo(a.usageCount);
        if (c != 0) return c;
        break;
      case SortMode.recentlyUsed:
        final at = a.lastUsedAt, bt = b.lastUsedAt;
        if (at == null && bt != null) return 1;
        if (at != null && bt == null) return -1;
        if (at != null && bt != null) {
          final c = bt.compareTo(at);
          if (c != 0) return c;
        }
        break;
      case SortMode.alphabetical:
        break;
    }
    return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
  }

  /// Visible snippets bucketed by group, with group names sorted A→Z.
  Map<String, List<Snippet>> get visibleByGroup {
    final map = <String, List<Snippet>>{};
    for (final s in visibleSnippets) {
      map.putIfAbsent(s.group, () => []).add(s);
    }
    return Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) =>
            a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
  }

  List<String> get groups {
    final set = _snippets.map((s) => s.group).toSet().toList()..sort();
    return set;
  }

  void setGroupFilter(String? group) {
    _groupFilter = group;
    notifyListeners();
  }

  Future<void> load() async {
    _settings = _repo.loadSettings();
    if (_repo.isFirstRun) {
      _snippets = seedSnippets();
      await _repo.saveSnippets(_snippets);
    } else {
      _snippets = _repo.loadSnippets();
    }
    _paused = _repo.loadPaused();
    _excludedApps = _repo.loadExcludedApps();
    _onboarded = _repo.loadOnboarded();
    await refreshServiceStatus();
    notifyListeners();
  }

  Future<void> markOnboarded() async {
    _onboarded = true;
    await _repo.saveOnboarded(true);
    notifyListeners();
  }

  /// Adds [incoming] snippets, giving each a fresh id and a unique shortcut
  /// (appending a number on clashes). Returns how many were added.
  Future<int> addSnippets(List<Snippet> incoming) async {
    for (final s in incoming) {
      var shortcut = s.shortcut;
      var n = 1;
      while (_snippets.any((e) => e.shortcut == shortcut)) {
        n++;
        shortcut = '${s.shortcut}$n';
      }
      _snippets.add(Snippet(
        id: Snippet.newId(),
        shortcut: shortcut,
        expansion: s.expansion,
        label: s.label,
        group: s.group,
      ));
    }
    await _persistSnippets();
    return incoming.length;
  }

  Future<void> refreshServiceStatus() async {
    _serviceConnected = await _bridge.isAccessibilityServiceEnabled();
    _overlayGranted = await _bridge.canDrawOverlays();
    // The Quick Settings tile may have toggled pause while backgrounded.
    _paused = _repo.loadPaused();
    notifyListeners();
  }

  /// Opens the "Display over other apps" settings (for the fill-in prompt).
  Future<void> openOverlaySettings() => _bridge.openOverlaySettings();

  Future<void> setPaused(bool value) async {
    _paused = value;
    await _repo.savePaused(value);
    notifyListeners();
  }

  /// Reloads prefs from disk (to pick up natively-written values) and returns
  /// the apps the service has seen the user type in.
  Future<List<SeenApp>> refreshSeenApps() async {
    await _repo.reload();
    _excludedApps = _repo.loadExcludedApps();
    _paused = _repo.loadPaused();
    notifyListeners();
    return _repo.loadSeenApps();
  }

  Future<void> setAppExcluded(String packageName, bool excluded) async {
    final set = {..._excludedApps};
    if (excluded) {
      set.add(packageName);
    } else {
      set.remove(packageName);
    }
    _excludedApps = set.toList()..sort();
    await _repo.saveExcludedApps(_excludedApps);
    notifyListeners();
  }

  Future<void> openSystemSettings() => _bridge.openAccessibilitySettings();

  /// Opens texcut's App info page (for the Android 13+ "Allow restricted
  /// settings" step).
  Future<void> openAppSettings() => _bridge.openAppSettings();

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  Snippet? snippetById(String id) {
    for (final s in _snippets) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> upsert(Snippet snippet) async {
    final index = _snippets.indexWhere((s) => s.id == snippet.id);
    if (index >= 0) {
      _snippets[index] = snippet;
    } else {
      _snippets.add(snippet);
    }
    await _persistSnippets();
  }

  Future<void> delete(String id) async {
    _snippets.removeWhere((s) => s.id == id);
    await _persistSnippets();
  }

  Future<void> toggleEnabled(String id, bool enabled) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _snippets[index] = _snippets[index].copyWith(enabled: enabled);
    await _persistSnippets();
  }

  Future<void> togglePin(String id) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _snippets[index] =
        _snippets[index].copyWith(pinned: !_snippets[index].pinned);
    await _persistSnippets();
  }

  /// Creates a copy of [snippet] with a fresh id and a unique shortcut.
  Future<void> duplicate(Snippet snippet) async {
    var newShortcut = '${snippet.shortcut}2';
    var n = 2;
    while (_snippets.any((s) => s.shortcut == newShortcut)) {
      n++;
      newShortcut = '${snippet.shortcut}$n';
    }
    _snippets.add(Snippet(
      id: Snippet.newId(),
      shortcut: newShortcut,
      expansion: snippet.expansion,
      label: snippet.label,
      group: snippet.group,
      enabled: snippet.enabled,
    ));
    await _persistSnippets();
  }

  Future<void> setSortMode(SortMode mode) async {
    await updateSettings(_settings.copyWith(sortMode: mode));
  }

  // ---- Bulk actions over a set of snippet ids ----

  Future<void> deleteMany(Set<String> ids) async {
    _snippets.removeWhere((s) => ids.contains(s.id));
    await _persistSnippets();
  }

  Future<void> setEnabledMany(Set<String> ids, bool enabled) async {
    for (var i = 0; i < _snippets.length; i++) {
      if (ids.contains(_snippets[i].id)) {
        _snippets[i] = _snippets[i].copyWith(enabled: enabled);
      }
    }
    await _persistSnippets();
  }

  Future<void> setPinnedMany(Set<String> ids, bool pinned) async {
    for (var i = 0; i < _snippets.length; i++) {
      if (ids.contains(_snippets[i].id)) {
        _snippets[i] = _snippets[i].copyWith(pinned: pinned);
      }
    }
    await _persistSnippets();
  }

  Future<void> moveMany(Set<String> ids, String group) async {
    final g = group.trim().isEmpty ? 'General' : group.trim();
    for (var i = 0; i < _snippets.length; i++) {
      if (ids.contains(_snippets[i].id)) {
        _snippets[i] = _snippets[i].copyWith(group: g);
      }
    }
    await _persistSnippets();
  }

  Future<void> recordUsage(String id) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _snippets[index] =
        _snippets[index].copyWith(usageCount: _snippets[index].usageCount + 1);
    await _persistSnippets();
  }

  Future<void> updateSettings(ExpansionSettings settings) async {
    _settings = settings;
    await _repo.saveSettings(settings);
    await _bridge.notifyDataChanged();
    onDataChanged?.call();
    notifyListeners();
  }

  /// Replaces all snippets/settings from synced data without re-triggering an
  /// upstream push (used when applying data pulled from Drive).
  Future<void> applySyncedData(String rawJson) async {
    final doc = jsonDecode(rawJson) as Map<String, dynamic>;
    final incoming = (doc['snippets'] as List<dynamic>)
        .map((e) => Snippet.fromJson(e as Map<String, dynamic>))
        .toList();
    // Newest-wins union so edits on either device survive.
    _snippets = mergeSnippets(_snippets, incoming);
    await _persistSnippets(silent: true);
  }

  /// Serialises the whole library to a JSON document for backup / sharing.
  String exportToJson() {
    final doc = {
      'app': 'texcut',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _settings.toJson(),
      'snippets': _snippets.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  /// Imports a previously exported document.
  ///
  /// When [merge] is true, snippets are added/updated by shortcut; otherwise the
  /// existing library is replaced. Returns the number of snippets imported.
  Future<int> importFromJson(String raw,
      {bool merge = true, bool silent = false}) async {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final incoming = (doc['snippets'] as List<dynamic>)
        .map((e) => Snippet.fromJson(e as Map<String, dynamic>))
        .toList();

    if (!merge) {
      _snippets = incoming;
    } else {
      for (final s in incoming) {
        final index =
            _snippets.indexWhere((e) => e.shortcut == s.shortcut);
        if (index >= 0) {
          _snippets[index] = s.copyWith();
        } else {
          _snippets.add(s);
        }
      }
    }

    if (doc['settings'] is Map<String, dynamic>) {
      _settings = ExpansionSettings.fromJson(
          doc['settings'] as Map<String, dynamic>);
      await _repo.saveSettings(_settings);
    }
    await _persistSnippets(silent: silent);
    return incoming.length;
  }

  Future<void> _persistSnippets({bool silent = false}) async {
    await _repo.saveSnippets(_snippets);
    if (!silent) onDataChanged?.call();
    await _bridge.notifyDataChanged();
    notifyListeners();
  }
}
