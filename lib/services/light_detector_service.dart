import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Light detector service for blind users.
/// Analyzes camera frames to measure ambient brightness and produces
/// continuous audio-haptic feedback:
///   - Dark → slow / no clicks
///   - Bright → rapid clicks
class LightDetectorService {
  Timer? _beepTimer;
  bool _isActive = false;
  int _currentBrightness = 0; // 0–255

  /// Current brightness level (0 = pitch black, 255 = very bright).
  int get brightness => _currentBrightness;

  /// Whether the detector is actively running.
  bool get isActive => _isActive;

  /// English description of current light level.
  String get levelDescription {
    if (_currentBrightness < 30) return 'Pitch black';
    if (_currentBrightness < 70) return 'Dark';
    if (_currentBrightness < 110) return 'Dim light';
    if (_currentBrightness < 160) return 'Medium light';
    if (_currentBrightness < 210) return 'Good light';
    return 'Strong light';
  }

  /// Start the light detector — begins image streaming & audio feedback.
  void start(CameraController controller) {
    if (_isActive) return;
    _isActive = true;

    controller.startImageStream((CameraImage image) {
      _currentBrightness = _calculateBrightness(image);
    });

    _startBeepLoop();
  }

  /// Stop the light detector — stops image streaming & audio.
  Future<void> stop(CameraController controller) async {
    if (!_isActive) return;
    _isActive = false;
    _beepTimer?.cancel();
    _beepTimer = null;
    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  /// Calculate average brightness from camera image (YUV/NV21 plane 0 = luminance).
  int _calculateBrightness(CameraImage image) {
    final Uint8List yPlane = image.planes[0].bytes;
    // Sample every 50th pixel for performance
    int sum = 0;
    int count = 0;
    for (int i = 0; i < yPlane.length; i += 50) {
      sum += yPlane[i];
      count++;
    }
    return count > 0 ? (sum ~/ count) : 0;
  }

  /// Continuous beep loop — interval maps to brightness.
  void _startBeepLoop() {
    _scheduleNextBeep();
  }

  void _scheduleNextBeep() {
    if (!_isActive) return;

    // Map brightness (0–255) to interval:
    //   0   → no beep (2000ms silence)
    //   255 → very fast (80ms)
    final int intervalMs;
    if (_currentBrightness < 15) {
      // Pitch black — silent, long pause
      intervalMs = 2000;
    } else {
      // Linear map: brighter = shorter interval
      // brightness 15→2000ms, brightness 255→80ms
      intervalMs = 2000 - ((_currentBrightness - 15) * 1920 ~/ 240);
    }

    _beepTimer?.cancel();
    _beepTimer = Timer(Duration(milliseconds: intervalMs.clamp(80, 2000)), () {
      if (!_isActive) return;
      if (_currentBrightness >= 15) {
        // Emit click + haptic proportional to brightness
        SystemSound.play(SystemSoundType.click);
        if (_currentBrightness > 150) {
          HapticFeedback.mediumImpact();
        } else if (_currentBrightness > 60) {
          HapticFeedback.lightImpact();
        }
      }
      _scheduleNextBeep();
    });
  }

  void dispose() {
    _beepTimer?.cancel();
    _beepTimer = null;
    _isActive = false;
  }
}
