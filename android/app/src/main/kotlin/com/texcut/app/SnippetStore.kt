package com.texcut.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** A single expansion rule, mirroring the Dart `Snippet` model. */
data class Snippet(
    val shortcut: String,
    val expansion: String,
    val enabled: Boolean
)

/** Trigger behaviour shared with the Flutter UI. */
data class Settings(
    val serviceEnabled: Boolean = true,
    val triggerMode: String = "onDelimiter",
    val requireWordBoundary: Boolean = true,
    val caseSensitive: Boolean = true,
    val hapticFeedback: Boolean = true,
    val dateFormat: String = "yyyy-MM-dd",
    val timeFormat: String = "HH:mm"
)

/**
 * Reads snippets and settings straight from the same `SharedPreferences` file
 * that the Flutter `shared_preferences` plugin writes to.
 *
 * The plugin stores everything under the `FlutterSharedPreferences` file and
 * prefixes each key with `flutter.`, so the keys saved by Dart as
 * `texcut.snippets` / `texcut.settings` are read here as
 * `flutter.texcut.snippets` / `flutter.texcut.settings`.
 */
class SnippetStore(context: Context) {

    private val prefs =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun loadSnippets(): List<Snippet> {
        val raw = prefs.getString(KEY_SNIPPETS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val o = array.optJSONObject(i) ?: return@mapNotNull null
                Snippet(
                    shortcut = o.optString("shortcut", ""),
                    expansion = o.optString("expansion", ""),
                    enabled = o.optBoolean("enabled", true)
                )
            }.filter { it.shortcut.isNotEmpty() }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun loadSettings(): Settings {
        val raw = prefs.getString(KEY_SETTINGS, null) ?: return Settings()
        return try {
            val o = JSONObject(raw)
            Settings(
                serviceEnabled = o.optBoolean("serviceEnabled", true),
                triggerMode = o.optString("triggerMode", "onDelimiter"),
                requireWordBoundary = o.optBoolean("requireWordBoundary", true),
                caseSensitive = o.optBoolean("caseSensitive", true),
                hapticFeedback = o.optBoolean("hapticFeedback", true),
                dateFormat = o.optString("dateFormat", "yyyy-MM-dd"),
                timeFormat = o.optString("timeFormat", "HH:mm")
            )
        } catch (e: Exception) {
            Settings()
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SNIPPETS = "flutter.texcut.snippets"
        private const val KEY_SETTINGS = "flutter.texcut.settings"
    }
}
