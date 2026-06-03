package com.texcut.app

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Where to put the text and caret after a shortcut fires. */
data class ExpansionResult(val text: String, val cursor: Int)

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
        now: Date = Date()
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

            val rendered = render(s.expansion, settings, now, clipboard)
            val newText = head.substring(0, matchStart) +
                rendered.text + trailing + text.substring(cursor)
            val offset = rendered.cursorOffset ?: rendered.text.length
            return ExpansionResult(newText, matchStart + offset)
        }
        return null
    }

    private fun isWordChar(c: Char): Boolean =
        c in '0'..'9' || c in 'A'..'Z' || c in 'a'..'z'

    private fun render(
        body: String,
        settings: Settings,
        now: Date,
        clipboard: String
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
                    val resolved = resolveToken(token, settings, now, clipboard)
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

    private fun resolveToken(
        token: String,
        settings: Settings,
        now: Date,
        clipboard: String
    ): TokenResult {
        val lower = token.lowercase()
        return when {
            lower == "cursor" -> TokenResult("", handled = true, isCursor = true)
            lower == "clipboard" -> TokenResult(clipboard, handled = true, isCursor = false)
            lower == "date" -> TokenResult(format(settings.dateFormat, now), true, false)
            lower == "time" -> TokenResult(format(settings.timeFormat, now), true, false)
            lower == "datetime" -> TokenResult(
                format(settings.dateFormat, now) + " " + format(settings.timeFormat, now),
                handled = true, isCursor = false
            )
            lower.startsWith("date:") -> {
                val pattern = token.substring(token.indexOf(':') + 1)
                try {
                    TokenResult(format(pattern, now), handled = true, isCursor = false)
                } catch (e: Exception) {
                    TokenResult("", handled = false, isCursor = false)
                }
            }
            else -> TokenResult("", handled = false, isCursor = false)
        }
    }

    private fun format(pattern: String, date: Date): String =
        SimpleDateFormat(pattern, Locale.getDefault()).format(date)
}
