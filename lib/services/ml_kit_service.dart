import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

// هيكل بيانات مخصص لدمج نتيجتي المحركين معاً
class MLKitMergedResult {
  final List<DetectedObject> objects;
  final List<ImageLabel> labels;

  MLKitMergedResult(this.objects, this.labels);
}

class MLKitService {
  ObjectDetector? _objectDetector;
  ImageLabeler? _imageLabeler;
  bool _isReady = false;

  MLKitService() {
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    final modelPath =
        await _getModelPath('assets/models/mlkit_mobilenet.tflite');

    final objectOptions = LocalObjectDetectorOptions(
      mode: DetectionMode.stream,
      modelPath: modelPath,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: objectOptions);

    // 2. محرك التسمية الدقيقة (Image Labeler - يتعرف على 400+ عنصر)
    final labelerOptions = ImageLabelerOptions(confidenceThreshold: 0.75);
    _imageLabeler = ImageLabeler(options: labelerOptions);
    _isReady = true;
  }

  Future<String> _getModelPath(String assetPath) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await Directory(path).parent.create(recursive: true);
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  // الدالة الأساسية لاستقبال الإطار وتحليله بكلا المحركين
  Future<MLKitMergedResult?> processCameraImage(
      CameraImage image, int sensorOrientation) async {
    if (!_isReady || _objectDetector == null || _imageLabeler == null)
      return null;

    final inputImage =
        _convertCameraImageToInputImage(image, sensorOrientation);
    if (inputImage == null) return null;

    // تشغيل المحركين معاً في نفس اللحظة (بالتوازي) لتوفير الوقت
    final Future<List<DetectedObject>> objectsFuture =
        _objectDetector!.processImage(inputImage);
    final Future<List<ImageLabel>> labelsFuture =
        _imageLabeler!.processImage(inputImage);

    // انتظار النتيجتين
    final results = await Future.wait([objectsFuture, labelsFuture]);

    return MLKitMergedResult(
        results[0] as List<DetectedObject>, results[1] as List<ImageLabel>);
  }

  // 3. دالة التحويل المعقدة (Boilerplate) لدمج مستويات الصورة (Planes)
  InputImage? _convertCameraImageToInputImage(
      CameraImage image, int sensorOrientation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    // ضبط دوران الصورة لتتطابق مع وضعية الهاتف (لتجنب حساب الإحداثيات بشكل خاطئ)
    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation90deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  // تنظيف الموارد في حال الخروج من التطبيق للحفاظ على الذاكرة
  void dispose() {
    _objectDetector?.close();
    _imageLabeler?.close();
  }
}
