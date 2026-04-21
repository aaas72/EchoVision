import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'vision_pipeline_service.dart';
import 'ml_kit_service.dart';
import 'mlkit_detection_service.dart';
import 'audio_haptic_service.dart';

class SystemController extends ChangeNotifier {
  final VisionPipelineService _vision = VisionPipelineService();
  final MLKitService _mlKit = MLKitService();
  final AudioHapticService _audioHaptic = AudioHapticService();

  bool isInitializing = true;
  int _sensorOrientation = 90;

  // عند بدء التطبيق، يتم إطلاق هذه الدالة لربط جميع المحركات معاً
  Future<void> initializeSystem() async {
    isInitializing = true;
    notifyListeners();

    // تشغيل الكاميرا وإعطاؤها أمر انتظار الإطارات المصفّاة (3 إطارات في الثانية)
    await _vision.initializeCamera((CameraImage image) {
      _processThrottledFrame(image);
    });

    isInitializing = false;
    notifyListeners();
  }

  // 1. الدالة المايسترو: تربط الكاميرا (المدخلات)، بالذكاء الاصطناعي (العقل)، بالصوت/الاهتزاز (المخرجات)
  Future<void> _processThrottledFrame(CameraImage image) async {
    // 2. إرسال الصورة للذكاء الاصطناعي أوفلاين (الآن يستقبل نتيجتين مدمجتين)
    final mergedResult =
        await _mlKit.processCameraImage(image, _sensorOrientation);

    if (mergedResult == null) return;

    List<DetectedObject> detectedObjects = mergedResult.objects;
    List<ImageLabel> labels = mergedResult.labels;

    // 3. معالجة النتائج لدقة عالية جداً: دمج البعد والموقع مع الاسم الدقيق
    if (detectedObjects.isNotEmpty && labels.isNotEmpty) {
      // ترتيب المواقع لنجد أين أقرب وأكبر شيء يمكن أن يشكل أمراً هاماً للمكفوف
      detectedObjects.sort((a, b) {
        double areaA = a.boundingBox.width * a.boundingBox.height;
        double areaB = b.boundingBox.width * b.boundingBox.height;
        return areaB.compareTo(areaA); // الأكبر أولاً
      });

      // الموقع (المربع المحيط) الخاص بأهم شيء في الصورة
      DetectedObject primaryTargetBox = detectedObjects.first;

      // تصفية: استبعاد النتائج والأسماء العامة جداً أو غير المفيدة للمكفوف
      List<String> ignoredLabels = ['Monochrome', 'Pattern', 'Room', 'Home good', 'Tableware'];
      
      var filteredLabels = labels.where((label) {
        if (ignoredLabels.contains(label.label)) return false;
        // التأكد من أن الاسم الإنجليزي تم ترجمته للتركية وأن النتيجة ليست فارغة
        if (MLKitDetectionService.translateToTurkish(label.label).isEmpty) return false;
        return true;
      }).toList();

      if(filteredLabels.isEmpty) return;

      // ترتيب قائمة الأسماء الدقيقة جداً 
      filteredLabels.sort((a, b) => b.confidence.compareTo(a.confidence));
      
      // أخذ أفضل وأدق اسم في الصورة (مترجم للتركية)
      String preciseLabel = MLKitDetectionService.translateToTurkish(filteredLabels.first.label);

      // 4. إرسال المعلومة للمستخدم (السمع واللمس)
      await _audioHaptic.processFeedback(
        label: preciseLabel, // الاسم التفصيلي من نموذج الـ Labeler
        boundingBox:
            primaryTargetBox.boundingBox, // موقع الشيء من نموذج الـ Detector
        imageSize: Size(
            image.width.toDouble(), image.height.toDouble()), // لمعايرة الأبعاد
      );
    }
  }

  // كتم أو تشغيل الصوت والمحركات
  void toggleMute() {
    _audioHaptic.stop(); // إيقاف الحديث الحالي
  }

  @override
  void dispose() {
    _vision.dispose();
    _mlKit.dispose();
    _audioHaptic.stop();
    super.dispose();
  }
}
