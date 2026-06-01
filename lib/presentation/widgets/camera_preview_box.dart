import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewBox extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewBox({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final previewSize = controller.value.previewSize!;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.of(context).orientation == Orientation.portrait
              ? previewSize.height
              : previewSize.width,
          height: MediaQuery.of(context).orientation == Orientation.portrait
              ? previewSize.width
              : previewSize.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
