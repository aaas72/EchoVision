import 'dart:ui';

import 'package:echovision/domain/models/detected_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DetectedObject', () {
    DetectedObject buildObject({
      Rect boundingBox = const Rect.fromLTWH(40, 30, 20, 30),
      double frameWidth = 100,
      double frameHeight = 100,
    }) {
      return DetectedObject(
        label: 'chair',
        confidence: 0.95,
        boundingBox: boundingBox,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      );
    }

    test('stores the supplied detection values', () {
      final object = buildObject();

      expect(object.label, 'chair');
      expect(object.confidence, 0.95);
      expect(object.boundingBox, const Rect.fromLTWH(40, 30, 20, 30));
      expect(object.frameWidth, 100);
      expect(object.frameHeight, 100);
    });

    test('calculates relative size from bounding-box and frame areas', () {
      final object = buildObject();

      expect(object.relativeSize, closeTo(0.06, 0.000001));
    });

    test('returns zero relative size when the frame area is zero', () {
      final object = buildObject(frameWidth: 0, frameHeight: 100);

      expect(object.relativeSize, 0);
    });

    test('identifies an object whose center is within the central region', () {
      final object = buildObject(
        boundingBox: const Rect.fromLTWH(40, 40, 20, 20),
      );

      expect(object.isCentered, isTrue);
    });

    test('does not identify an object outside the central region as centered',
        () {
      final object = buildObject(
        boundingBox: const Rect.fromLTWH(5, 40, 20, 20),
      );

      expect(object.isCentered, isFalse);
    });

    test('returns the left direction hint for an object on the left', () {
      final object = buildObject(
        boundingBox: const Rect.fromLTWH(10, 40, 10, 10),
      );

      expect(object.directionHint, 'on your left');
    });

    test('returns the right direction hint for an object on the right', () {
      final object = buildObject(
        boundingBox: const Rect.fromLTWH(80, 40, 10, 10),
      );

      expect(object.directionHint, 'on your right');
    });

    test('returns the front direction hint for an object near the center', () {
      final object = buildObject(
        boundingBox: const Rect.fromLTWH(45, 40, 10, 10),
      );

      expect(object.directionHint, 'in front of you');
    });
  });
}
