import 'dart:async';
import 'dart:ui';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class AudioHapticService {
  final FlutterTts _tts = FlutterTts();

  // تصفية التكرار: نحتاج الآن إلى مؤقت "عالمي" لمنع التطبيق من الثرثرة بأشياء مختلفة وراء بعضها
  DateTime? _lastGlobalSpoken;
  final Duration _globalDebounceDuration = const Duration(seconds: 3);
  AudioHapticService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("tr-TR"); // اللغة التركية
    await _tts.setSpeechRate(0.6); // سرعة مناسبة للاستيعاب
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // الدالة الرئيسية لاستقبال البيانات من الذكاء الاصطناعي وإصدار رد الفعل
  Future<void> processFeedback({
    required String label,
    required Rect boundingBox,
    required Size imageSize,
  }) async {
    // 1. حل الفجوة الدلالية (Semantic Gap): حساب الاتجاه والقرب
    String directionText = _calculateDirection(boundingBox, imageSize);
    double areaRatio = _calculateAreaRatio(boundingBox, imageSize);

    // تقدير المسافة بناءً على حجم المربع المحيط مقارنة بحجم الشاشة
    String proximityText =
        areaRatio > 0.4 ? "çok yakın" : (areaRatio > 0.15 ? "yakın" : "");

    // 2. حل العبء المعرفي الصوتي (Cognitive Load): نظام الـ Debounce العالمي
    final now = DateTime.now();

    // إذا لم تمر 3 ثوانٍ على الأقل منذ آخر نطق، تجاهل الإطار الحالي (لمنع الثرثرة والانتقال السريع بين الأسماء)
    if (_lastGlobalSpoken != null &&
        now.difference(_lastGlobalSpoken!) < _globalDebounceDuration) {
      return; // لا تتكلم ولا تهتز الآن لتجنب إرباك المستخدم
    }

    // بمجرد أن نمتلك الإذن بالنطق، نحدث المؤقت فوراً لمنع التداخل
    _lastGlobalSpoken = now;

    // دمج المعلومات: "اسم الشيء + المسافة + الاتجاه" (مثال: Masa çok yakın karşıda)
    String textToSpeak = "$label $proximityText $directionText".trim();
    await _tts.speak(textToSpeak);

    // 3. تخفيف العبء السمعي وتحويله للمس (Haptic Offloading)
    _triggerVibration(areaRatio);
  }

  // حساب الاتجاه (يسار، يمين، أمام)
  String _calculateDirection(Rect box, Size imageSize) {
    double centerX = box.left + (box.width / 2);
    double oneThird = imageSize.width / 3;

    if (centerX < oneThird) {
      return "solda"; // لليسار
    } else if (centerX > 2 * oneThird) {
      return "sağda"; // لليمين
    } else {
      return "karşıda"; // في المنتصف أمامك
    }
  }

  // حساب نسبة مساحة الشيء مقارنة بالشاشة لمعرفة قربه
  double _calculateAreaRatio(Rect box, Size imageSize) {
    double boxArea = box.width * box.height;
    double imageArea = imageSize.width * imageSize.height;
    return boxArea / imageArea;
  }

  // إصدار الاهتزازات بناءً على القرب والخطر
  Future<void> _triggerVibration(double areaRatio) async {
    bool hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    if (areaRatio > 0.5) {
      // خطر مباشر: اهتزاز قوي ومتقطع للتحذير
      Vibration.vibrate(
          pattern: [0, 500, 100, 500], intensities: [0, 255, 0, 255]);
    } else if (areaRatio > 0.2) {
      // اقتراب: اهتزاز متوسط ينبه المستخدم
      Vibration.vibrate(duration: 200, amplitude: 128);
    }
  }

  // إيقاف الصوت مؤقتاً (Mute Functionality)
  Future<void> stop() async {
    await _tts.stop();
  }
}
