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
 * values of fill-in fields before a snippet is pasted — free-text {input:}
 * fields and {choice:} pick-lists. Requires the "Display over other apps"
 * permission.
 */
class FillOverlay(private val context: Context) {

    companion object {
        fun canShow(context: Context): Boolean = Settings.canDrawOverlays(context)

        private const val CHIP_OFF = "#2A2740"
        private const val CHIP_ON = "#3D5BD6"
    }

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: View? = null

    /** [onResult] is called with the entered values, or null if cancelled. */
    fun show(fields: List<FillField>, onResult: (Map<String, String>?) -> Unit) {
        if (root != null) return

        val density = context.resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val textInputs = mutableMapOf<String, EditText>()
        // Pre-select the first option for each pick-list so "Insert" is always
        // valid even if the user doesn't change anything.
        val chosen = mutableMapOf<String, String>()
        var firstEdit: EditText? = null

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

        for (field in fields) {
            container.addView(TextView(context).apply {
                text = field.title
                setTextColor(Color.parseColor("#C9C5D6"))
                textSize = 13f
                setPadding(0, dp(8), 0, dp(2))
            })

            if (field.isChoice) {
                chosen[field.label] = field.options.first()
                val buttons = mutableListOf<Button>()
                val row = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                }
                // Wrap options into rows of up to 3 so long lists stay readable.
                var line = row
                container.addView(line)
                field.options.forEachIndexed { i, opt ->
                    if (i > 0 && i % 3 == 0) {
                        line = LinearLayout(context).apply {
                            orientation = LinearLayout.HORIZONTAL
                        }
                        container.addView(line)
                    }
                    val btn = Button(context).apply {
                        text = opt
                        setAllCaps(false)
                        setTextColor(Color.WHITE)
                        background = chipBg(dp(16), i == 0)
                    }
                    btn.setOnClickListener {
                        chosen[field.label] = opt
                        buttons.forEachIndexed { j, b ->
                            b.background = chipBg(dp(16), field.options[j] == opt)
                        }
                    }
                    buttons.add(btn)
                    val lp = LinearLayout.LayoutParams(
                        0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f
                    ).apply { setMargins(dp(2), dp(2), dp(2), dp(2)) }
                    line.addView(btn, lp)
                }
            } else {
                val edit = EditText(context).apply {
                    hint = field.title
                    setTextColor(Color.WHITE)
                    setHintTextColor(Color.parseColor("#7C7790"))
                    inputType = InputType.TYPE_CLASS_TEXT or
                        InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                }
                textInputs[field.label] = edit
                if (firstEdit == null) firstEdit = edit
                container.addView(edit)
            }
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
                val values = HashMap<String, String>(chosen)
                for ((label, edit) in textInputs) {
                    values[label] = edit.text.toString()
                }
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
            firstEdit?.requestFocus()
        } catch (e: Exception) {
            root = null
            onResult(null)
        }
    }

    private fun chipBg(radius: Int, selected: Boolean): GradientDrawable =
        GradientDrawable().apply {
            cornerRadius = radius.toFloat()
            setColor(Color.parseColor(if (selected) CHIP_ON else CHIP_OFF))
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
