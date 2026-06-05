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
import java.util.Date

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

    @Volatile
    private var launcherOpen = false

    /** Last package we recorded, to avoid resolving the app label every keystroke. */
    private var lastSeenPkg: String? = null
    private var lastAppLabel: String = ""

    private fun recordSeenApp(pkg: String) {
        if (pkg.isEmpty() || pkg == lastSeenPkg) return
        lastSeenPkg = pkg
        val label = try {
            val pm = packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: Exception) {
            pkg
        }
        lastAppLabel = label
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

        // Quick-search launcher: typing the trigger (e.g. ";;") opens a
        // floating snippet search instead of expanding a shortcut.
        if (settings.launcherEnabled && settings.launcherTrigger.isNotEmpty() &&
            !launcherOpen && text.substring(0, cursor).endsWith(settings.launcherTrigger)
        ) {
            showLauncher(snippets, settings, source)
            return
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

        val labels = engine.inputLabels(result.rawExpansion)
        if (labels.isEmpty()) {
            // No fill-in fields: paste the rendered text directly.
            val applied = pasteInto(source, result.replaceStart, result.replaceEnd,
                result.insertText, result.cursor) ||
                setTextWhole(source, result.text, result.cursor)
            if (applied) recordSuccess(result, counter, settings)
            return
        }

        if (FillOverlay.canShow(this)) {
            // Prompt for the fields in a floating window. Because that window
            // takes focus, we wait for focus to return to the target field,
            // then RE-DETECT the shortcut on the live node and paste — this
            // avoids pasting into a stale/blurred node.
            val clip = readClipboard()
            FillOverlay(this).show(labels) { values ->
                if (values == null) return@show
                main.postDelayed({
                    applyFilledExpansion(snippets, settings, counter, clip, values, result, source)
                }, 350)
            }
        } else {
            // Without overlay permission, paste with [Label] placeholders so the
            // user can fill them in by hand.
            val applied = pasteInto(source, result.replaceStart, result.replaceEnd,
                result.insertText, result.cursor)
            if (applied) recordSuccess(result, counter, settings)
        }
    }

    /**
     * Re-acquires the focused editable field after the fill-in overlay closes
     * and applies the expansion with the collected [values]. Re-detecting on
     * the live node makes this robust to focus changes and any text shifts.
     */
    private fun applyFilledExpansion(
        snippets: List<Snippet>,
        settings: Settings,
        counter: Int,
        clip: String,
        values: Map<String, String>,
        original: ExpansionResult,
        fallbackNode: AccessibilityNodeInfo
    ) {
        val node = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: fallbackNode.also { it.refresh() }
        val text = node.text?.toString()
        if (text != null) {
            val cursorPos =
                if (node.textSelectionEnd in 0..text.length) node.textSelectionEnd
                else text.length
            val r = engine.expand(text, cursorPos, snippets, settings, clip, Date(), counter, values)
            if (r != null) {
                val applied = pasteInto(node, r.replaceStart, r.replaceEnd, r.insertText, r.cursor) ||
                    setTextWhole(node, r.text, r.cursor)
                if (applied) recordSuccess(r, counter, settings)
                return
            }
        }
        // Fallback: the field text was unchanged, so reuse the original span.
        val lookup = snippets.associate { it.shortcut to it.expansion }
        val rr = engine.renderText(
            original.rawExpansion, settings, Date(), clip, lookup, counter, values)
        val caret = original.replaceStart + (rr.cursorOffset ?: rr.text.length)
        val applied = pasteInto(
            node, original.replaceStart, original.replaceEnd, rr.text, caret)
        if (applied) recordSuccess(original, counter, settings)
    }

    /** Opens the quick-search launcher; on choice, inserts over the trigger. */
    private fun showLauncher(
        snippets: List<Snippet>,
        settings: Settings,
        fallback: AccessibilityNodeInfo
    ) {
        if (!FillOverlay.canShow(this)) return
        launcherOpen = true
        LauncherOverlay(this).show(snippets, store.loadClips()) { chosen, clip ->
            launcherOpen = false
            if (clip != null) {
                main.postDelayed({ insertLiteral(clip, settings, fallback) }, 300)
                return@show
            }
            if (chosen == null) return@show
            val labels = engine.inputLabels(chosen.expansion)
            if (labels.isEmpty()) {
                main.postDelayed({
                    insertChosen(chosen, emptyMap(), settings, fallback)
                }, 300)
            } else {
                FillOverlay(this).show(labels) { values ->
                    if (values == null) return@show
                    main.postDelayed({
                        insertChosen(chosen, values, settings, fallback)
                    }, 300)
                }
            }
        }
    }

    /** Replaces the launcher trigger with a clip's text, inserted literally. */
    private fun insertLiteral(
        text: String,
        settings: Settings,
        fallback: AccessibilityNodeInfo
    ) {
        val node = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: fallback.also { it.refresh() }
        val current = node.text?.toString() ?: return
        val caret = if (node.textSelectionEnd in 0..current.length)
            node.textSelectionEnd else current.length
        val trig = settings.launcherTrigger
        var start = caret - trig.length
        var end = caret
        if (start < 0 || current.substring(start.coerceAtLeast(0), end) != trig) {
            start = caret
            end = caret
        }
        if (pasteInto(node, start, end, text, start + text.length)) {
            store.addHistory("clip", lastAppLabel)
            if (settings.hapticFeedback) vibrate()
        }
    }

    /** Replaces the launcher trigger with [chosen]'s rendered expansion. */
    private fun insertChosen(
        chosen: Snippet,
        values: Map<String, String>,
        settings: Settings,
        fallback: AccessibilityNodeInfo
    ) {
        val node = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: fallback.also { it.refresh() }
        val text = node.text?.toString() ?: return
        val caret = if (node.textSelectionEnd in 0..text.length)
            node.textSelectionEnd else text.length
        val trig = settings.launcherTrigger
        // Replace the trigger if it's right before the caret; otherwise insert.
        var start = caret - trig.length
        var end = caret
        if (start < 0 || text.substring(start.coerceAtLeast(0), end) != trig) {
            start = caret
            end = caret
        }
        val counter = store.getCounter()
        val lookup = store.loadSnippets().associate { it.shortcut to it.expansion }
        val r = engine.renderText(
            chosen.expansion, settings, Date(), readClipboard(), lookup, counter, values)
        val caretFinal = start + (r.cursorOffset ?: r.text.length)
        val applied = pasteInto(node, start, end, r.text, caretFinal)
        if (applied) {
            store.bumpUsage(chosen.shortcut)
            store.addHistory(chosen.shortcut, lastAppLabel)
            if (chosen.expansion.contains("{counter}", ignoreCase = true)) {
                store.setCounter(counter + 1)
            }
            if (settings.hapticFeedback) vibrate()
        }
    }

    private fun recordSuccess(result: ExpansionResult, counter: Int, settings: Settings) {
        store.bumpUsage(result.shortcut)
        store.addHistory(result.shortcut, lastAppLabel)
        if (result.usedCounter) store.setCounter(counter + 1)
        if (settings.hapticFeedback) vibrate()
    }

    /**
     * Selects [start, end] in [node] and pastes [insertText] over it, then
     * positions the caret at [caret]. Paste travels through the app's normal
     * input pipeline so the change is committed.
     */
    private fun pasteInto(
        node: AccessibilityNodeInfo,
        start: Int,
        end: Int,
        insertText: String,
        caret: Int
    ): Boolean {
        val clipboard =
            getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                ?: return false

        val select = Bundle().apply {
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, start)
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, end)
        }
        if (!node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, select)) {
            return false
        }

        val previousClip: ClipData? = try {
            clipboard.primaryClip
        } catch (e: Exception) {
            null
        }
        clipboard.setPrimaryClip(ClipData.newPlainText("texcut", insertText))

        selfEdit = true
        val pasted = node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        if (!pasted) {
            selfEdit = false
            restoreClip(clipboard, previousClip)
            return false
        }

        main.postDelayed({
            try {
                val c = Bundle().apply {
                    putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, caret)
                    putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, caret)
                }
                node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, c)
            } catch (e: Exception) {
                // Caret repositioning is best-effort.
            }
            restoreClip(clipboard, previousClip)
        }, 120)

        return true
    }

    /** Whole-field replacement fallback for nodes that reject paste. */
    private fun setTextWhole(
        node: AccessibilityNodeInfo,
        fullText: String,
        caret: Int
    ): Boolean {
        val setText = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, fullText)
        }
        selfEdit = true
        val ok = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, setText)
        if (!ok) {
            selfEdit = false
            return false
        }
        val c = Bundle().apply {
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, caret)
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, caret)
        }
        node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, c)
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
