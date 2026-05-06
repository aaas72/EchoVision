import 'dart:ui' show Rect;

/// Represents a detected object with its label, confidence, and bounding box.
class DetectedObject {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final double frameWidth;
  final double frameHeight;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.frameWidth,
    required this.frameHeight,
  });

  /// Relative size of the bounding box (0.0 to 1.0) compared to the frame.
  /// Larger value = object is closer.
  double get relativeSize {
    final frameArea = frameWidth * frameHeight;
    if (frameArea == 0) return 0;
    return (boundingBox.width * boundingBox.height) / frameArea;
  }

  /// Whether the object is centered in the frame (within 20% of center).
  bool get isCentered {
    final centerX = boundingBox.center.dx / frameWidth;
    final centerY = boundingBox.center.dy / frameHeight;
    return (centerX - 0.5).abs() < 0.2 && (centerY - 0.5).abs() < 0.2;
  }

  /// Direction hint for the user (English).
  String get directionHint {
    final cx = boundingBox.center.dx / frameWidth;
    if (cx < 0.35) return 'on your left';
    if (cx > 0.65) return 'on your right';
    return 'in front of you';
  }
}
