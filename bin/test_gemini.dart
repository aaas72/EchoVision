import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  const apiKey = 'AIzaSyAzfEZpo3tJtU2kwDQ8TMmzhhmiO4HuSNM';
  
  print('--- Gemini API Connection Test (2.0 Flash) ---');
  
  final model = GenerativeModel(
    model: 'gemini-flash-latest',
    apiKey: apiKey,
  );

  try {
    print('Sending a test prompt to Gemini...');
    final response = await model.generateContent([
      Content.text('Please reply with "Connection Successful" if you can read this message.')
    ]);

    if (response.text != null) {
      print('\n[SUCCESS] Gemini responded:');
      print('"${response.text!.trim()}"');
      print('\nYour API key is working correctly with Gemini 2.0 Flash!');
    } else {
      print('\n[WARNING] Received empty response from Gemini.');
    }
  } catch (e) {
    print('\n[FAILURE] Error connecting to Gemini API:');
    print(e.toString());
  }
}
