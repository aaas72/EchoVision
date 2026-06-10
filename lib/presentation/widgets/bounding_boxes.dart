import 'package:flutter/material.dart';
import '../../core/enums/detection_mode.dart';
import '../../domain/models/detection_result.dart';

class BoundingBoxes extends StatelessWidget {
  final List<DetectionResult> detections;
  final DetectionMode currentMode;

  const BoundingBoxes({
    super.key,
    required this.detections,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty || (currentMode != DetectionMode.object && currentMode != DetectionMode.hand)) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;

    return Stack(
      children: detections.map((d) {
        final box = d.boundingBox;

        // Simple mapping (Assuming full screen coverage)
        final left = box.left * size.width;
        final top = box.top * size.height;
        final width = box.width * size.width;
        final height = box.height * size.height;

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  d.turkishLabel,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
