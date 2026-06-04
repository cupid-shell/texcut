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

    fun show(snippets: List<Snippet>, onResult: (Snippet?) -> Unit) {
        if (root != null) return
        val density = context.resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val list = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }

        fun rowFor(s: Snippet): View {
            val title = if (s.label.isNotBlank()) s.label else s.shortcut
            return LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(6), dp(10), dp(6), dp(10))
                isClickable = true
                addView(TextView(context).apply {
                    text = title
                    setTextColor(Color.WHITE)
                    textSize = 15f
                })
                addView(TextView(context).apply {
                    text = "${s.shortcut}   ·   ${s.expansion.replace("\n", " ↵ ")}"
                    setTextColor(Color.parseColor("#9C97AE"))
                    textSize = 12f
                    maxLines = 1
                })
                setOnClickListener {
                    dismiss()
                    onResult(s)
                }
            }
        }

        fun rebuild(query: String) {
            list.removeAllViews()
            val q = query.trim().lowercase()
            val matches = snippets.filter {
                it.enabled && (q.isEmpty() ||
                    it.shortcut.lowercase().contains(q) ||
                    it.label.lowercase().contains(q) ||
                    it.expansion.lowercase().contains(q))
            }.take(50)
            if (matches.isEmpty()) {
                list.addView(TextView(context).apply {
                    text = "No matching snippets"
                    setTextColor(Color.parseColor("#9C97AE"))
                    setPadding(dp(6), dp(12), dp(6), dp(12))
                })
            } else {
                for (s in matches) list.addView(rowFor(s))
            }
        }

        val search = EditText(context).apply {
            hint = "Search snippets"
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
                setOnClickListener { dismiss(); onResult(null) }
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
        } catch (e: Exception) {
            root = null
            onResult(null)
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
