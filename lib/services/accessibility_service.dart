import 'package:flutter/services.dart';

/// Service to manage Android Accessibility settings.
/// Allows checking if the volume button shortcut is enabled
/// and opens settings to enable it.
class AccessibilityService {
  static const MethodChannel _channel =
      MethodChannel('com.echovision/accessibility');

  /// Check if the accessibility service is enabled
  static Future<bool> isEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result;
    } catch (e) {
      print('Error checking accessibility: $e');
      return false;
    }
  }

  /// Open Android accessibility settings
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('Error opening accessibility settings: $e');
    }
  }
}
