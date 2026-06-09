import 'dart:convert';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants/app_constants.dart';

/// Service responsible for text-to-speech output with Google Cloud TTS and local fallback.
/// Prevents spamming the user by only repeating the same label
/// after [AppConstants.ttsDebounceSeconds] seconds.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _cloudAudioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final Map<String, DateTime> _lastSpoken = {};
  
  bool _isMuted = false;
  bool _useCloudTts = false;
  String? _googleApiKey;
  File? _tempAudioFile;
  bool _isSpeakingCloud = false;

  bool get isMuted => _isMuted;

  /// Callbacks for progress tracking
  void Function(String text, int start, int end, String word)? onProgress;
  void Function()? onSpeechStart;
  void Function()? onSpeechFinished;

  /// Initialize TTS engines.
  Future<void> initialize() async {
    // 1. Check Google Cloud API key
    _googleApiKey = dotenv.env['GOOGLE_CLOUD_TTS_API_KEY'];
    if (_googleApiKey == null || _googleApiKey!.isEmpty) {
      _googleApiKey = dotenv.env['GEMINI_API_KEY'];
    }

    if (_googleApiKey != null && _googleApiKey!.isNotEmpty) {
      _useCloudTts = true;
      print('TTS: Google Cloud API Key detected. Using Cloud TTS as primary engine.');
    } else {
      print('TTS: Google Cloud API Key missing. Using local TTS as primary.');
    }

    // 2. Setup temp directory for audio files
    try {
      final tempDir = await getTemporaryDirectory();
      _tempAudioFile = File('${tempDir.path}/gtts_cache.mp3');
    } catch (e) {
      print('TTS Error initializing temp dir: $e');
    }

    // 3. Setup cloud player completion listener
    _cloudAudioPlayer.onPlayerComplete.listen((_) {
      print('TTS (Cloud): Finished speaking');
      _isSpeakingCloud = false;
      if (onSpeechFinished != null) onSpeechFinished!();
    });

    // 4. Initialize local TTS engine (always initialized as fallback/backup)
    await _initLocalTts();
  }

  /// Initialize local TTS engine with Turkish/English configuration.
  Future<void> _initLocalTts() async {
    final engines = await _flutterTts.getEngines;
    if (engines is List) {
      final engineList = List<String>.from(engines.map((e) => e.toString()));
      print('TTS Available engines: $engineList');

      for (final engine in engineList) {
        if (engine.toLowerCase().contains('google')) {
          await _flutterTts.setEngine(engine);
          print('TTS Using local engine: $engine');
          break;
        }
      }
    }

    await _flutterTts.setVolume(1.0);
    
    // Check Turkish availability
    final hasTurkish = await _flutterTts.isLanguageAvailable('tr-TR');
    if (hasTurkish == true) {
      await _flutterTts.setLanguage('tr-TR');
      await _flutterTts.setSpeechRate(0.45); // natural Turkish pace
      await _flutterTts.setPitch(0.98);      // warm pitch
      print('TTS: Local language set to tr-TR.');
    } else {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.44);
      await _flutterTts.setPitch(0.98);
      print('TTS: Local language tr-TR not available, fell back to en-US.');
    }

    // Configure voices based on selected language
    final voices = await _flutterTts.getVoices;
    if (voices is List) {
      final voiceList = List<Map<dynamic, dynamic>>.from(voices);
      final isTurkishSelected = (await _flutterTts.getDefaultVoice)?['locale']?.toString().contains('tr') ?? false;

      final targetLocale = isTurkishSelected ? 'tr' : 'en';
      final targetVoices = voiceList.where((v) {
        final locale = v['locale']?.toString().toLowerCase() ?? '';
        return locale.startsWith(targetLocale);
      }).toList();

      if (targetVoices.isNotEmpty) {
        final selectedVoice = targetVoices.firstWhere(
          (v) {
            final name = v['name']?.toString().toLowerCase() ?? '';
            return name.contains('wavenet') || 
                   name.contains('neural') || 
                   name.contains('natural') || 
                   name.contains('network') ||
                   name.contains('google');
          },
          orElse: () => targetVoices.first,
        );

        final voiceName = selectedVoice['name']?.toString();
        if (voiceName != null) {
          await _flutterTts.setVoice({
            'name': voiceName,
            'locale': selectedVoice['locale']?.toString() ?? (isTurkishSelected ? 'tr-TR' : 'en-US'),
          });
          print('TTS Hard-Forced Local Voice: $voiceName');
        }
      }
    }

    _flutterTts.setStartHandler(() {
      if (onSpeechStart != null) onSpeechStart!();
    });
    
    _flutterTts.setCompletionHandler(() {
      print('TTS (Local): Finished speaking');
      if (onSpeechFinished != null) onSpeechFinished!();
    });
    
    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      if (onProgress != null) {
        onProgress!(text, start, end, word);
      }
    });

    _flutterTts.setErrorHandler((msg) {
      print('TTS Local Error: $msg');
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
    await _speakWithEngine(text);
  }

  /// Speak immediately without debounce (for system/interactive instructions).
  Future<void> speakImmediate(String text) async {
    if (_isMuted) return;
    await _speakWithEngine(text);
  }

  /// Stop all active speaking channels.
  Future<void> _stopAll() async {
    await _flutterTts.stop();
    if (_isSpeakingCloud) {
      await _cloudAudioPlayer.stop();
      _isSpeakingCloud = false;
    }
  }

  /// Direct speech execution choosing between Cloud TTS and Local Fallback.
  Future<void> _speakWithEngine(String text) async {
    await _stopAll();

    if (_useCloudTts && _googleApiKey != null && _googleApiKey!.isNotEmpty) {
      final success = await _speakCloud(text);
      if (success) {
        return;
      }
      print('TTS: Cloud engine failed. Falling back to local TTS.');
    }

    await _flutterTts.speak(text);
  }

  /// Call Google Cloud TTS API to synthesize speech.
  Future<bool> _speakCloud(String text) async {
    if (_tempAudioFile == null) return false;
    
    try {
      final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$_googleApiKey');
      
      // Request Neural2 Turkish voice (very natural)
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': 'tr-TR',
            'name': 'tr-TR-Neural2-A' // Premium neural Turkish female voice
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 0.95, // natural Turkish speed
            'pitch': 0.0
          }
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        print('TTS Cloud API Error: ${response.statusCode} - ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body);
      final audioContent = data['audioContent'] as String?;
      if (audioContent == null || audioContent.isEmpty) {
        print('TTS Cloud API returned empty audioContent');
        return false;
      }

      final bytes = base64Decode(audioContent);
      await _tempAudioFile!.writeAsBytes(bytes, flush: true);
      
      _isSpeakingCloud = true;
      if (onSpeechStart != null) onSpeechStart!();
      
      await _cloudAudioPlayer.play(DeviceFileSource(_tempAudioFile!.path));
      return true;
    } catch (e) {
      print('TTS Cloud Synthesis exception: $e');
      return false;
    }
  }

  /// Toggle mute state. Returns the new mute state.
  bool toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _stopAll();
    }
    return _isMuted;
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    await _stopAll();
  }

  /// Dispose TTS resources.
  Future<void> dispose() async {
    await _stopAll();
    await _cloudAudioPlayer.dispose();
  }
}
