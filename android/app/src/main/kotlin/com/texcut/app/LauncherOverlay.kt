package com.texcut.app

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * A floating snippet search shown over the current app. The user types to
 * filter and taps a snippet to insert it — handy when you forget a shortcut.
 */
class LauncherOverlay(private val context: Context) {

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: View? = null

    /** Current system clipboard, read while this (focusable) overlay has focus. */
    private var clipboardText: String = ""

    private fun readClipboard(): String = try {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE)
            as android.content.ClipboardManager
        cm.primaryClip?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)?.coerceToText(context)?.toString()?.trim() ?: ""
    } catch (e: Exception) {
        ""
    }

    fun show(
        snippets: List<Snippet>,
        clips: List<String>,
        onResult: (Snippet?, String?) -> Unit
    ) {
        if (root != null) return
        val density = context.resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val list = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }

        fun row(title: String, subtitle: String, onClick: () -> Unit): View {
            return LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(6), dp(10), dp(6), dp(10))
                isClickable = true
                addView(TextView(context).apply {
                    text = title
                    setTextColor(Color.WHITE)
                    textSize = 15f
                    maxLines = 1
                })
                addView(TextView(context).apply {
                    text = subtitle
                    setTextColor(Color.parseColor("#9C97AE"))
                    textSize = 12f
                    maxLines = 1
                })
                setOnClickListener {
                    dismiss()
                    onClick()
                }
            }
        }

        fun rebuild(query: String) {
            list.removeAllViews()
            val q = query.trim().lowercase()
            var shown = 0
            // Live clipboard (readable because this overlay holds focus).
            if (clipboardText.isNotEmpty() &&
                (q.isEmpty() || clipboardText.lowercase().contains(q))
            ) {
                list.addView(row("📋  Paste clipboard",
                    clipboardText.replace("\n", " ↵ ").take(60)) {
                    onResult(null, clipboardText)
                })
                shown++
            }
            for (s in snippets) {
                if (!s.enabled) continue
                if (q.isNotEmpty() && !(s.shortcut.lowercase().contains(q) ||
                        s.label.lowercase().contains(q) ||
                        s.expansion.lowercase().contains(q))) continue
                val title = if (s.label.isNotBlank()) s.label else s.shortcut
                list.addView(row(title,
                    "${s.shortcut}   ·   ${s.expansion.replace("\n", " ↵ ")}") {
                    onResult(s, null)
                })
                if (++shown >= 50) break
            }
            for (c in clips) {
                if (shown >= 60) break
                if (q.isNotEmpty() && !c.lowercase().contains(q)) continue
                list.addView(row("📋  ${c.replace("\n", " ↵ ").take(60)}", "clip") {
                    onResult(null, c)
                })
                shown++
            }
            if (shown == 0) {
                list.addView(TextView(context).apply {
                    text = "No matches"
                    setTextColor(Color.parseColor("#9C97AE"))
                    setPadding(dp(6), dp(12), dp(6), dp(12))
                })
            }
        }

        val search = EditText(context).apply {
            hint = "Search snippets & clips"
            setTextColor(Color.WHITE)
            setHintTextColor(Color.parseColor("#7C7790"))
            inputType = InputType.TYPE_CLASS_TEXT
            addTextChangedListener(object : TextWatcher {
                override fun afterTextChanged(s: Editable?) = rebuild(s?.toString() ?: "")
                override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
                override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            })
        }

        val scroll = ScrollView(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (context.resources.displayMetrics.heightPixels * 0.45).toInt()
            )
            addView(list)
        }

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(18), dp(20), dp(14))
            background = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(Color.parseColor("#1E1B2E"))
            }
            addView(TextView(context).apply {
                text = "texcut"
                setTextColor(Color.WHITE)
                textSize = 16f
                setPadding(0, 0, 0, dp(8))
            })
            addView(search)
            addView(scroll)
            addView(TextView(context).apply {
                text = "Cancel"
                setTextColor(Color.parseColor("#B9B4CC"))
                textSize = 14f
                gravity = Gravity.END
                setPadding(0, dp(10), dp(6), 0)
                setOnClickListener { dismiss(); onResult(null, null) }
            })
        }

        rebuild("")

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            (context.resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_DIM_BEHIND,
            android.graphics.PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.5f
        }

        root = container
        try {
            windowManager.addView(container, params)
            search.requestFocus()
            // Once the window has focus, the clipboard becomes readable; pick it
            // up and surface a "Paste clipboard" row.
            container.postDelayed({
                if (root == null) return@postDelayed
                clipboardText = readClipboard()
                if (clipboardText.isNotEmpty()) rebuild(search.text?.toString() ?: "")
            }, 200)
        } catch (e: Exception) {
            root = null
            onResult(null, null)
        }
    }

    private fun dismiss() {
        root?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {
                // already removed
            }
        }
        root = null
    }
}
