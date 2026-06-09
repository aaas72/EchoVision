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
    const avoidMarkdown = 'ÖNEMLİ: Görme engelli bir kişinin kulaklığına doğrudan konuşuyorsunuz. ASLA "Bu resimde", "Görebiliyorum", "Fotoğraf gösteriyor ki" veya "Burada" gibi ifadeler kullanmayın. ASLA markdown formatı, madde işaretleri veya emojiler kullanmayın. Kısa, doğal ve akıcı bir Türkçe ile konuşun.';

    switch (mode) {
      case DetectionMode.scene:
        return 'Betimleyici bir rehber gibi davranın. Görme engelli kullanıcının zihninde bir harita oluşturabilmesi için çevrenin net bir mekansal düzenini sağlayın. Doğrudan önünde ne olduğunu, ardından solundakileri ve sağındakileri açıklayın. Işıklandırmayı, mekanın türünü (örneğin bir ofis veya hareketli bir cadde) ve belirgin nesneleri belirtin. Açıklayıcı olun ancak konuşma dilinde ve dinlemesi kolay bir ton kullanın. $avoidMarkdown';
      
      case DetectionMode.currency:
        return 'Güvenilir bir para sayacı gibi davranın. Kullanıcıya görünen banknotların tam değerini söyleyin. Eğer para görünmüyorsa kesinlikle "Hiçbir para algılanmadı." deyin. Çok kısa ve doğrudan tutun. $avoidMarkdown';
      
      case DetectionMode.medication:
        return 'Görme engelli bir kullanıcıya yardımcı olan kısa ve insansı bir tıbbi asistan gibi davranın. KRİTİK KURAL: İlk olarak, görüntüdeki nesnenin gerçekten bir ilaç veya tıbbi ürün olup olmadığını kesin olarak doğrulayın. Eğer tıbbi bir ürün DEĞİLSE, HEMEN ve YALNIZCA şu yanıtı verin: "Bu tıbbi bir ürün değil. Lütfen kamerayı bir ilaca doğrultun." Eğer bir tıbbi ürün İSE, sözü uzatmayın. Paketin üzerinde yazan ilaç adını, dozajını ve amacını çok net, kısa ve önemli bir özet şeklinde verin. Hiçbir şeyi tahmin etmeyin. Türkçe olarak doğal bir şekilde yanıtlayın. $avoidMarkdown';
      
      default:
        return 'Kameranın önündeki nesneleri veya metni, tıpkı gören bir rehber gibi, net ve samimi bir şekilde Türkçe olarak betimleyin. $avoidMarkdown';
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
    if (!_isInitialized) return 'Gemini servisi başlatılmadı.';
    if (_lastImageBytes == null) return 'Lütfen önce bir resmi tarayın.';

    try {
      _chatHistory.add(Content.text(
        '$question. ÖNEMLİ: Yanıtınızı kısa, net ve doğrudan tutun. Markdown veya emoji kullanmayın. Türkçe yanıt verin.'
      ));

      final response = await _model.generateContent(_chatHistory);
      String resultText = response.text ?? 'Yanıt alınamadı.';

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
      return 'Üzgünüm, soruyu analiz edemedim.';
    }
  }

  /// Reset the current Visual Q&A conversation session.
  void clearSession() {
    _lastImageBytes = null;
    _chatHistory.clear();
  }
}
