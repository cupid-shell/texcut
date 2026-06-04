package com.texcut.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and bridges a small set of platform calls used to
 * check on / open the accessibility service.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.texcut.app/accessibility"

    /** Text shared into texcut (ACTION_SEND / PROCESS_TEXT), consumed once by Flutter. */
    private var sharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureSharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureSharedText(intent)
    }

    private fun captureSharedText(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SEND ->
                if (intent.type == "text/plain") {
                    sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                }
            Intent.ACTION_PROCESS_TEXT ->
                sharedText = intent
                    .getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isServiceEnabled" -> result.success(isAccessibilityServiceEnabled())
                "getSharedText" -> {
                    val t = sharedText
                    sharedText = null
                    result.success(t)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.fromParts("package", packageName, null)
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                "openAppSettings" -> {
                    // Opens texcut's App info page. On Android 13+ this is where
                    // the "Allow restricted settings" menu item appears, which
                    // must be tapped before a sideloaded app can be granted
                    // accessibility access.
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                // The service reads snippets/settings lazily from shared
                // storage on its next event, so there is nothing to push.
                "reloadData" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected =
            "$packageName/${TextExpanderAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.split(':').any { it.equals(expected, ignoreCase = true) }
    }
}
