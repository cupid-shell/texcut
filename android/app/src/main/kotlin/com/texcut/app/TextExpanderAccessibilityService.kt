package com.texcut.app

import android.accessibilityservice.AccessibilityService
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Watches text fields across the whole device and rewrites a typed shortcut
 * into its expansion the moment it is recognised.
 *
 * Flow per keystroke:
 *  1. Android delivers a TYPE_VIEW_TEXT_CHANGED event for the focused field.
 *  2. We read the field's current text and caret position.
 *  3. [ExpansionEngine] decides whether a shortcut just completed.
 *  4. If so, we replace the entire field text (ACTION_SET_TEXT) and reposition
 *     the caret (ACTION_SET_SELECTION).
 *
 * A guard flag suppresses the echo event our own edit produces so we never
 * loop on ourselves.
 */
class TextExpanderAccessibilityService : AccessibilityService() {

    private val store by lazy { SnippetStore(this) }
    private val engine = ExpansionEngine()

    @Volatile
    private var selfEdit = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) return

        if (selfEdit) {
            // This change is the result of our own ACTION_SET_TEXT; ignore it.
            selfEdit = false
            return
        }

        val settings = store.loadSettings()
        if (!settings.serviceEnabled) return

        val snippets = store.loadSnippets()
        if (snippets.isEmpty()) return

        val source = event.source ?: return
        if (!source.isEditable) return

        val text = source.text?.toString() ?: return
        val cursor =
            if (source.textSelectionEnd in 0..text.length) {
                source.textSelectionEnd
            } else {
                text.length
            }

        val result = engine.expand(
            text = text,
            cursor = cursor,
            snippets = snippets,
            settings = settings,
            clipboard = readClipboard()
        ) ?: return

        applyExpansion(source, result, settings)
    }

    private fun applyExpansion(
        node: AccessibilityNodeInfo,
        result: ExpansionResult,
        settings: Settings
    ) {
        val setText = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                result.text
            )
        }

        selfEdit = true
        val ok = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, setText)
        if (!ok) {
            selfEdit = false
            return
        }

        val setSelection = Bundle().apply {
            putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT,
                result.cursor
            )
            putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT,
                result.cursor
            )
        }
        node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, setSelection)

        if (settings.hapticFeedback) vibrate()
    }

    /**
     * Clipboard reads only succeed for foreground/IME/default apps on Android
     * 10+. We attempt it for the {clipboard} token and quietly fall back to an
     * empty string when the platform denies access.
     */
    private fun readClipboard(): String {
        return try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            cm?.primaryClip?.takeIf { it.itemCount > 0 }
                ?.getItemAt(0)
                ?.coerceToText(this)
                ?.toString()
                ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrate() {
        try {
            val vibrator: Vibrator? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                        as? VibratorManager
                    manager?.defaultVibrator
                } else {
                    getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                }
            vibrator?.vibrate(
                VibrationEffect.createOneShot(15, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        } catch (e: Exception) {
            // Vibration is a nicety; never let it crash an expansion.
        }
    }

    override fun onInterrupt() {
        // No long-running work to interrupt.
    }
}
