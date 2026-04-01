import 'package:vibration/vibration.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/detected_object.dart';

/// Service responsible for haptic feedback based on object proximity.
/// Maps bounding box size/position to vibration intensity.
class HapticService {
  bool _hasVibrator = false;

  /// Initialize haptic service and check device capability.
  Future<void> initialize() async {
    _hasVibrator = await Vibration.hasVibrator() ?? false;
  }

  /// Provide haptic feedback based on detected object's bounding box.
  /// - Larger bounding box (closer object) = longer/stronger vibration
  /// - Centered object = distinct pulse pattern ("Target Locked")
  Future<void> vibrateForObject(DetectedObject object) async {
    if (!_hasVibrator) return;

    final size = object.relativeSize;

    // Map relative size (0.0 - 1.0) to vibration duration
    final duration = (AppConstants.minVibrationDuration +
            (size * (AppConstants.maxVibrationDuration - AppConstants.minVibrationDuration)))
        .round()
        .clamp(AppConstants.minVibrationDuration, AppConstants.maxVibrationDuration);

    if (object.isCentered) {
      // "Target Locked" - distinct double-pulse pattern
      await Vibration.vibrate(pattern: [0, duration, 100, duration]);
    } else {
      // Normal proximity vibration
      await Vibration.vibrate(duration: duration);
    }
  }

  /// Single short vibration for UI feedback (mode switch, etc.)
  Future<void> tick() async {
    if (!_hasVibrator) return;
    await Vibration.vibrate(duration: 50);
  }
}
