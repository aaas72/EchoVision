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
    const avoidMarkdown = ' IMPORTANT: Speak naturally as a human companion. Do not use any markdown symbols (like asterisks, hashtags, bullet lists). Speak in clear, fluent sentences without robotic prefixes.';

    switch (mode) {
      case DetectionMode.hazard:
        return 'Act as a protective, alert human guide warning a blind friend about physical dangers. If you detect immediate hazards (like stairs, cables on floor, holes, clutter, or sharp corners), speak in a realistic, urgent, and protective tone. For example: "Watch out! There is a cable on the floor right in front of you." or "Caution! There are steps descending on your left, please slow down." Be direct and helpful. $avoidMarkdown';
      
      case DetectionMode.scene:
        return 'Act as a warm, friendly human companion describing the room/surroundings to a blind friend. Speak in a conversational, comforting, and descriptive tone. For example: "Looking around, you are in a brightly lit room. In front of you, there is a large sofa..." or "Let\'s see what is around you. To your right, there is a door...". Describe the layout naturally (left, center, right). $avoidMarkdown';
      
      case DetectionMode.currency:
        return 'Act as a friendly, reassuring human assistant counting money. State the total amount and the specific bills warmly and clearly. For example: "You are holding a total of 150 Liras. That is a 100 Lira bill and a 50 Lira bill." or "You have a single 20 Lira bill in your hand." $avoidMarkdown';
      
      case DetectionMode.medication:
        return 'Act as a caring, extremely safety-oriented medical assistant checking a package. Guide the user gently. For example: "Let me check this medicine for you. This is Aspirin, 100 milligrams." Read the dosage ONLY if it is 100% clearly visible. If you cannot read it clearly, explicitly warn them: "I can see the medicine name is Ibuprofen, but the dosage is a bit blurry. Please ask someone to check this for you to be safe." Do not guess. $avoidMarkdown';
      
      default:
        return 'Describe the objects or text in front of the camera clearly and warmly, like a friendly companion describing things. $avoidMarkdown';
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
