import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Advanced audio-haptic feedback service (3-State Feedback Loop).
/// Provides premium UI confirmation sounds synced with haptics.
class AudioFeedbackService {
  static final AudioPlayer _startPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _successPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _errorPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  static bool _hasSounds = false;

  /// Loads the audio assets into memory for zero-latency playback.
  /// If the files don't exist yet, it catches the error and falls back gracefully.
  static Future<void> initialize() async {
    try {
      await _startPlayer.setSource(AssetSource('sounds/start.wav'));
      await _successPlayer.setSource(AssetSource('sounds/success.wav'));
      await _errorPlayer.setSource(AssetSource('sounds/error.wav'));
      _hasSounds = true;
    } catch (e) {
      print('AudioFeedbackService: Sounds not found yet. Please add them to assets/sounds/.');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  3-STATE CLOUD FEEDBACK LOOP (Gemini)
  // ══════════════════════════════════════════════════════════════

  /// State 1: Request Initiated (Light Impact + Tick-Up)
  static Future<void> requestInitiated() async {
    await HapticFeedback.lightImpact();
    if (_hasSounds) {
      try { await _startPlayer.resume(); } catch (_) {}
    } else {
      // Fallback if no sound file
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// State 2: Response Received (Medium Impact / Double Tick + Positive Chime)
  static Future<void> responseReceived() async {
    await HapticFeedback.mediumImpact();
    if (_hasSounds) {
      try { await _successPlayer.resume(); } catch (_) {}
    }
  }

  /// State 3: Error / No Connection (Heavy Vibration + Low-pitch Beep)
  static Future<void> errorState() async {
    await HapticFeedback.heavyImpact();
    if (_hasSounds) {
      try { await _errorPlayer.resume(); } catch (_) {}
    }
  }


  // ══════════════════════════════════════════════════════════════
  // ██  LEGACY / LOCAL UI FEEDBACK
  // ══════════════════════════════════════════════════════════════

  static Future<void> uiClick() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.lightImpact();
  }

  static Future<void> scanStart() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> scanComplete() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> error() async {
    await HapticFeedback.vibrate();
  }
}
