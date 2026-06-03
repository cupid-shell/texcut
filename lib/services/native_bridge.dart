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
