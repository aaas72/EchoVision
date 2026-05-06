import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import '../domain/models/detection_result.dart';

/// Data passed to the background isolate for inference.
class _InferenceData {
  final int interpreterAddress;
  final img.Image image;
  final int inputSize;
  final List<String> labels;

  _InferenceData(this.interpreterAddress, this.image, this.inputSize, this.labels);
}

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

      // 2. Initialize TFLite Interpreter with 4 threads
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

      // Use compute to run inference in a background isolate
      return await compute(_processImageInIsolate, _InferenceData(
        _interpreter!.address,
        decoded,
        _inputSize,
        _labels,
      ));
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

      // Use compute to run inference in a background isolate
      return await compute(_processImageInIsolate, _InferenceData(
        _interpreter!.address,
        decoded,
        _inputSize,
        _labels,
      ));
    } catch (e) {
      print('YOLO11 File Inference Error: $e');
      return [];
    }
  }

  /// Entry point for background isolate inference.
  static List<DetectionResult> _processImageInIsolate(_InferenceData data) {
    final sw = Stopwatch()..start();
    final interpreter = Interpreter.fromAddress(data.interpreterAddress);
    
    // 1. Preprocessing: Resize
    final resized = img.copyResize(data.image, width: data.inputSize, height: data.inputSize);
    final resizeTime = sw.elapsedMilliseconds;
    
    // 2. Input preparation using TypedData
    final input = Float32List(1 * data.inputSize * data.inputSize * 3);
    var bufferIndex = 0;
    for (var y = 0; y < data.inputSize; y++) {
      for (var x = 0; x < data.inputSize; x++) {
        final p = resized.getPixel(x, y);
        input[bufferIndex++] = p.r / 255.0;
        input[bufferIndex++] = p.g / 255.0;
        input[bufferIndex++] = p.b / 255.0;
      }
    }
    final preProcessTime = sw.elapsedMilliseconds;

    // 3. Inference
    final outputTensor = interpreter.getOutputTensor(0);
    final shape = outputTensor.shape;
    final numChannels = shape[1]; 
    final numAnchors = shape[2];  
    
    final output = List.filled(1 * numChannels * numAnchors, 0.0)
        .reshape([1, numChannels, numAnchors]);

    interpreter.run(input.reshape([1, data.inputSize, data.inputSize, 3]), output);
    final inferenceTime = sw.elapsedMilliseconds - preProcessTime;

    // 4. Postprocessing (NMS)
    final detections = _staticProcessOutputs(output, data.labels, data.inputSize);
    final totalTime = sw.elapsedMilliseconds;
    
    print('YOLO Isolate Performance: Total ${totalTime}ms | Resize ${resizeTime}ms | Pre ${preProcessTime-resizeTime}ms | Infer ${inferenceTime}ms');
    
    return detections;
  }

  /// Internal processing logic moved to static for Isolate compatibility.
  static List<DetectionResult> _staticProcessOutputs(List<dynamic> output, List<String> labels, int inputSize) {
    final detections = <DetectionResult>[];
    final numChannels = output[0].length;
    final numAnchors = output[0][0].length;
    const confThreshold = 0.30;

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

      if (maxScore > confThreshold) {
        final cx = output[0][0][i];
        final cy = output[0][1][i];
        final w = output[0][2][i];
        final h = output[0][3][i];

        final x1 = (cx - w / 2) / inputSize;
        final y1 = (cy - h / 2) / inputSize;
        final x2 = (cx + w / 2) / inputSize;
        final y2 = (cy + h / 2) / inputSize;

        if (maxClassIndex < labels.length) {
          detections.add(
            DetectionResult(
              label: labels[maxClassIndex],
              confidence: maxScore,
              boundingBox: Rect.fromLTRB(x1, y1, x2, y2),
              source: DetectionSource.tflite,
            ),
          );
        }
      }
    }

    return _staticNms(detections);
  }

  /// Helper for static NMS.
  static List<DetectionResult> _staticNms(List<DetectionResult> results) {
    if (results.isEmpty) return [];
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    final finalResults = <DetectionResult>[];
    final isRemoved = List<bool>.filled(results.length, false);

    for (int i = 0; i < results.length; i++) {
      if (isRemoved[i]) continue;
      finalResults.add(results[i]);
      for (int j = i + 1; j < results.length; j++) {
        if (isRemoved[j]) continue;
        if (_staticCalculateIoU(results[i].boundingBox, results[j].boundingBox) > 0.45) {
          isRemoved[j] = true;
        }
      }
    }
    return finalResults.take(10).toList();
  }

  static double _staticCalculateIoU(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;
    final intersectionArea = intersection.width * intersection.height;
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    return intersectionArea / (areaA + areaB - intersectionArea);
  }


  Future<void> dispose() async {
    _interpreter?.close();
    _isInitialized = false;
  }
}
