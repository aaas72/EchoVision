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
  int get sensorOrientation => _controller?.description.sensorOrientation ?? 0;

  /// Initialize the camera with the back-facing lens (high resolution).
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('NO_CAMERAS', 'No cameras available on this device.');
    }

    // Default to the first back camera for a natural, standard view
    final backCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high, // Reverted to high resolution (1080p) to provide detailed crops for the AI model
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg, // JPEG gives higher-quality preview on Xiaomi/Redmi/Samsung hardware encoders
    );

    await _controller!.initialize();
    
    // Lock zoom to 1.0 (no digital zoom degradation)
    try {
      await _controller!.setZoomLevel(1.0);
    } catch (e) {
      print('Camera Zoom Error: $e');
    }

    // Optimize focus and exposure for sharpest results
    try {
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (e) {
      print('Camera Focus Error: $e');
    }
    try {
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (e) {
      print('Camera Exposure Error: $e');
    }

    _isInitialized = true;
    print('Camera initialized: ${_controller!.value.previewSize} | Format: JPEG | Preset: high (16:9)');
  }

  /// Start streaming camera frames for real-time analysis.
  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (!_isInitialized || _controller == null) return;
    if (_controller!.value.isStreamingImages) return;
    await _controller!.startImageStream(onImage);
  }

  /// Stop the camera frame stream.
  Future<void> stopImageStream() async {
    if (!_isInitialized || _controller == null) return;
    if (!_controller!.value.isStreamingImages) return;
    await _controller!.stopImageStream();
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
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
