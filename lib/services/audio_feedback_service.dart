import 'package:flutter/services.dart';

/// Lightweight audio-haptic feedback service using system sounds.
/// Provides premium UI click/confirmation sounds synced with haptics.
class AudioFeedbackService {
  /// Short click for mode switches and UI interactions.
  static Future<void> uiClick() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for scan start.
  static Future<void> scanStart() async {
    await HapticFeedback.mediumImpact();
  }

  /// Success feedback for scan completion.
  static Future<void> scanComplete() async {
    await HapticFeedback.heavyImpact();
  }

  /// Alert pattern for errors.
  static Future<void> error() async {
    await HapticFeedback.vibrate();
  }
}
