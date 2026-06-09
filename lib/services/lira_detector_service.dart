import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // for compute()
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─────────────────────────────────────────────────────────────────────────────
Float32List _preprocessInIsolate(Map<String, dynamic> args) {
  final Uint8List bytes = args['bytes'] as Uint8List;
  final int inputSize = args['inputSize'] as int;

  var decoded = img.decodeImage(bytes);
  if (decoded == null) return Float32List(0);

  decoded = img.bakeOrientation(decoded);

  // 🔴 SQUASH RESIZE 🔴
  // Since the training dataset images are 224x224 squares (likely squished),
  // we must squash the camera frame directly into 640x640 without cropping
  // or letterboxing, to exactly match how the model saw data during training.
  final resized = img.copyResize(decoded,
      width: inputSize, height: inputSize,
      interpolation: img.Interpolation.linear);

  final buffer = Float32List(inputSize * inputSize * 3);
  var idx = 0;
  for (var y = 0; y < inputSize; y++) {
    for (var x = 0; x < inputSize; x++) {
      final pixel = resized.getPixel(x, y);
      buffer[idx++] = pixel.r / 255.0;
      buffer[idx++] = pixel.g / 255.0;
      buffer[idx++] = pixel.b / 255.0;
    }
  }
  return buffer;
}

// ─────────────────────────────────────────────────────────────────────────────

class LiraDetectorService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  late final TextRecognizer _textRecognizer;

  static const int _inputSize = 640;

  static const List<String> _denominations = [
    "10 Türk Lirası",
    "100 Türk Lirası",
    "20 Türk Lirası",
    "200 Türk Lirası",
    "5 Türk Lirası",
    "50 Türk Lirası",
  ];

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // Initialize ML Kit Text Recognizer
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      // Initialize TFLite YOLOv11 model
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/lira.tflite',
        options: options,
      );
      _isInitialized = true;
      print('LiraDetector: ML Kit and YOLOv11 loaded successfully.');
    } catch (e) {
      print('LiraDetector: Model loading failed: $e');
      _isInitialized = false;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }

  Future<String> detectCurrency(File imageFile) async {
    if (!_isInitialized || _interpreter == null) {
      return "Çevrimdışı Mod: Banknot şekli algılandı. (Tam taramak için daha yakınlaştırın)";
    }

    try {
      // =======================================================================
      // PHASE 1: Google ML Kit Text Recognition (The Main Judge)
      // =======================================================================
      print("LiraDetector: Running ML Kit Text Recognition...");
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      
      // Look for specific Turkish Lira denominations in the text
      // We check from highest to lowest to prevent matching "10" inside "100" (handled by word boundaries).
      final RegExp numRegex = RegExp(r'\b(200|100|50|20|10|5)\b');
      final matches = numRegex.allMatches(fullText);
      
      if (matches.isNotEmpty) {
        // Count occurrences of each denomination
        final counts = <String, int>{};
        for (var match in matches) {
          final val = match.group(0)!;
          counts[val] = (counts[val] ?? 0) + 1;
        }
        
        // Find the most frequently occurring number
        String? bestDenom;
        int maxCount = 0;
        counts.forEach((key, count) {
          if (count > maxCount) {
            maxCount = count;
            bestDenom = key;
          }
        });
        
        if (bestDenom != null) {
          print("LiraDetector: ML Kit confidently found $bestDenom TL (Count: $maxCount)");
          return "$bestDenom Türk Lirası";
        }
      }

      print("LiraDetector: ML Kit did not find clear numbers. Falling back to YOLO.");

      // =======================================================================
      // PHASE 2: YOLOv11 Classification Fallback
      // =======================================================================
      final bytes = await imageFile.readAsBytes();

      final inputData = await compute(_preprocessInIsolate, {
        'bytes': bytes,
        'inputSize': _inputSize,
      });

      if (inputData.isEmpty) return "Görüntü okunamadı.";

      final output = [List<double>.filled(_denominations.length, 0.0)];

      _interpreter!.run(
        inputData.reshape([1, _inputSize, _inputSize, 3]),
        output,
      );

      final probs = output[0];

      int maxIndex = -1;
      double maxProb = -1.0;
      for (int i = 0; i < _denominations.length; i++) {
        if (probs[i] > maxProb) {
          maxProb = probs[i];
          maxIndex = i;
        }
      }

      final probLog = List.generate(_denominations.length,
          (i) => '${_denominations[i]}: ${(probs[i] * 100).toStringAsFixed(1)}%').join(' | ');
      print('LiraDetector Probs: $probLog');
      print('LiraDetector Winner: ${_denominations[maxIndex]} @ ${(maxProb * 100).toStringAsFixed(1)}%');

      // Reduced threshold because classification models are sensitive to real-world backgrounds
      if (maxIndex >= 0 && maxProb > 0.30) {
        return _denominations[maxIndex];
      } else {
        return "Net olmayan banknot. Lütfen banknotu ortalayıp tekrar deneyin.";
      }
    } catch (e) {
      print('LiraDetector Inference Error: $e');
      return "Tarama hatası. Lütfen daha iyi ışık altında tekrar deneyin.";
    }
  }
}