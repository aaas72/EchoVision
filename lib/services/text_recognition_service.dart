import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Fast, offline local text recognition service using Google ML Kit.
class TextRecognitionService {
  final TextRecognizer _textRecognizer;

  TextRecognitionService()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Analyzes an image file and extracts text offline.
  Future<String> recognizeText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.trim().isEmpty) {
        return 'Metin algılanmadı.';
      }
      
      // Clean and format the text slightly so it sounds good via TTS.
      final cleanText = recognizedText.text
          .replaceAll(RegExp(r'\n+'), ', ') // Replace newlines with commas for TTS pauses
          .replaceAll(RegExp(r'\s+'), ' ')  // Normalize spaces
          .trim();

      return cleanText;
    } catch (e) {
      print('TextRecognition Error: $e');
      return 'Metin okunurken hata oluştu.';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
