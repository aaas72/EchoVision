import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'AIzaSyAzfEZpo3tJtU2kwDQ8TMmzhhmiO4HuSNM';
  const url = 'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';

  print('Listing models via REST...');
  
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final models = data['models'] as List;
      print('Available Models:');
      for (var m in models) {
        print('- ${m['name']}');
      }
    } else {
      print('FAILURE! Status: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
