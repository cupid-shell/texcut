import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/expansion_settings.dart';
import '../models/snippet.dart';
import '../services/native_bridge.dart';
import '../services/seed_data.dart';
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

  List<Snippet> _snippets = [];
  ExpansionSettings _settings = const ExpansionSettings();
  bool _serviceConnected = false;
  String _query = '';

  List<Snippet> get snippets => List.unmodifiable(_snippets);
  ExpansionSettings get settings => _settings;
  bool get serviceConnected => _serviceConnected;
  String get query => _query;

  /// Snippets filtered by the current search query.
  List<Snippet> get visibleSnippets {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? _snippets
        : _snippets.where((s) {
            return s.shortcut.toLowerCase().contains(q) ||
                s.expansion.toLowerCase().contains(q) ||
                s.label.toLowerCase().contains(q) ||
                s.group.toLowerCase().contains(q);
          }).toList();
    final sorted = [...list]
      ..sort((a, b) =>
          a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
    return sorted;
  }

  List<String> get groups {
    final set = _snippets.map((s) => s.group).toSet().toList()..sort();
    return set;
  }

  Future<void> load() async {
    _settings = _repo.loadSettings();
    if (_repo.isFirstRun) {
      _snippets = seedSnippets();
      await _repo.saveSnippets(_snippets);
    } else {
      _snippets = _repo.loadSnippets();
    }
    await refreshServiceStatus();
    notifyListeners();
  }

  Future<void> refreshServiceStatus() async {
    _serviceConnected = await _bridge.isAccessibilityServiceEnabled();
    notifyListeners();
  }

  Future<void> openSystemSettings() => _bridge.openAccessibilitySettings();

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
    notifyListeners();
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
  Future<int> importFromJson(String raw, {bool merge = true}) async {
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
    await _persistSnippets();
    return incoming.length;
  }

  Future<void> _persistSnippets() async {
    await _repo.saveSnippets(_snippets);
    await _bridge.notifyDataChanged();
    notifyListeners();
  }
}
