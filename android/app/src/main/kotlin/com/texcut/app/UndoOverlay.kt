package com.texcut.app

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * A small, non-focusable "Undo" chip shown briefly near the bottom of the
 * screen right after an expansion fires. Because the window is NOT focusable,
 * the user's text field keeps input focus and typing continues uninterrupted;
 * only a tap on the chip itself is captured.
 *
 * Single-instance: showing a new chip replaces any chip already on screen.
 */
class UndoOverlay(private val context: Context) {

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private var root: View? = null
    private val autoDismiss = Runnable { dismiss() }

    fun show(shortcut: String, onUndo: () -> Unit) {
        dismiss()
        val density = context.resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val label = TextView(context).apply {
            text = "Expanded “$shortcut”"
            setTextColor(Color.parseColor("#E7E3F4"))
            textSize = 13f
        }
        val action = TextView(context).apply {
            text = "  UNDO"
            setTextColor(Color.parseColor("#9FB4FF"))
            textSize = 14f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }

        val chip = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = GradientDrawable().apply {
                cornerRadius = dp(24).toFloat()
                setColor(Color.parseColor("#2A2740"))
            }
            isClickable = true
            addView(label)
            addView(action)
            setOnClickListener {
                main.removeCallbacks(autoDismiss)
                dismiss()
                onUndo()
            }
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            // Not focusable: typing keeps flowing to the app's text field. Only
            // touches landing on the chip's own bounds are delivered to us.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            android.graphics.PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(120)
        }

        root = chip
        try {
            windowManager.addView(chip, params)
            main.postDelayed(autoDismiss, 3500)
        } catch (e: Exception) {
            root = null
        }
    }

    fun dismiss() {
        main.removeCallbacks(autoDismiss)
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
