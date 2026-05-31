import 'package:speech_to_text/speech_to_text.dart';

enum AppVoiceCommand {
  scan,
  modeObject,
  modeHazard,
  modeCurrency,
  modeMedication,
  modeScene,
  modeLight,
  whereAmI,
  direction,
  mute,
  unmute,
  help,
  unknown
}

/// Service to handle Speech-To-Text and convert voice to app actions.
class VoiceCommandService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  /// Initialize Speech recognition engine.
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => print('Speech Error: $val'),
        onStatus: (val) {
          print('Speech Status: $val');
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          }
        },
      );
    } catch (e) {
      print('Speech Init Exception: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  /// Start listening and invoke callback when command is matched.
  Future<void> startListening({
    required Function(AppVoiceCommand command, String rawText) onCommandMatched,
    required Function() onStopListening,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (_isListening) return;

    _isListening = true;
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _isListening = false;
            final command = _parseCommand(result.recognizedWords);
            onCommandMatched(command, result.recognizedWords);
            onStopListening();
          }
        },
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
      );
    } catch (e) {
      print('Speech listen failed: $e');
      _isListening = false;
      onStopListening();
    }
  }

  /// Cancel listening.
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    _isListening = false;
  }

  /// Matches spoken words to specific app commands.
  /// Supports English and Arabic inputs.
  AppVoiceCommand _parseCommand(String text) {
    final cleanText = text.toLowerCase().trim();
    print('Speech Recognized: $cleanText');

    // ── 1. HELP ──
    if (cleanText.contains('help') || cleanText.contains('مساعدة') || cleanText.contains('تعليمات')) {
      return AppVoiceCommand.help;
    }

    // ── 2. CAPTURE / SCAN ──
    if (cleanText.contains('scan') || cleanText.contains('capture') || cleanText.contains('فحص') || cleanText.contains('التقط') || cleanText.contains('صورة')) {
      return AppVoiceCommand.scan;
    }

    // ── 3. WHERE AM I (LOCATION) ──
    if (cleanText.contains('where') || cleanText.contains('location') || cleanText.contains('موقع') || cleanText.contains('أين أنا')) {
      return AppVoiceCommand.whereAmI;
    }

    // ── 4. DIRECTION (COMPASS) ──
    if (cleanText.contains('direction') || cleanText.contains('compass') || cleanText.contains('اتجاه') || cleanText.contains('بوصلة')) {
      return AppVoiceCommand.direction;
    }

    // ── 5. MUTE / UNMUTE ──
    if (cleanText.contains('unmute') || cleanText.contains('صوت تشغيل') || cleanText.contains('تفعيل الصوت')) {
      return AppVoiceCommand.unmute;
    }
    if (cleanText.contains('mute') || cleanText.contains('صامت') || cleanText.contains('كتم')) {
      return AppVoiceCommand.mute;
    }

    // ── 6. DETECTOR MODES ──
    if (cleanText.contains('hazard') || cleanText.contains('danger') || cleanText.contains('خطر') || cleanText.contains('مخاطر')) {
      return AppVoiceCommand.modeHazard;
    }
    if (cleanText.contains('currency') || cleanText.contains('money') || cleanText.contains('نقود') || cleanText.contains('عملة') || cleanText.contains('فلوس')) {
      return AppVoiceCommand.modeCurrency;
    }
    if (cleanText.contains('medicine') || cleanText.contains('medication') || cleanText.contains('drug') || cleanText.contains('دواء') || cleanText.contains('صيدلية')) {
      return AppVoiceCommand.modeMedication;
    }
    if (cleanText.contains('scene') || cleanText.contains('room') || cleanText.contains('غرفة') || cleanText.contains('مشهد') || cleanText.contains('وصف')) {
      return AppVoiceCommand.modeScene;
    }
    if (cleanText.contains('light') || cleanText.contains('brightness') || cleanText.contains('ضوء') || cleanText.contains('إضاءة')) {
      return AppVoiceCommand.modeLight;
    }
    if (cleanText.contains('object') || cleanText.contains('thing') || cleanText.contains('كائنات') || cleanText.contains('أشياء')) {
      return AppVoiceCommand.modeObject;
    }

    return AppVoiceCommand.unknown;
  }
}
