package com.texcut.app

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Describes how to apply an expansion to an editable field.
 *
 *  - [text]/[cursor] support the whole-field ACTION_SET_TEXT fallback.
 *  - [replaceStart]/[replaceEnd]/[insertText] support the preferred
 *    select-then-paste path, which only touches the shortcut span and flows
 *    through the app's normal input pipeline so changes are actually committed
 *    (apps like Google Keep autosave from their own text model and ignore
 *    ACTION_SET_TEXT).
 */
data class ExpansionResult(
    val text: String,
    val cursor: Int,
    val replaceStart: Int,
    val replaceEnd: Int,
    val insertText: String,
    val shortcut: String,
    val usedCounter: Boolean,
    val rawExpansion: String,
)

data class RenderedText(val text: String, val cursorOffset: Int?)

private data class Rendered(val text: String, val cursorOffset: Int?)

/**
 * Kotlin port of the Dart `Expander`. Kept deliberately in lock-step with
 * `lib/services/expander.dart` so that an expansion behaves identically whether
 * the user types inside the texcut app or anywhere else on the device.
 */
class ExpansionEngine {

    private val delimiters = setOf(
        ' ', '\n', '\t', '.', ',', ';', ':', '!', '?', ')', ']', '}', '"', '\''
    )

    fun expand(
        text: String,
        cursor: Int,
        snippets: List<Snippet>,
        settings: Settings,
        clipboard: String = "",
        now: Date = Date(),
        counter: Int = 0,
        inputs: Map<String, String> = emptyMap()
    ): ExpansionResult? {
        if (cursor < 0 || cursor > text.length) return null

        var head = text.substring(0, cursor)
        var trailing = ""

        if (settings.triggerMode == "onDelimiter") {
            if (head.isEmpty()) return null
            val last = head.last()
            if (!delimiters.contains(last)) return null
            trailing = last.toString()
            head = head.substring(0, head.length - 1)
        }

        val lookup = snippets.associate { it.shortcut to it.expansion }
        val candidates = snippets
            .filter { it.enabled && it.shortcut.isNotEmpty() }
            .sortedByDescending { it.shortcut.length }

        for (s in candidates) {
            val hay = if (settings.caseSensitive) head else head.lowercase()
            val needle =
                if (settings.caseSensitive) s.shortcut else s.shortcut.lowercase()
            if (!hay.endsWith(needle)) continue

            val matchStart = head.length - s.shortcut.length
            if (settings.requireWordBoundary && matchStart > 0) {
                val before = head[matchStart - 1]
                if (isWordChar(before) && isWordChar(s.shortcut[0])) continue
            }

            val rendered = render(s.expansion, settings, now, clipboard, lookup, inputs, counter, 0)
            val newText = head.substring(0, matchStart) +
                rendered.text + trailing + text.substring(cursor)
            val offset = rendered.cursorOffset ?: rendered.text.length
            // The shortcut span to select/replace is [matchStart, cursor minus
            // the trailing delimiter] = [matchStart, matchStart + shortcutLen].
            val replaceEnd = matchStart + s.shortcut.length
            return ExpansionResult(
                text = newText,
                cursor = matchStart + offset,
                replaceStart = matchStart,
                replaceEnd = replaceEnd,
                insertText = rendered.text,
                shortcut = s.shortcut,
                usedCounter = s.expansion.contains("{counter}", ignoreCase = true),
                rawExpansion = s.expansion,
            )
        }
        return null
    }

    private fun isWordChar(c: Char): Boolean =
        c in '0'..'9' || c in 'A'..'Z' || c in 'a'..'z'

    /** Ordered, de-duplicated {input:Label} field labels found in [body]. */
    fun inputLabels(body: String): List<String> {
        val labels = mutableListOf<String>()
        Regex("\\{input:([^}]*)\\}", RegexOption.IGNORE_CASE).findAll(body).forEach {
            val label = it.groupValues[1].trim()
            if (label.isNotEmpty() && !labels.contains(label)) labels.add(label)
        }
        return labels
    }

    /** Public render used to re-render a body once fill-in values are known. */
    fun renderText(
        body: String,
        settings: Settings,
        now: Date,
        clipboard: String,
        snippets: Map<String, String>,
        counter: Int,
        inputs: Map<String, String>
    ): RenderedText {
        val r = render(body, settings, now, clipboard, snippets, inputs, counter, 0)
        return RenderedText(r.text, r.cursorOffset)
    }

    private fun render(
        body: String,
        settings: Settings,
        now: Date,
        clipboard: String,
        snippets: Map<String, String>,
        inputs: Map<String, String>,
        counter: Int,
        depth: Int
    ): Rendered {
        val sb = StringBuilder()
        var cursorOffset: Int? = null
        var i = 0
        while (i < body.length) {
            val c = body[i]

            if (c == '{' && i + 1 < body.length && body[i + 1] == '{') {
                sb.append('{'); i += 2; continue
            }
            if (c == '}' && i + 1 < body.length && body[i + 1] == '}') {
                sb.append('}'); i += 2; continue
            }

            if (c == '{') {
                val end = body.indexOf('}', i + 1)
                if (end != -1) {
                    val token = body.substring(i + 1, end).trim()
                    val resolved =
                        resolveToken(token, settings, now, clipboard, snippets, inputs, counter, depth)
                    when {
                        resolved.isCursor -> cursorOffset = sb.length
                        resolved.handled -> sb.append(resolved.value)
                        else -> sb.append(body.substring(i, end + 1))
                    }
                    i = end + 1
                    continue
                }
            }

            sb.append(c)
            i++
        }
        return Rendered(sb.toString(), cursorOffset)
    }

    private data class TokenResult(
        val value: String,
        val handled: Boolean,
        val isCursor: Boolean
    )

    private val dateTokenRegex =
        Regex("^(date|time|datetime)([+-]\\d+(?:y|mo|w|d|h|m))?(?::(.*))?$",
            RegexOption.IGNORE_CASE)
    private val offsetRegex = Regex("^([+-])(\\d+)(y|mo|w|d|h|m)$")

    private fun resolveToken(
        token: String,
        settings: Settings,
        now: Date,
        clipboard: String,
        snippets: Map<String, String>,
        inputs: Map<String, String>,
        counter: Int,
        depth: Int
    ): TokenResult {
        val lower = token.lowercase()
        if (lower == "cursor") return TokenResult("", handled = true, isCursor = true)
        if (lower == "clipboard") return TokenResult(clipboard, handled = true, isCursor = false)
        if (lower == "counter") return TokenResult(counter.toString(), handled = true, isCursor = false)

        if (lower.startsWith("input:")) {
            val label = token.substring(token.indexOf(':') + 1).trim()
            return TokenResult(inputs[label] ?: "[$label]", handled = true, isCursor = false)
        }

        if (lower.startsWith("snippet:") || lower.startsWith("s:")) {
            val shortcut = token.substring(token.indexOf(':') + 1).trim()
            val nestedBody = snippets[shortcut]
            if (nestedBody == null || depth >= 5) {
                return TokenResult("", handled = false, isCursor = false)
            }
            val nested = render(nestedBody, settings, now, clipboard, snippets, inputs, counter, depth + 1)
            return TokenResult(nested.text, handled = true, isCursor = false)
        }

        val m = dateTokenRegex.find(token)
        if (m != null) {
            val name = m.groupValues[1].lowercase()
            val when_ = shift(now, m.groupValues[2])
            val pattern = m.groupValues[3]
            try {
                if (pattern.isNotEmpty()) {
                    return TokenResult(format(pattern, when_), handled = true, isCursor = false)
                }
                val value = when (name) {
                    "date" -> format(settings.dateFormat, when_)
                    "time" -> format(settings.timeFormat, when_)
                    else -> format(settings.dateFormat, when_) + " " + format(settings.timeFormat, when_)
                }
                return TokenResult(value, handled = true, isCursor = false)
            } catch (e: Exception) {
                return TokenResult("", handled = false, isCursor = false)
            }
        }
        return TokenResult("", handled = false, isCursor = false)
    }

    private fun shift(base: Date, offset: String): Date {
        if (offset.isEmpty()) return base
        val m = offsetRegex.find(offset) ?: return base
        val sign = if (m.groupValues[1] == "-") -1 else 1
        val amount = sign * m.groupValues[2].toInt()
        val cal = Calendar.getInstance().apply { time = base }
        when (m.groupValues[3]) {
            "y" -> cal.add(Calendar.YEAR, amount)
            "mo" -> cal.add(Calendar.MONTH, amount)
            "w" -> cal.add(Calendar.WEEK_OF_YEAR, amount)
            "d" -> cal.add(Calendar.DAY_OF_MONTH, amount)
            "h" -> cal.add(Calendar.HOUR_OF_DAY, amount)
            "m" -> cal.add(Calendar.MINUTE, amount)
        }
        return cal.time
    }

    private fun format(pattern: String, date: Date): String =
        SimpleDateFormat(pattern, Locale.getDefault()).format(date)
}
