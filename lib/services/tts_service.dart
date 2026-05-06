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

  /// Initialize TTS engine with US English language and optimized settings.
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

    // Set language to US English (MANDATORY FIRST)
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Get all available voices to find a natural English one
    final voices = await _flutterTts.getVoices;
    if (voices is List) {
      final voiceList = List<Map<dynamic, dynamic>>.from(voices);
      
      // Filter for US English voices only
      final englishVoices = voiceList.where((v) {
        final locale = v['locale']?.toString().toLowerCase() ?? '';
        return locale == 'en-us' || locale == 'en_us';
      }).toList();

      if (englishVoices.isNotEmpty) {
        // Find a high-quality "network" voice or just a natural sounding one
        final selectedVoice = englishVoices.firstWhere(
          (v) => v['name']?.toString().toLowerCase().contains('network') ?? false,
          orElse: () => englishVoices.first,
        );

        final voiceName = selectedVoice['name']?.toString();
        if (voiceName != null) {
          await _flutterTts.setVoice({
            'name': voiceName,
            'locale': selectedVoice['locale']?.toString() ?? 'en-US',
          });
          print('TTS Hard-Forced Voice: $voiceName');
        }
      } else {
        print('TTS Warning: No en-US voices found, staying with system default en-US');
      }
    }

    // Set completion handler to track TTS state
    _flutterTts.setStartHandler(() {
      if (onSpeechStart != null) onSpeechStart!();
    });
    
    _flutterTts.setCompletionHandler(() {
      print('TTS: Finished speaking');
      if (onSpeechFinished != null) onSpeechFinished!();
    });
    
    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      if (onProgress != null) {
        onProgress!(text, start, end, word);
      }
    });

    _flutterTts.setErrorHandler((msg) {
      print('TTS Error: $msg');
    });
  }

  /// Callbacks for progress tracking
  void Function(String text, int start, int end, String word)? onProgress;
  void Function()? onSpeechStart;
  void Function()? onSpeechFinished;

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
