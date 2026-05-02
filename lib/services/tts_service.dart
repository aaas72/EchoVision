import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';

/// Service responsible for text-to-speech output with debounce logic.
/// Prevents spamming the user by only repeating the same label
/// after [AppConstants.ttsDebounceSeconds] seconds.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final Map<String, DateTime> _lastSpoken = {};
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  /// Initialize TTS engine with Turkish language and optimized settings.
  Future<void> initialize() async {
    // Try to use Google TTS engine for better quality
    final engines = await _flutterTts.getEngines;
    if (engines is List) {
      final engineList = List<String>.from(engines.map((e) => e.toString()));
      print('TTS Available engines: $engineList');

      // Prefer Google TTS engine for better quality
      for (final engine in engineList) {
        if (engine.toLowerCase().contains('google')) {
          await _flutterTts.setEngine(engine);
          print('TTS Using engine: $engine');
          break;
        }
      }
    }

    // Set volume to maximum
    await _flutterTts.setVolume(1.0);

    // Slightly higher pitch for clearer voice (1.0 = normal, 1.1 = slightly higher)
    await _flutterTts.setPitch(1.05);

    // Try Arabic variants in order of preference
    final languages = await _flutterTts.getLanguages;
    String selectedLang = 'en-US'; // fallback

    if (languages is List) {
      final langList = List<String>.from(languages.map((e) => e.toString()));
      print('TTS Available languages: $langList');

      // Try Arabic variants
      for (final lang in ['ar-SA', 'ar', 'ara']) {
        if (langList.any((l) => l.toLowerCase() == lang.toLowerCase())) {
          selectedLang = lang;
          break;
        }
      }
    }

    print('TTS Selected language: $selectedLang');
    await _flutterTts.setLanguage(selectedLang);

    // Slightly slower speech rate for better clarity
    await _flutterTts.setSpeechRate(0.50);

    // Try to select a voice if available
    final voices = await _flutterTts.getVoices;
    if (voices is List) {
      final voiceList = List<Map<dynamic, dynamic>>.from(voices);
      print('TTS Available voices: ${voiceList.length}');

      // Find Arabic voices
      final arabicVoices = voiceList.where((v) {
        final locale = v['locale']?.toString().toLowerCase() ?? '';
        return locale.contains('ar');
      }).toList();

      if (arabicVoices.isNotEmpty) {
        var selectedVoice = arabicVoices.first;

        final voiceName = selectedVoice['name']?.toString();
        if (voiceName != null) {
          await _flutterTts.setVoice({
            'name': voiceName,
            'locale': selectedVoice['locale']?.toString() ?? 'ar-SA',
          });
          print('TTS Selected voice: $voiceName');
        }
      }
    }

    // Set completion handler to track TTS state
    _flutterTts.setCompletionHandler(() {
      print('TTS: Finished speaking');
    });
    _flutterTts.setErrorHandler((msg) {
      print('TTS Error: $msg');
    });
  }

  /// Speak the given [text] with debounce logic.
  /// Won't repeat the same text within [AppConstants.ttsDebounceSeconds].
  Future<void> speak(String text) async {
    if (_isMuted) return;

    final now = DateTime.now();
    final lastTime = _lastSpoken[text];

    if (lastTime != null &&
        now.difference(lastTime).inSeconds < AppConstants.ttsDebounceSeconds) {
      return; // Debounce: skip if spoken recently
    }

    _lastSpoken[text] = now;
    await _flutterTts.speak(text);
  }

  /// Speak immediately without debounce (for system messages).
  Future<void> speakImmediate(String text) async {
    if (_isMuted) return;
    await _flutterTts.speak(text);
  }

  /// Toggle mute state. Returns the new mute state.
  bool toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _flutterTts.stop();
    }
    return _isMuted;
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  /// Dispose TTS resources.
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}
