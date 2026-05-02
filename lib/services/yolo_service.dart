import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import '../domain/models/detection_result.dart';

/// Optimized service for YOLO11n object detection.
class YoloService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<String> _labels = [];

  // YOLO11n default input size
  static const int _inputSize = 640;
  static const double _confThreshold = 0.30;
  static const double _iouThreshold = 0.45;

  bool get isInitialized => _isInitialized;

  /// Initialize YOLO11 engine and load labels.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // 1. Load COCO labels
      final labelsData = await rootBundle.loadString('assets/models/labelmap.txt');
      _labels = labelsData.split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != '???')
          .toList();
      
      print('YOLO11: Loaded ${_labels.length} labels');

      // 2. Initialize TFLite Interpreter with 4 threads for speed
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolo11n.tflite',
        options: options,
      );

      _isInitialized = true;
      print('YOLO11: Service initialized successfully');
    } catch (e) {
      print('YOLO11 Init Error: $e');
      _isInitialized = false;
    }
  }

  /// Analyze a camera stream frame directly.
  Future<List<DetectionResult>> analyzeFrame(CameraImage image, int sensorOrientation) async {
    if (!_isInitialized || _interpreter == null) return [];

    try {
      img.Image decoded;
      
      if (image.format.group == ImageFormatGroup.yuv420) {
        decoded = _convertYUV420ToImage(image);
      } else {
        final plane = image.planes.first;
        decoded = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: plane.bytes.buffer,
          order: img.ChannelOrder.bgra,
          rowStride: plane.bytesPerRow,
        );
      }

      // Rotate image based on sensor orientation (Android usually 90)
      if (sensorOrientation == 90) {
        decoded = img.copyRotate(decoded, angle: 90);
      } else if (sensorOrientation == 270) {
        decoded = img.copyRotate(decoded, angle: 270);
      }

      return _processDecodedImage(decoded);
    } catch (e) {
      print('YOLO11 Frame Inference Error: $e');
      return [];
    }
  }

  /// Optimized YUV420 to RGB conversion for CameraImage.
  img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final out = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        // Ensure we don't go out of bounds (padding issues)
        if (yIndex >= yBuffer.length || uvIndex >= uBuffer.length || uvIndex >= vBuffer.length) continue;

        final yp = yBuffer[yIndex];
        final up = uBuffer[uvIndex];
        final vp = vBuffer[uvIndex];

        // Standard YUV to RGB conversion formula
        int r = (yp + 1.402 * (vp - 128)).toInt().clamp(0, 255);
        int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).toInt().clamp(0, 255);
        int b = (yp + 1.772 * (up - 128)).toInt().clamp(0, 255);

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  /// Analyze image file and return detected objects.
  Future<List<DetectionResult>> analyzeImage(XFile imageFile) async {
    if (!_isInitialized || _interpreter == null) return [];

    try {
      final bytes = await File(imageFile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];

      return _processDecodedImage(decoded);
    } catch (e) {
      print('YOLO11 File Inference Error: $e');
      return [];
    }
  }

  /// Core processing logic shared between file and frame analysis.
  Future<List<DetectionResult>> _processDecodedImage(img.Image decoded) async {
    // Preprocessing: Resize and Normalize
    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);
    
    // Efficient input preparation
    final input = List.generate(1, (_) => List.generate(_inputSize, (y) => List.generate(_inputSize, (x) {
      final p = resized.getPixel(x, y);
      return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
    })));

    final outputTensor = _interpreter!.getOutputTensor(0);
    final shape = outputTensor.shape;
    final numChannels = shape[1]; 
    final numAnchors = shape[2];  
    
    print('YOLO Tensor Shape: $shape');

    final output = List.filled(1 * numChannels * numAnchors, 0.0)
        .reshape([1, numChannels, numAnchors]);

    _interpreter!.run(input, output);

    final detections = <DetectionResult>[];
    double maxConfidenceFound = 0.0;
    
    for (int i = 0; i < numAnchors; i++) {
      double maxScore = 0.0;
      int maxClassIndex = -1;

      for (int c = 0; c < (numChannels - 4); c++) {
        final score = output[0][4 + c][i];
        if (score > maxScore) {
          maxScore = score;
          maxClassIndex = c;
        }
      }

      if (maxScore > maxConfidenceFound) {
        maxConfidenceFound = maxScore;
      }

      if (maxScore > _confThreshold) {
        final cx = output[0][0][i];
        final cy = output[0][1][i];
        final w = output[0][2][i];
        final h = output[0][3][i];

        final x1 = (cx - w / 2) / _inputSize;
        final y1 = (cy - h / 2) / _inputSize;
        final x2 = (cx + w / 2) / _inputSize;
        final y2 = (cy + h / 2) / _inputSize;

        if (maxClassIndex < _labels.length) {
          detections.add(
            DetectionResult(
              label: _translateToArabic(_labels[maxClassIndex]),
              confidence: maxScore,
              boundingBox: Rect.fromLTRB(x1, y1, x2, y2),
              source: DetectionSource.tflite,
            ),
          );
        }
      }
    }

    final finalDetections = _nms(detections);
    if (finalDetections.isNotEmpty) {
      print('Detected: ${finalDetections.map((d) => d.label).toList()}');
    } else if (maxConfidenceFound > 0.05) {
      print('No detection. Max confidence: ${maxConfidenceFound.toStringAsFixed(3)}');
    }
    return finalDetections;
  }

  /// Non-Maximum Suppression to remove overlapping boxes.
  List<DetectionResult> _nms(List<DetectionResult> results) {
    if (results.isEmpty) return [];
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    final finalResults = <DetectionResult>[];
    final isRemoved = List<bool>.filled(results.length, false);

    for (int i = 0; i < results.length; i++) {
      if (isRemoved[i]) continue;
      finalResults.add(results[i]);
      for (int j = i + 1; j < results.length; j++) {
        if (isRemoved[j]) continue;
        if (_calculateIoU(results[i].boundingBox, results[j].boundingBox) > _iouThreshold) {
          isRemoved[j] = true;
        }
      }
    }
    return finalResults.take(10).toList();
  }

  double _calculateIoU(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;
    final intersectionArea = intersection.width * intersection.height;
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    return intersectionArea / (areaA + areaB - intersectionArea);
  }

  String _translateToArabic(String englishLabel) {
    return _arabicMap[englishLabel.toLowerCase()] ?? englishLabel;
  }

  static const Map<String, String> _arabicMap = {
    'person': 'شخص', 'bicycle': 'دراجة', 'car': 'سيارة', 'motorcycle': 'دراجة نارية',
    'airplane': 'طائرة', 'bus': 'حافلة', 'train': 'قطار', 'truck': 'شاحنة',
    'boat': 'قارب', 'traffic light': 'إشارة مرور', 'fire hydrant': 'صنبور حريق',
    'stop sign': 'علامة قف', 'parking meter': 'عداد موقف', 'bench': 'مقعد',
    'bird': 'طائر', 'cat': 'قطة', 'dog': 'كلب', 'horse': 'حصان', 'sheep': 'خروف',
    'cow': 'بقرة', 'elephant': 'فيل', 'bear': 'دب', 'zebra': 'حمار وحشي', 'giraffe': 'زرافة',
    'backpack': 'حقيبة ظهر', 'umbrella': 'شemsية', 'handbag': 'حقيبة يد',
    'tie': 'ربطة عنق', 'suitcase': 'حقيبة سفر', 'frisbee': 'فرسبي', 'skis': 'زلاجات',
    'snowboard': 'لوح تزلج', 'sports ball': 'كرة', 'kite': 'طائرة ورقية',
    'baseball bat': 'مضرب بيسبول', 'baseball glove': 'قفاز بيسبول',
    'skateboard': 'لوح تزلج', 'surfboard': 'لوح ركوب الأمواج', 'tennis racket': 'مضرب تنس',
    'bottle': 'زجاجة', 'wine glass': 'كأس', 'cup': 'كوب', 'fork': 'شوكة',
    'knife': 'سكين', 'spoon': 'ملعقة', 'bowl': 'وعاء', 'banana': 'موز', 'apple': 'تفاح',
    'sandwich': 'شطيرة', 'orange': 'برتقال', 'broccoli': 'بروكلي', 'carrot': 'جزر',
    'hot dog': 'نقانق', 'pizza': 'بيتزا', 'donut': 'دونات', 'cake': 'كعكة',
    'chair': 'كرسي', 'couch': 'أريكة', 'potted plant': 'نبات',
    'bed': 'يatak', 'dining table': 'طاولة طعام', 'toilet': 'مرحاض', 'tv': 'تلفاز',
    'laptop': 'لابتوب', 'mouse': 'فأرة', 'remote': 'جهاز تحكم', 'keyboard': 'لوحة مفاتيح',
    'cell phone': 'هاتف', 'microwave': 'مايكرويف', 'oven': 'فرن', 'toaster': 'محمصة',
    'sink': 'مغسلة', 'refrigerator': 'ثلاجة', 'book': 'كتاب', 'clock': 'ساعة',
    'vase': 'مزهرية', 'scissors': 'مقص', 'teddy bear': 'دب لعبة',
    'hair dryer': 'مجفف شعر', 'toothbrush': 'فرشاة أسنان'
  };

  Future<void> dispose() async {
    _interpreter?.close();
    _isInitialized = false;
  }
}
