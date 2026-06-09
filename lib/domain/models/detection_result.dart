import 'dart:ui';

const Map<String, String> cocoLabelsTr = {
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
  'parking meter': 'park metresi',
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
  'suitcase': 'valiz',
  'frisbee': 'frizbi',
  'skis': 'kayak',
  'snowboard': 'kar tahtası',
  'sports ball': 'spor topu',
  'kite': 'uçurtma',
  'baseball bat': 'beyzbol sopası',
  'baseball glove': 'beyzbol eldiveni',
  'skateboard': 'kaykay',
  'surfboard': 'sörf tahtası',
  'tennis racket': 'tenis raketi',
  'bottle': 'şişe',
  'wine glass': 'şarap kadehi',
  'cup': 'fincan',
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
  'hot dog': 'sosisli sandviç',
  'pizza': 'pizza',
  'donut': 'donut',
  'cake': 'kek',
  'chair': 'sandalye',
  'couch': 'koltuk',
  'potted plant': 'saksı bitkisi',
  'bed': 'yatak',
  'dining table': 'yemek masası',
  'toilet': 'tuvalet',
  'tv': 'televizyon',
  'laptop': 'dizüstü bilgisayar',
  'mouse': 'fare',
  'remote': 'kumanda',
  'keyboard': 'klavye',
  'cell phone': 'cep telefonu',
  'microwave': 'mikrodalga',
  'oven': 'fırın',
  'toaster': 'ekmek kızartma makinesi',
  'sink': 'lavabo',
  'refrigerator': 'buzdolabı',
  'book': 'kitap',
  'clock': 'saat',
  'vase': 'vazo',
  'scissors': 'makas',
  'teddy bear': 'oyuncak ayı',
  'hair drier': 'saç kurutma makinesi',
  'toothbrush': 'diş fırçası'
};

/// Represents a single detection with spatial data.
class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final DetectionSource source;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.source,
  });

  /// Calculates the position relative to the frame (0.0 to 1.0).
  double get centerX => boundingBox.center.dx;
  double get centerY => boundingBox.center.dy;

  /// Returns the Turkish translated label.
  String get turkishLabel => cocoLabelsTr[label.toLowerCase()] ?? label;

  /// Returns the horizontal position description in Turkish.
  String get horizontalPosition {
    if (centerX < 0.33) return 'solda';
    if (centerX > 0.66) return 'sağda';
    return 'ortada';
  }

  /// Estimates if the object is close based on bounding box area.
  /// (Simplified logic: Area > 40% of frame = Very Close).
  bool get isClose => (boundingBox.width * boundingBox.height) > 0.4;

  /// Returns a full descriptive sentence in Turkish using conversational design.
  String get description {
    String pos = horizontalPosition;
    String tLabel = turkishLabel;
    if (isClose) {
      return '$pos çok yakında bir $tLabel var';
    }
    return '$pos bir $tLabel var';
  }
}

enum DetectionSource {
  mlKit,
  tflite,
  gemini,
}
