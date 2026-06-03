import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expansion_settings.dart';
import '../models/snippet.dart';

/// Persists snippets and settings in [SharedPreferences] as JSON.
///
/// SharedPreferences is the deliberate storage choice here: the Flutter
/// `shared_preferences` plugin writes to the same `FlutterSharedPreferences`
/// file that the native [AccessibilityService] reads, so both sides share a
/// single source of truth with no extra IPC for the data itself.
///
/// NOTE: the plugin prefixes every key with `flutter.`, so the native side
/// reads e.g. `flutter.texcut.snippets`.
class SnippetRepository {
  SnippetRepository(this._prefs);

  static const String snippetsKey = 'texcut.snippets';
  static const String settingsKey = 'texcut.settings';

  final SharedPreferences _prefs;

  static Future<SnippetRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SnippetRepository(prefs);
  }

  List<Snippet> loadSnippets() {
    final raw = _prefs.getString(snippetsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Snippet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSnippets(List<Snippet> snippets) async {
    final raw = jsonEncode(snippets.map((s) => s.toJson()).toList());
    await _prefs.setString(snippetsKey, raw);
  }

  ExpansionSettings loadSettings() {
    final raw = _prefs.getString(settingsKey);
    if (raw == null || raw.isEmpty) return const ExpansionSettings();
    try {
      return ExpansionSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ExpansionSettings();
    }
  }

  Future<void> saveSettings(ExpansionSettings settings) async {
    await _prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  bool get isFirstRun => !_prefs.containsKey(snippetsKey);
}
