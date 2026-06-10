import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';

/// Service responsible for text-to-speech output using the local TTS engine.
/// Prevents spamming the user by only repeating the same label
/// after [AppConstants.ttsDebounceSeconds] seconds.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final Map<String, DateTime> _lastSpoken = {};
  
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  /// Callbacks for progress tracking
  void Function(String text, int start, int end, String word)? onProgress;
  void Function()? onSpeechStart;
  void Function()? onSpeechFinished;

  /// Initialize TTS engine.
  Future<void> initialize() async {
    await _initLocalTts();
    print('TTS: Initialized with local TTS engine only.');
  }

  /// Initialize local TTS engine with strict Turkish voice and articulation.
  Future<void> _initLocalTts() async {
    // ── 1. Select the best TTS engine (prefer Google) ──
    final engines = await _flutterTts.getEngines;
    if (engines is List) {
      final engineList = List<String>.from(engines.map((e) => e.toString()));
      print('TTS Available engines: $engineList');

      // Priority order: Google > Samsung > any other
      String? bestEngine;
      for (final engine in engineList) {
        final lower = engine.toLowerCase();
        if (lower.contains('google')) {
          bestEngine = engine;
          break; // Google is the best for Turkish
        } else if (lower.contains('samsung') && bestEngine == null) {
          bestEngine = engine;
        }
      }
      if (bestEngine != null) {
        await _flutterTts.setEngine(bestEngine);
        print('TTS Selected engine: $bestEngine');
      }
    }

    // ── 2. Force Turkish language (tr-TR) ──
    // Set language BEFORE checking availability to prime the engine
    await _flutterTts.setLanguage('tr-TR');

    final hasTurkish = await _flutterTts.isLanguageAvailable('tr-TR');
    if (hasTurkish != true) {
      // Try alternative Turkish locale codes
      final alternatives = ['tr', 'tr_TR', 'tur'];
      bool found = false;
      for (final alt in alternatives) {
        final available = await _flutterTts.isLanguageAvailable(alt);
        if (available == true) {
          await _flutterTts.setLanguage(alt);
          found = true;
          print('TTS: Turkish found with locale code: $alt');
          break;
        }
      }
      if (!found) {
        print('TTS WARNING: Turkish not available on this device! Falling back to en-US.');
        await _flutterTts.setLanguage('en-US');
      }
    } else {
      print('TTS: Turkish (tr-TR) language confirmed.');
    }

    // ── 3. Fine-tune speech parameters for natural Turkish articulation ──
    // Turkish has specific phonetic characteristics:
    //   - Clear consonants: ç[tʃ], ş[ʃ], ğ[ɰ] need slower, deliberate articulation
    //   - Vowel harmony: ö[ø], ü[y], ı[ɯ] need proper mouth shaping
    //   - Agglutinative suffixes need even pacing to stay intelligible
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.42);  // Slightly slower for clear ç/ş/ğ articulation
    await _flutterTts.setPitch(1.0);        // Neutral pitch — natural Turkish intonation

    // ── 4. Select the highest-quality Turkish voice ──
    final voices = await _flutterTts.getVoices;
    if (voices is List) {
      final voiceList = List<Map<dynamic, dynamic>>.from(voices);

      // Filter to only Turkish voices
      final turkishVoices = voiceList.where((v) {
        final locale = v['locale']?.toString().toLowerCase() ?? '';
        return locale.startsWith('tr');
      }).toList();

      print('TTS: Found ${turkishVoices.length} Turkish voice(s)');
      for (final v in turkishVoices) {
        print('  → ${v['name']} (${v['locale']})');
      }

      if (turkishVoices.isNotEmpty) {
        // Quality tiers — pick the best available voice
        // Tier 1: Neural / Natural voices (highest quality, best articulation)
        // Tier 2: WaveNet / Network voices (high quality)
        // Tier 3: Standard voices (acceptable)
        final qualityKeywords = [
          ['neural', 'natural'],           // Tier 1
          ['wavenet', 'network', 'studio'], // Tier 2
          ['premium', 'enhanced'],          // Tier 2.5
        ];

        Map<dynamic, dynamic>? bestVoice;

        for (final tier in qualityKeywords) {
          if (bestVoice != null) break;
          for (final voice in turkishVoices) {
            final name = voice['name']?.toString().toLowerCase() ?? '';
            if (tier.any((keyword) => name.contains(keyword))) {
              bestVoice = voice;
              break;
            }
          }
        }

        // Fallback: prefer female voices (typically clearer Turkish diction)
        bestVoice ??= turkishVoices.firstWhere(
          (v) {
            final name = v['name']?.toString().toLowerCase() ?? '';
            return name.contains('female') || name.contains('kadın') || name.contains('woman');
          },
          orElse: () => turkishVoices.first,
        );

        final voiceName = bestVoice['name']?.toString();
        final voiceLocale = bestVoice['locale']?.toString() ?? 'tr-TR';
        if (voiceName != null) {
          await _flutterTts.setVoice({
            'name': voiceName,
            'locale': voiceLocale,
          });
          print('TTS: ✓ Selected Turkish voice: $voiceName ($voiceLocale)');
        }
      } else {
        print('TTS: No dedicated Turkish voices found, relying on language setting.');
      }
    }

    // ── 5. Register event handlers ──
    _flutterTts.setStartHandler(() {
      if (onSpeechStart != null) onSpeechStart!();
    });
    
    _flutterTts.setCompletionHandler(() {
      print('TTS (Local): Finished speaking');
      _progressTimer?.cancel();
      if (onSpeechFinished != null) onSpeechFinished!();
    });
    
    _flutterTts.setErrorHandler((msg) {
      print('TTS Local Error: $msg');
      _progressTimer?.cancel();
    });
  }

  Timer? _progressTimer;

  void _startTimedProgress(String text) {
    _progressTimer?.cancel();
    
    // Clean text from punctuation for cleaner word-by-word emission
    final cleanText = text.replaceAll(RegExp(r'[^\w\s\d\xAA-\xFF]'), '');
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return;

    int wordIndex = 0;
    
    void scheduleNextWord() {
      if (wordIndex >= words.length) {
        _progressTimer?.cancel();
        return;
      }
      
      final word = words[wordIndex];
      final start = text.indexOf(word);
      final end = start + word.length;
      
      // Emit the progress event
      if (onProgress != null) {
        onProgress!(text, start, end, word);
      }
      
      // Calculate speaking duration for this word
      // 180ms base + 72ms per character is perfectly calibrated for the 0.42/0.45 speed rate
      final durationMs = 180 + (word.length * 72);
      
      wordIndex++;
      _progressTimer = Timer(Duration(milliseconds: durationMs), scheduleNextWord);
    }
    
    scheduleNextWord();
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

  /// Direct speech execution using local TTS engine.
  Future<void> _speakWithEngine(String text) async {
    _progressTimer?.cancel();
    await _flutterTts.stop();
    await _flutterTts.speak(text);
    
    // Start synchronized word progress matching the speaking speed
    _startTimedProgress(text);
  }

  /// Toggle mute state. Returns the new mute state.
  bool toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _progressTimer?.cancel();
      _flutterTts.stop();
    }
    return _isMuted;
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    _progressTimer?.cancel();
    await _flutterTts.stop();
  }

  /// Dispose TTS resources.
  Future<void> dispose() async {
    _progressTimer?.cancel();
    await _flutterTts.stop();
  }
}