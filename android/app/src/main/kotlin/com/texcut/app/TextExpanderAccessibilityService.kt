package com.texcut.app

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
 *  4. If so, we replace the shortcut with its expansion.
 *
 * Replacement strategy — paste first, set-text as fallback:
 *  - Preferred: select the shortcut span and ACTION_PASTE the expansion. Paste
 *    travels through the app's normal input pipeline, firing its TextWatchers
 *    so the change is actually committed/saved. This fixes editors such as
 *    Google Keep that autosave from their own text model and would otherwise
 *    silently revert an ACTION_SET_TEXT change when you leave and return.
 *  - Fallback: ACTION_SET_TEXT on the whole field, for nodes that don't honour
 *    paste.
 *
 * A guard flag suppresses the echo events our own edit produces so we never
 * loop on ourselves.
 */
class TextExpanderAccessibilityService : AccessibilityService() {

    private val store by lazy { SnippetStore(this) }
    private val engine = ExpansionEngine()
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var selfEdit = false

    /** Last package we recorded, to avoid resolving the app label every keystroke. */
    private var lastSeenPkg: String? = null

    private fun recordSeenApp(pkg: String) {
        if (pkg.isEmpty() || pkg == lastSeenPkg) return
        lastSeenPkg = pkg
        val label = try {
            val pm = packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: Exception) {
            pkg
        }
        store.recordSeenApp(pkg, label)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) return

        if (selfEdit) {
            // This change is the result of our own edit; ignore it.
            selfEdit = false
            return
        }

        val settings = store.loadSettings()
        if (!settings.serviceEnabled) return

        val snippets = store.loadSnippets()
        if (snippets.isEmpty()) return

        val source = event.source ?: return
        if (!source.isEditable) return

        // Remember which app we're typing in (for the in-app exclusion picker),
        // then honour the pause switch and per-app exclusions.
        val pkg = event.packageName?.toString() ?: ""
        recordSeenApp(pkg)
        if (store.isPaused()) return
        if (pkg.isNotEmpty() && store.excludedApps().contains(pkg)) return

        val text = source.text?.toString() ?: return
        val cursor =
            if (source.textSelectionEnd in 0..text.length) {
                source.textSelectionEnd
            } else {
                text.length
            }

        val counter = store.getCounter()
        val result = engine.expand(
            text = text,
            cursor = cursor,
            snippets = snippets,
            settings = settings,
            clipboard = readClipboard(),
            counter = counter
        ) ?: return

        val applied = pasteExpansion(source, result) || setTextExpansion(source, result)
        if (applied) {
            store.bumpUsage(result.shortcut)
            if (result.usedCounter) store.setCounter(counter + 1)
            if (settings.hapticFeedback) vibrate()
        }
    }

    /**
     * Selects the shortcut span and pastes the expansion over it. Returns true
     * when the paste action was accepted by the node.
     */
    private fun pasteExpansion(
        node: AccessibilityNodeInfo,
        result: ExpansionResult
    ): Boolean {
        val clipboard =
            getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                ?: return false

        // Select just the shortcut text.
        val select = Bundle().apply {
            putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT,
                result.replaceStart
            )
            putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT,
                result.replaceEnd
            )
        }
        if (!node.performAction(
                AccessibilityNodeInfo.ACTION_SET_SELECTION, select)
        ) {
            return false
        }

        // Stash whatever the user had on the clipboard so we can restore it.
        val previousClip: ClipData? = try {
            clipboard.primaryClip
        } catch (e: Exception) {
            null
        }

        clipboard.setPrimaryClip(
            ClipData.newPlainText("texcut", result.insertText)
        )

        selfEdit = true
        val pasted = node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        if (!pasted) {
            selfEdit = false
            restoreClip(clipboard, previousClip)
            return false
        }

        // Place the caret (honours the {cursor} token) once paste settles, then
        // put the user's clipboard back.
        main.postDelayed({
            try {
                val caret = Bundle().apply {
                    putInt(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT,
                        result.cursor
                    )
                    putInt(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT,
                        result.cursor
                    )
                }
                node.performAction(
                    AccessibilityNodeInfo.ACTION_SET_SELECTION, caret)
            } catch (e: Exception) {
                // Caret repositioning is best-effort.
            }
            restoreClip(clipboard, previousClip)
        }, 120)

        return true
    }

    /** Whole-field replacement fallback for nodes that reject paste. */
    private fun setTextExpansion(
        node: AccessibilityNodeInfo,
        result: ExpansionResult
    ): Boolean {
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
            return false
        }
        val caret = Bundle().apply {
            putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT,
                result.cursor
            )
            putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT,
                result.cursor
            )
        }
        node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, caret)
        return true
    }

    private fun restoreClip(clipboard: ClipboardManager, clip: ClipData?) {
        try {
            if (clip != null) {
                clipboard.setPrimaryClip(clip)
            }
        } catch (e: Exception) {
            // Ignore — restoring the clipboard is best-effort.
        }
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
