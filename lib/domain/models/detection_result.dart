import 'dart:ui';

/// Represents a single detection with spatial data.
class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final DetectionSource source;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.source,
  });

  /// Calculates the position relative to the frame (0.0 to 1.0).
  double get centerX => boundingBox.center.dx;
  double get centerY => boundingBox.center.dy;

  /// Returns the horizontal position description in English.
  String get horizontalPosition {
    if (centerX < 0.33) return 'on the left';
    if (centerX > 0.66) return 'on the right';
    return 'in the center';
  }

  /// Estimates if the object is close based on bounding box area.
  /// (Simplified logic: Area > 40% of frame = Very Close).
  bool get isClose => (boundingBox.width * boundingBox.height) > 0.4;

  /// Returns a full descriptive sentence in English.
  String get description {
    String pos = horizontalPosition;
    if (isClose) {
      return '$label is very close, $pos';
    }
    return '$label $pos';
  }
}

enum DetectionSource {
  mlKit,
  tflite,
  gemini,
}
