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

  Uint8List? _lastImageBytes;
  final List<Content> _chatHistory = [];

  Uint8List? get lastImageBytes => _lastImageBytes;
  bool get hasActiveSession => _lastImageBytes != null;


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

      // Keep image large enough for Gemini to read fine text (medication, currency)
      // but cap at 1920px to stay within API bandwidth limits
      final resizedImage = img.copyResize(
        decodedImage, 
        width: decodedImage.width > decodedImage.height ? 1920 : null,
        height: decodedImage.height >= decodedImage.width ? 1920 : null,
        interpolation: img.Interpolation.cubic, // Smooth downscale preserves text clarity
      );

      final compressedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 88));
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

          // Initialize visual Q&A session
          _lastImageBytes = compressedBytes;
          _chatHistory.clear();
          _chatHistory.add(Content.multi([
            DataPart('image/jpeg', compressedBytes),
            TextPart('This is the image we are discussing. Your initial description of the image was: "$resultText". Keep this context in mind for any follow-up questions.'),
          ]));

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
  /// Formulated to produce warm, humane, conversational, and alert speech outputs.
  String _getPromptForMode(DetectionMode mode) {
    const avoidMarkdown = 'IMPORTANT: You are speaking directly into the earpiece of a blind person. NEVER use phrases like "In this image", "I can see", "The photo shows", or "Here is". NEVER use markdown, bullet points, or emojis. Speak in concise, natural, spoken English.';

    switch (mode) {
      case DetectionMode.scene:
        return 'Act as a descriptive sighted guide. Provide a clear spatial layout of the environment so the blind user can build a mental map. Describe what is directly ahead, then to the left, then to the right. Mention the lighting, the type of place (e.g., an office, a busy street), and any prominent objects. Be descriptive but conversational and easy to listen to. $avoidMarkdown';
      
      case DetectionMode.currency:
        return 'Act as a reliable money counter. Tell the user the exact denominations of the banknotes visible. If no money is visible, strictly say "No currency detected." Keep it very short and direct. $avoidMarkdown';
      
      case DetectionMode.medication:
        return 'Act as a concise, human-like medical assistant helping a blind user. CRITICAL RULE: First, strictly verify if the object in the image is actually a medication or medical item. If it is NOT a medical item, reply IMMEDIATELY and ONLY with: "This is not a medical product. Please point the camera at a medication." If it IS a medical item, do not be verbose. Give a very clear, short, and important summary of the medication name, dosage, and purpose as written on the package. Do not guess anything. Respond naturally in English. $avoidMarkdown';
      
      default:
        return 'Describe the objects or text in front of the camera clearly and warmly, like a sighted guide. $avoidMarkdown';
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

  /// Ask a follow-up question about the last analyzed image.
  Future<String> askFollowUp(String question) async {
    if (!_isInitialized) return 'Gemini service not initialized.';
    if (_lastImageBytes == null) return 'Please scan an image first.';

    try {
      _chatHistory.add(Content.text(
        '$question. IMPORTANT: Keep your response short, clear, and direct. Do not use markdown or emojis.'
      ));

      final response = await _model.generateContent(_chatHistory);
      String resultText = response.text ?? 'No reply received.';

      resultText = resultText
          .replaceAll(RegExp(r'[\*\#\_]'), '') // Remove markdown symbols
          .replaceAll(RegExp(r'\s+'), ' ')     // Normalize spaces
          .trim();

      // Store in chat history
      _chatHistory.add(Content.model([TextPart(resultText)]));
      print('Gemini Q&A: $resultText');
      return resultText;
    } catch (e) {
      print('Gemini Q&A Error: $e');
      return 'Sorry, I could not analyze the question.';
    }
  }

  /// Reset the current Visual Q&A conversation session.
  void clearSession() {
    _lastImageBytes = null;
    _chatHistory.clear();
  }
}
