import 'dart:async';
import 'package:camera/camera.dart';

class VisionPipelineService {
  CameraController? _cameraController;
  bool _isProcessing = false;
  DateTime _lastFrameTime = DateTime.now();

  // 1. حل فجوة التأخير والأمان (Frame Throttling)
  // سنعالج فقط 3 إطارات في الثانية بدلاً من 60 (أي حوالي 333 ملي ثانية بين كل إطار)
  // هذا يقلل العبء على المعالج CPU، ويمنع ارتفاع الحرارة، ويقتل التأخير Latency تماماً
  final int _throttleDurationMs = 333;

  Future<void> initializeCamera(Function(CameraImage) onFrameAvailable) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // الحصول على الكاميرا الخلفية بشكل افتراضي
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // استخدام دقة منخفضة (ResolutionPreset.low) لتسريع المعالجة وتحليل الإطارات دون إرهاق النظام
    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();

    // الاستماع لكل إطار تلتقطه الكاميرا (Video Stream)
    _cameraController!.startImageStream((CameraImage image) {
      final now = DateTime.now();

      // تقييد الإطارات (Throttling System):
      // تجاهل الإطار إذا كنا حالياً نعالج إطاراً آخر لتجنب تراكم المعالجة (Backpressure)
      // تجاهل الإطار إذا لم يمضِ 333 ملي ثانية منذ الإطار الأخير
      if (_isProcessing ||
          now.difference(_lastFrameTime).inMilliseconds < _throttleDurationMs) {
        return;
      }

      // قفل الحالة لمنع التراكم
      _isProcessing = true;
      _lastFrameTime = now;

      // إرسال الإطار (Frame) لمحرك الذكاء الاصطناعي (ML Core) لتحليله
      onFrameAvailable(image);

      // تحرير القفل فور الانتهاء ليسمح بدخول الإطار التالي
      _isProcessing = false;
    });
  }

  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
  }
}
