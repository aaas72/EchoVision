import 'dart:io';
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

/// Data passed to the background isolate for file inference.
class _FileInferenceData {
  final int interpreterAddress;
  final String filePath;
  final int inputSize;
  final List<String> labels;

  _FileInferenceData(this.interpreterAddress, this.filePath, this.inputSize, this.labels);
}

/// Optimized service for YOLO11n object detection.
class YoloService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<String> _labels = [];

  // YOLO11 COCO 80 Classes list
  static const List<String> _coco80Labels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat', 'traffic light',
    'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
    'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee',
    'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle',
    'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange',
    'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant', 'bed',
    'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven',
    'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
  ];

  // YOLO11n default input size
  static const int _inputSize = 640;

  bool get isInitialized => _isInitialized;

  /// Initialize YOLO11 engine.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // 1. Assign COCO 80 labels
      _labels = _coco80Labels;
      print('YOLO11: Configured with ${_labels.length} COCO labels');

      // 2. Initialize TFLite Interpreter with 4 threads
      final options = InterpreterOptions()..threads = 4;
      
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolo11n.tflite',
        options: options,
      );

      _isInitialized = true;
      print('YOLO11: Service initialized successfully with assets/models/yolo11n.tflite');
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
      } else if (image.format.group == ImageFormatGroup.jpeg) {
        // JPEG stream: decode directly from compressed bytes
        final jpegBytes = image.planes.first.bytes;
        final jpegDecoded = img.decodeJpg(jpegBytes);
        if (jpegDecoded == null) return [];
        decoded = jpegDecoded;
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
      // Offload file reading, decoding and inference entirely to background isolate
      return await compute(_processFileInIsolate, _FileInferenceData(
        _interpreter!.address,
        imageFile.path,
        _inputSize,
        _labels,
      ));
    } catch (e) {
      print('YOLO11 File Inference Error: $e');
      return [];
    }
  }

  /// Entry point for file decoding + inference isolate
  static List<DetectionResult> _processFileInIsolate(_FileInferenceData data) {
    try {
      final bytes = File(data.filePath).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];

      return _processImageInIsolate(_InferenceData(
        data.interpreterAddress,
        decoded,
        data.inputSize,
        data.labels,
      ));
    } catch (e) {
      print('Isolate File Process Error: $e');
      return [];
    }
  }

  /// Analyze image, find a hand, crop it, run a second pass of YOLO on the crop,
  /// and return detected objects within the hand (filtering out human parts).
  /// Fully executed in background isolate.
  Future<List<DetectionResult>> analyzeHandheldObject(XFile imageFile) async {
    if (!_isInitialized || _interpreter == null) return [];

    try {
      // Offload all logic (first pass, crop, second pass, mapping) to background isolate
      return await compute(_processHandheldInIsolate, _FileInferenceData(
        _interpreter!.address,
        imageFile.path,
        _inputSize,
        _labels,
      ));
    } catch (e) {
      print('YOLO Handheld Inference Error: $e');
      return [];
    }
  }

  /// Background isolate entry point for handheld center cropping and YOLO11 inference
  static List<DetectionResult> _processHandheldInIsolate(_FileInferenceData data) {
    try {
      final bytes = File(data.filePath).readAsBytesSync();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return [];

      final imgW = originalImage.width;
      final imgH = originalImage.height;

      // Crop the center 50% region of the image (horizontal 25%-75%, vertical 25%-75%)
      // where the user naturally holds the object in front of the camera lens.
      final cropX = (imgW * 0.25).toInt();
      final cropY = (imgH * 0.25).toInt();
      final cropW = (imgW * 0.50).toInt();
      final cropH = (imgH * 0.50).toInt();

      final croppedHandImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // Run YOLO11 inference on the cropped center region
      final croppedResults = _processImageInIsolate(_InferenceData(
        data.interpreterAddress,
        croppedHandImage,
        data.inputSize,
        data.labels,
      ));

      // Filter out 'person' as it represents the user themselves
      final filteredResults = croppedResults.where((d) {
        final labelLower = d.label.toLowerCase();
        return labelLower != 'person';
      }).toList();

      // Map coordinates back to original image space so bounding box overlays render in position
      final mappedResults = filteredResults.map((d) {
        final cropBox = d.boundingBox;
        
        final absX1 = cropBox.left * cropW;
        final absY1 = cropBox.top * cropH;
        final absX2 = cropBox.right * cropW;
        final absY2 = cropBox.bottom * cropH;
        
        final origX1 = cropX + absX1;
        final origY1 = cropY + absY1;
        final origX2 = cropX + absX2;
        final origY2 = cropY + absY2;
        
        final normX1 = origX1 / imgW;
        final normY1 = origY1 / imgH;
        final normX2 = origX2 / imgW;
        final normY2 = origY2 / imgH;
        
        return DetectionResult(
          label: d.label,
          confidence: d.confidence,
          boundingBox: Rect.fromLTRB(normX1, normY1, normX2, normY2),
          source: DetectionSource.tflite,
        );
      }).toList();

      return mappedResults;
    } catch (e) {
      print('Isolate Handheld Process Error: $e');
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
    
    print('YOLOv8-OIV7 Isolate Performance: Total ${totalTime}ms | Resize ${resizeTime}ms | Pre ${preProcessTime-resizeTime}ms | Infer ${inferenceTime}ms');
    
    return detections;
  }

  /// Internal processing logic moved to static for Isolate compatibility.
  static List<DetectionResult> _staticProcessOutputs(List<dynamic> output, List<String> labels, int inputSize) {
    final detections = <DetectionResult>[];
    final numChannels = output[0].length;
    final numAnchors = output[0][0].length;
    const confThreshold = 0.20; // Lowered from 0.30 to detect more common objects in diverse conditions

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
