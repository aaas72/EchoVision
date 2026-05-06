import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  // Read key from .env manually for this test
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final apiKey = lines.firstWhere((l) => l.startsWith('GEMINI_API_KEY=')).split('=')[1];

  print('--- Gemini Real-World Test ---');
  print('Model: gemini-flash-latest');
  
  final model = GenerativeModel(
    model: 'gemini-flash-latest',
    apiKey: apiKey,
  );

  final stopwatch = Stopwatch()..start();
  
  try {
    print('Sending prompt...');
    final response = await model.generateContent([
      Content.text('Describe your capabilities for a blind user briefly.')
    ]);
    
    stopwatch.stop();
    
    print('\n[SUCCESS] Time taken: ${stopwatch.elapsedMilliseconds}ms');
    print('Gemini Output:');
    print('--------------------------------------------------');
    print(response.text);
    print('--------------------------------------------------');
    print('\nAPI is responsive and ready for action.');
  } catch (e) {
    print('\n[FAILURE] Error: $e');
  }
}
