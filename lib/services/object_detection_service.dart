import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

// ─── COCO 80 Classes ──────────────────────────────────────────────────────────
const List<String> _cocoLabels = [
  'person',
  'bicycle',
  'car',
  'motorcycle',
  'airplane',
  'bus',
  'train',
  'truck',
  'boat',
  'traffic light',
  'fire hydrant',
  'stop sign',
  'parking meter',
  'bench',
  'bird',
  'cat',
  'dog',
  'horse',
  'sheep',
  'cow',
  'elephant',
  'bear',
  'zebra',
  'giraffe',
  'backpack',
  'umbrella',
  'handbag',
  'tie',
  'suitcase',
  'frisbee',
  'skis',
  'snowboard',
  'sports ball',
  'kite',
  'baseball bat',
  'baseball glove',
  'skateboard',
  'surfboard',
  'tennis racket',
  'bottle',
  'wine glass',
  'cup',
  'fork',
  'knife',
  'spoon',
  'bowl',
  'banana',
  'apple',
  'sandwich',
  'orange',
  'broccoli',
  'carrot',
  'hot dog',
  'pizza',
  'donut',
  'cake',
  'chair',
  'couch',
  'potted plant',
  'bed',
  'dining table',
  'toilet',
  'tv',
  'laptop',
  'mouse',
  'remote',
  'keyboard',
  'cell phone',
  'microwave',
  'oven',
  'toaster',
  'sink',
  'refrigerator',
  'book',
  'clock',
  'vase',
  'scissors',
  'teddy bear',
  'hair dryer',
  'toothbrush',
];

const Map<String, String> _cocoTurkish = {
  'person': 'kişi',
  'bicycle': 'bisiklet',
  'car': 'araba',
  'motorcycle': 'motosiklet',
  'airplane': 'uçak',
  'bus': 'otobüs',
  'train': 'tren',
  'truck': 'kamyon',
  'boat': 'tekne',
  'traffic light': 'trafik ışığı',
  'fire hydrant': 'yangın musluğu',
  'stop sign': 'dur işareti',
  'parking meter': 'parkmetre',
  'bench': 'bank',
  'bird': 'kuş',
  'cat': 'kedi',
  'dog': 'köpek',
  'horse': 'at',
  'sheep': 'koyun',
  'cow': 'inek',
  'elephant': 'fil',
  'bear': 'ayı',
  'zebra': 'zebra',
  'giraffe': 'zürafa',
  'backpack': 'sırt çantası',
  'umbrella': 'şemsiye',
  'handbag': 'el çantası',
  'tie': 'kravat',
  'suitcase': 'bavul',
  'frisbee': 'frizbi',
  'skis': 'kayak',
  'snowboard': 'snowboard',
  'sports ball': 'top',
  'kite': 'uçurtma',
  'baseball bat': 'beyzbol sopası',
  'baseball glove': 'beyzbol eldiveni',
  'skateboard': 'kaykay',
  'surfboard': 'sörf tahtası',
  'tennis racket': 'tenis raketi',
  'bottle': 'şişe',
  'wine glass': 'şarap kadehi',
  'cup': 'bardak',
  'fork': 'çatal',
  'knife': 'bıçak',
  'spoon': 'kaşık',
  'bowl': 'kase',
  'banana': 'muz',
  'apple': 'elma',
  'sandwich': 'sandviç',
  'orange': 'portakal',
  'broccoli': 'brokoli',
  'carrot': 'havuç',
  'hot dog': 'sosisli',
  'pizza': 'pizza',
  'donut': 'donut',
  'cake': 'pasta',
  'chair': 'sandalye',
  'couch': 'kanepe',
  'potted plant': 'saksı bitkisi',
  'bed': 'yatak',
  'dining table': 'yemek masası',
  'toilet': 'tuvalet',
  'tv': 'televizyon',
  'laptop': 'laptop',
  'mouse': 'fare',
  'remote': 'kumanda',
  'keyboard': 'klavye',
  'cell phone': 'telefon',
  'microwave': 'mikrodalga',
  'oven': 'fırın',
  'toaster': 'tost makinesi',
  'sink': 'lavabo',
  'refrigerator': 'buzdolabı',
  'book': 'kitap',
  'clock': 'saat',
  'vase': 'vazo',
  'scissors': 'makas',
  'teddy bear': 'oyuncak ayı',
  'hair dryer': 'saç kurutma makinesi',
  'toothbrush': 'diş fırçası',
};

/// Object detection service that adapts to either SSD MobileNet or YOLOv8n.
class ObjectDetectionService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _isYolo = false;

  // Initial config - will update after model inspection
  int _inputSize = 300;
  static const double _confThreshold = 0.20; // Lowered to detect more objects
  static const double _iouThreshold = 0.45;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/detect.tflite',
        options: options,
      );

      // Auto-detect model type
      // Check input tensor shape
      final inputTensor = _interpreter!.getInputTensor(0);
      _inputSize = inputTensor.shape[1]; // Typically 300 (SSD) or 640 (YOLO)

      // Check output tensors
      final outputTensors = _interpreter!.getOutputTensors();
      // YOLOv8n typically has 1 output tensor [1, 84, 8400]
      // SSD MobileNet typically has 4 output tensors [locations, classes, scores, count]

      if (outputTensors.length == 1 && outputTensors[0].shape.length == 3) {
        _isYolo = true;
        print(
            'TFLite: Detected YOLOv8n model (Input: $_inputSize, Output: ${outputTensors[0].shape})');
      } else {
        _isYolo = false;
        print(
            'TFLite: Detected SSD MobileNet model (Input: $_inputSize, Outputs: ${outputTensors.length})');
      }

      _isInitialized = true;
    } catch (e) {
      print('TFLite init error: $e');
      _isInitialized = false;
    }
  }

  /// Analyze a captured image. Returns Turkish names of detected objects.
  Future<List<String>> analyzeImage(XFile imageFile) async {
    if (!_isInitialized || _interpreter == null) return [];

    if (_isYolo) {
      return _analyzeYolo(imageFile);
    } else {
      return _analyzeSSD(imageFile);
    }
  }

  // ─── YOLO Logic ─────────────────────────────────────────────────────────────
  Future<List<String>> _analyzeYolo(XFile imageFile) async {
    try {
      final bytes = await File(imageFile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];

      final resized =
          img.copyResize(decoded, width: _inputSize, height: _inputSize);

      // Normalize [0..1]
      final input = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              final p = resized.getPixel(x, y);
              return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
            },
          ),
        ),
      );

      final outputTensor = _interpreter!.getOutputTensor(0);
      final shape = outputTensor.shape;
      // Expected [1, 84, 8400]
      final numChannels = shape[1];
      final numAnchors = shape[2];

      final output = List.filled(1 * numChannels * numAnchors, 0.0)
          .reshape([1, numChannels, numAnchors]);

      _interpreter!.run(input, output);

      final detections = <_Detection>[];
      for (int i = 0; i < numAnchors; i++) {
        double maxScore = 0.0;
        int maxClassIndex = -1;

        // First 4 are box, rest are classes
        for (int c = 0; c < (numChannels - 4); c++) {
          final score = output[0][4 + c][i];
          if (score > maxScore) {
            maxScore = score;
            maxClassIndex = c;
          }
        }

        if (maxScore > _confThreshold) {
          final cx = output[0][0][i];
          final cy = output[0][1][i];
          final w = output[0][2][i];
          final h = output[0][3][i];

          final x1 = (cx - w / 2);
          final y1 = (cy - h / 2);
          final x2 = (cx + w / 2);
          final y2 = (cy + h / 2);

          final label = _getLabel(maxClassIndex);
          detections.add(_Detection(label, maxScore, [x1, y1, x2, y2]));
        }
      }

      return _processResults(detections);
    } catch (e) {
      print('YOLO Error: $e');
      return [];
    }
  }

  // ─── SSD Logic ──────────────────────────────────────────────────────────────
  Future<List<String>> _analyzeSSD(XFile imageFile) async {
    try {
      final bytes = await File(imageFile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];

      // SSD often benefits from slight contrast boost
      final enhanced = img.adjustColor(decoded, contrast: 1.1);
      final resized =
          img.copyResize(enhanced, width: _inputSize, height: _inputSize);

      // Input [0..255] uint8
      final input = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              final p = resized.getPixel(x, y);
              return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
            },
          ),
        ),
      );

      // Output maps
      final outBoxes = [List.generate(10, (_) => List.filled(4, 0.0))];
      final outClasses = [List.filled(10, 0.0)];
      final outScores = [List.filled(10, 0.0)];
      final outCount = [0.0];

      final outputs = {
        0: outBoxes,
        1: outClasses,
        2: outScores,
        3: outCount,
      };

      _interpreter!.runForMultipleInputs([input], outputs);

      final detections = <_Detection>[];
      final count = outCount[0].toInt().clamp(0, 10);

      for (int i = 0; i < count; i++) {
        final score = outScores[0][i];
        if (score < _confThreshold) continue;

        final classIdx = outClasses[0][i].toInt();
        final label = _getLabel(classIdx);

        // Ensure box coords are valid if we need them (SSD gives [y1, x1, y2, x2] normalized)
        // For simple labeling we just need the class and score
        detections.add(_Detection(label, score, [0, 0, 0, 0]));
      }

      // SSD usually has NMS built-in or pre-filtered, so we might skip NMS or just dedupe
      return _processResults(detections, applyNms: false);
    } catch (e) {
      print('SSD Error: $e');
      return [];
    }
  }

  String _getLabel(int index) {
    if (index >= 0 && index < _cocoLabels.length) {
      final eng = _cocoLabels[index];
      return _cocoTurkish[eng] ?? '';
    }
    return '';
  }

  List<String> _processResults(List<_Detection> detections,
      {bool applyNms = true}) {
    List<_Detection> processed = detections;

    if (applyNms && processed.isNotEmpty) {
      processed = _nonMaxSuppression(processed, _iouThreshold);
    }

    processed.sort((a, b) => b.score.compareTo(a.score));

    final uniqueLabels = <String>{};
    final results = <String>[];
    for (final d in processed) {
      if (d.label.isNotEmpty && uniqueLabels.add(d.label)) {
        results.add(d.label);
        // Debug print
        print(
            'Detected (${_isYolo ? "YOLO" : "SSD"}): ${d.label} ${(d.score * 100).toInt()}%');
        // Removed limit to show all possible detections instead of just 6
        if (results.length >= 20) break;
      }
    }
    return results;
  }

  List<_Detection> _nonMaxSuppression(
      List<_Detection> boxes, double iouThreshold) {
    if (boxes.isEmpty) return [];

    boxes.sort((a, b) => b.score.compareTo(a.score));

    final selected = <_Detection>[];
    final active = List<bool>.filled(boxes.length, true);

    for (int i = 0; i < boxes.length; i++) {
      if (active[i]) {
        selected.add(boxes[i]);
        for (int j = i + 1; j < boxes.length; j++) {
          if (active[j]) {
            final iou = _calculateIoU(boxes[i].box, boxes[j].box);
            if (iou > iouThreshold) active[j] = false;
          }
        }
      }
    }
    return selected;
  }

  double _calculateIoU(List<double> boxA, List<double> boxB) {
    final xA = math.max(boxA[0], boxB[0]);
    final yA = math.max(boxA[1], boxB[1]);
    final xB = math.min(boxA[2], boxB[2]);
    final yB = math.min(boxA[3], boxB[3]);

    if (xB < xA || yB < yA) return 0.0;

    final interArea = (xB - xA) * (yB - yA);
    final boxAArea = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1]);
    final boxBArea = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1]);

    return interArea / (boxAArea + boxBArea - interArea);
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

/// Helper class for sorting detections by confidence
class _Detection {
  final String label;
  final double score;
  final List<double> box; // [x1, y1, x2, y2]
  _Detection(this.label, this.score, this.box);
}
