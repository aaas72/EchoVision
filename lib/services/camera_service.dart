import 'dart:async';
import 'package:camera/camera.dart';

/// Camera service for on-demand image capture.
/// Shows a live preview but does NOT continuously process frames.
/// The user taps to capture a high-quality still image for analysis.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  List<CameraDescription> get cameras => _cameras;

  /// Initialize the camera with the back-facing lens (high resolution).
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('NO_CAMERAS', 'No cameras available on this device.');
    }

    final backCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    // Auto-focus for sharp captures
    await _controller!.setFocusMode(FocusMode.auto);
    _isInitialized = true;
  }

  /// Capture a single high-quality still image and return the file.
  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) return null;
    if (_controller!.value.isTakingPicture) return null;
    return await _controller!.takePicture();
  }

  /// Toggle the flash/torch.
  Future<void> toggleFlash() async {
    if (_controller == null) return;
    final currentMode = _controller!.value.flashMode;
    await _controller!.setFlashMode(
      currentMode == FlashMode.torch ? FlashMode.off : FlashMode.torch,
    );
  }

  /// Dispose the camera controller and release resources.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
