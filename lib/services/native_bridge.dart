import 'package:flutter/services.dart';

/// Thin wrapper around the platform channel that talks to the Android
/// accessibility service. On non-Android platforms every call degrades
/// gracefully to a no-op so the UI still runs (e.g. in tests or on desktop).
class NativeBridge {
  NativeBridge([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.texcut.app/accessibility';

  final MethodChannel _channel;

  /// Whether the texcut accessibility service is currently enabled in the
  /// Android system settings.
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('isServiceEnabled');
      return enabled ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system Accessibility settings so the user can toggle texcut on.
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on MissingPluginException {
      // Not on Android — nothing to open.
    } on PlatformException {
      // Ignore; the UI surfaces guidance separately.
    }
  }

  /// Opens texcut's own "App info" page, where the "Allow restricted settings"
  /// option lives on Android 13+ (needed before accessibility can be granted to
  /// a sideloaded app).
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } on MissingPluginException {
      // Not on Android — nothing to open.
    } on PlatformException {
      // Ignore; the guide explains the manual path too.
    }
  }

  /// Whether texcut can draw over other apps (needed for the fill-in prompt).
  Future<bool> canDrawOverlays() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the "Display over other apps" settings page for texcut.
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } on MissingPluginException {
      // no-op off Android
    } on PlatformException {
      // no-op
    }
  }

  /// Tells the running service to reload snippets/settings from storage.
  Future<void> notifyDataChanged() async {
    try {
      await _channel.invokeMethod('reloadData');
    } on MissingPluginException {
      // No-op off Android.
    } on PlatformException {
      // No-op; the service also reloads lazily on its next event.
    }
  }
}
