import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

/// Gemini Vision API service for high-accuracy object detection.
/// Uses Google's Gemini 2.5 Flash model for image analysis.
/// Free tier: 15 requests/minute, 1500 requests/day.
class GeminiVisionService {
  static const String _apiKey = 'AIzaSyCZDsXbgmUCbco4NYnmZ7NQIr2LPjaeQ_Q';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _isInitialized = true;
    print('Gemini Vision: Service initialized');
  }

  /// Analyze image and return Turkish description of objects.
  Future<String> analyzeImage(XFile imageFile) async {
    if (!_isInitialized) return 'Servis başlatılmadı';

    try {
      // Read image and convert to base64
      final bytes = await File(imageFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine MIME type
      final extension = imageFile.path.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (extension == 'png') mimeType = 'image/png';
      if (extension == 'webp') mimeType = 'image/webp';

      // Build request body
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text':
                    '''Sen görme engelli kullanıcılar için bir yardımcı asistansın.
Bu fotoğrafta ne görüyorsun? Türkçe olarak kısa ve net bir şekilde açıkla.
Sadece gördüğün nesneleri ve sahneyi tanımla.
Maksimum 2-3 cümle kullan.
Örnek: "Önünüzde bir masa var. Masanın üzerinde bir laptop ve bir bardak su görüyorum."'''
              },
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'topK': 32,
          'topP': 1,
          'maxOutputTokens': 256,
        },
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE'
          }
        ]
      };

      // Make API request
      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Gemini API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.isNotEmpty) {
              print('Gemini Result: $text');
              return text.trim();
            }
          }
        }
        return 'Görüntü analiz edilemedi';
      } else {
        print('Gemini API Error: ${response.body}');
        if (response.statusCode == 429) {
          return 'Çok fazla istek. Lütfen biraz bekleyin.';
        }
        return 'API hatası: ${response.statusCode}';
      }
    } catch (e) {
      print('Gemini Vision Error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        return 'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.';
      }
      return 'Bir hata oluştu: $e';
    }
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }
}
