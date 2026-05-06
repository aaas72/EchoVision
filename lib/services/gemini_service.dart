import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;
import '../core/enums/detection_mode.dart';

/// Service to interact with Google Gemini Vision API.
/// Handles detailed scene analysis, medication reading, and currency recognition.
class GeminiService {
  late final GenerativeModel _model;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  void initialize() {
    final apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    
    if (apiKey.isEmpty) {
      print('Gemini API Key missing in .env! Cloud features will not work.');
      return;
    }
    
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: apiKey,
    );
    _isInitialized = true;
  }

  /// Send image to Gemini for analysis based on the current mode.
  /// Includes automatic compression to reduce data usage.
  Future<String> describeImage(File imageFile, DetectionMode mode) async {
    if (!_isInitialized) return 'Gemini service not initialized.';

    try {
      // ── 1. Read and Compress Image ──
      final originalBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(originalBytes);
      
      if (decodedImage == null) return 'Failed to process image.';

      final resizedImage = img.copyResize(
        decodedImage, 
        width: decodedImage.width > decodedImage.height ? 1024 : null,
        height: decodedImage.height >= decodedImage.width ? 1024 : null,
      );

      final compressedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 75));
      print('Image compressed: ${originalBytes.length} -> ${compressedBytes.length} bytes');

      // ── 2. Send to Gemini with Retry Logic ──
      int retryCount = 0;
      const int maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          final content = [
            Content.multi([
              DataPart('image/jpeg', compressedBytes),
              TextPart(_getPromptForMode(mode)),
            ])
          ];

          final response = await _model.generateContent(content);
          String resultText = response.text ?? 'No description received.';
          
          // ── 3. Clean Text (Remove Markdown and Symbols) ──
          resultText = resultText
              .replaceAll(RegExp(r'[\*\#\_]'), '') // Remove markdown symbols
              .replaceAll(RegExp(r'In this image|I see|I can see|The photo shows|This is a photo of', caseSensitive: false), '') // Remove fillers
              .replaceAll(RegExp(r'\s+'), ' ')     // Normalize spaces
              .trim();

          // Capitalize first letter if needed
          if (resultText.isNotEmpty) {
            resultText = resultText[0].toUpperCase() + resultText.substring(1);
          }

          print('Gemini Response (Cleaned): $resultText');
          return resultText;
        } catch (e) {
          if (e.toString().contains('503') && retryCount < maxRetries - 1) {
            retryCount++;
            print('Gemini Busy (503). Retrying $retryCount/$maxRetries...');
            await Future.delayed(Duration(seconds: 1 * retryCount));
            continue;
          }
          
          print('Gemini Inner Error: $e');
          if (e.toString().contains('503')) {
            return 'The AI servers are very busy right now. Please try again in a few moments.';
          }
          return 'Sorry, I could not analyze the image right now.';
        }
      }
      return 'Sorry, the server is not responding.';
    } catch (e) {
      print('Gemini Outer Error: $e');
      return 'An error occurred while preparing the image.';
    }
  }

  /// Returns specialized prompts for different detection modes.
  String _getPromptForMode(DetectionMode mode) {
    const commonInstructions = ' IMPORTANT: Act as an objective, highly efficient visual assistant for a blind person. Give only the facts. Do not use any markdown (asterisks, hashtags). Do not say "In this image" or "I see". Be brief and clear.';

    switch (mode) {
      case DetectionMode.currency:
        return 'State the total amount of money and denominations. $commonInstructions';
      case DetectionMode.medication:
        return 'Identify the medicine name. Read the dosage ONLY if it is clearly visible. If you cannot read it clearly, explicitly say: "I cannot read the dosage clearly, please ask for help". Do NOT guess. $commonInstructions';
      case DetectionMode.scene:
        return 'Describe the path and surroundings layout (left, center, right) and any obstacles. $commonInstructions';
      case DetectionMode.hazard:
        return 'Warn about any immediate hazards like stairs, holes, or cables. $commonInstructions';
      default:
        return 'Describe the objects or texؤمسt in front of the camera clearly. $commonInstructions';
    }
  }

  /// Verification method to check if the API is responsive and the model is correct.
  Future<bool> verifyConnection() async {
    if (!_isInitialized) return false;
    try {
      final response = await _model.generateContent([Content.text('API Status Check. Reply with OK.')]);
      return response.text?.contains('OK') ?? false;
    } catch (e) {
      print('Gemini Verification Failed: $e');
      return false;
    }
  }
}
