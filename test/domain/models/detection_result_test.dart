import 'dart:ui';

import 'package:echovision/domain/models/detection_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DetectionResult', () {
    DetectionResult buildResult({
      String label = 'chair',
      double confidence = 0.9,
      Rect boundingBox = const Rect.fromLTWH(45, 10, 10, 10),
      DetectionSource source = DetectionSource.tflite,
    }) {
      return DetectionResult(
        label: label,
        confidence: confidence,
        boundingBox: boundingBox,
        source: source,
      );
    }

    test('stores the supplied detection values', () {
      final result = buildResult();

      expect(result.label, 'chair');
      expect(result.confidence, 0.9);
      expect(result.boundingBox, const Rect.fromLTWH(45, 10, 10, 10));
      expect(result.source, DetectionSource.tflite);
    });

    test('exposes the bounding-box center coordinates', () {
      final result = buildResult(
        boundingBox: const Rect.fromLTWH(10, 20, 30, 40),
      );

      expect(result.centerX, 25);
      expect(result.centerY, 40);
    });

    test('translates a known label into Turkish', () {
      expect(buildResult(label: 'chair').turkishLabel, 'sandalye');
    });

    test('looks up labels without case sensitivity', () {
      expect(buildResult(label: 'CHAIR').turkishLabel, 'sandalye');
    });

    test('keeps the original label when no translation exists', () {
      expect(buildResult(label: 'custom object').turkishLabel, 'custom object');
    });

    test('describes objects on the left in Turkish', () {
      final result = buildResult(
        boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
      );

      expect(result.horizontalPosition, 'solda');
    });

    test('describes objects on the right in Turkish', () {
      final result = buildResult(
        boundingBox: const Rect.fromLTWH(80, 0, 10, 10),
      );

      expect(result.horizontalPosition, 'sağda');
    });

    test('describes objects between the left and right thresholds as centered',
        () {
      final result = buildResult(
        boundingBox: const Rect.fromLTWH(45, 0, 10, 10),
      );

      expect(result.horizontalPosition, 'ortada');
    });

    test('considers an object close when its bounding-box area exceeds 0.4',
        () {
      final result = buildResult(
        boundingBox: const Rect.fromLTWH(0, 0, 0.5, 0.9),
      );

      expect(result.isClose, isTrue);
    });

    test('does not consider an object close when its area is 0.4', () {
      final result = buildResult(
        boundingBox: const Rect.fromLTWH(0, 0, 1, 0.4),
      );

      expect(result.isClose, isFalse);
    });

    test('builds the spoken Turkish description from position and label', () {
      final result = buildResult(
        label: 'chair',
        boundingBox: const Rect.fromLTWH(45, 0, 10, 10),
      );

      expect(result.description, 'ortada bir sandalye var');
    });

    test('supports each detection source value', () {
      expect(buildResult(source: DetectionSource.mlKit).source,
          DetectionSource.mlKit);
      expect(buildResult(source: DetectionSource.tflite).source,
          DetectionSource.tflite);
      expect(buildResult(source: DetectionSource.gemini).source,
          DetectionSource.gemini);
    });
  });
}
