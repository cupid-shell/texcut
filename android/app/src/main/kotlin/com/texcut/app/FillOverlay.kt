package com.texcut.app

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView

/**
 * A floating form, shown over whatever app the user is in, that collects the
 * values of {input:Label} fields before a snippet is pasted. Requires the
 * "Display over other apps" permission.
 */
class FillOverlay(private val context: Context) {

    companion object {
        fun canShow(context: Context): Boolean = Settings.canDrawOverlays(context)
    }

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: View? = null

    /** [onResult] is called with the entered values, or null if cancelled. */
    fun show(labels: List<String>, onResult: (Map<String, String>?) -> Unit) {
        if (root != null) return

        val density = context.resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val fields = mutableMapOf<String, EditText>()

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(16))
            background = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(Color.parseColor("#1E1B2E"))
            }
        }

        container.addView(TextView(context).apply {
            text = "texcut — fill in"
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(0, 0, 0, dp(12))
        })

        for (label in labels) {
            container.addView(TextView(context).apply {
                text = label
                setTextColor(Color.parseColor("#C9C5D6"))
                textSize = 13f
                setPadding(0, dp(8), 0, dp(2))
            })
            val edit = EditText(context).apply {
                hint = label
                setTextColor(Color.WHITE)
                setHintTextColor(Color.parseColor("#7C7790"))
                inputType = InputType.TYPE_CLASS_TEXT or
                    InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            }
            fields[label] = edit
            container.addView(edit)
        }

        val buttons = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, dp(16), 0, 0)
        }
        buttons.addView(Button(context).apply {
            text = "Cancel"
            setOnClickListener {
                dismiss()
                onResult(null)
            }
        })
        buttons.addView(Button(context).apply {
            text = "Insert"
            setOnClickListener {
                val values = fields.mapValues { it.value.text.toString() }
                dismiss()
                onResult(values)
            }
        })
        container.addView(buttons)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            (context.resources.displayMetrics.widthPixels * 0.88).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            // Focusable so the EditTexts can receive keyboard input; dim behind.
            WindowManager.LayoutParams.FLAG_DIM_BEHIND,
            android.graphics.PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.45f
        }

        root = container
        try {
            windowManager.addView(container, params)
            fields[labels.first()]?.requestFocus()
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
