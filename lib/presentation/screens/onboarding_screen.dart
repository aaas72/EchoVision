import 'package:flutter/material.dart';
import '../../services/tts_service.dart';
import '../../services/audio_feedback_service.dart';
import '../../services/haptic_service.dart';

enum TutorialStep {
  welcome,
  swipe,
  tap,
  doubleTap,
  level2Welcome,
  listenStart,
  listenSuccess,
  listenError,
  finished,
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();
  
  TutorialStep _currentStep = TutorialStep.welcome;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _initServicesAndStart();
  }

  Future<void> _initServicesAndStart() async {
    await _ttsService.initialize();
    await _hapticService.initialize();
    _playCurrentInstruction();
  }

  Future<void> _playCurrentInstruction() async {
    _isTransitioning = true;
    switch (_currentStep) {
      // ── Level 1: Gestures ──
      case TutorialStep.welcome:
        await _ttsService.speakImmediate(
          'Welcome to EchoVision. Let\'s start Level 1: Gestures. First, swipe your finger left or right on the screen to change modes. Please swipe now.'
        );
        break;
      case TutorialStep.swipe:
        break;
      case TutorialStep.tap:
        await _ttsService.speakImmediate(
          'Great job! Now, tap the screen once anywhere to scan the environment. Please tap now.'
        );
        break;
      case TutorialStep.doubleTap:
        await _ttsService.speakImmediate(
          'Excellent! Finally, double tap the screen quickly to mute or unmute voice guidance. Try double tapping now.'
        );
        break;

      // ── Level 2: Audio-Haptic Feedback ──
      case TutorialStep.level2Welcome:
        await _ttsService.speakImmediate(
          'Excellent! You have completed Level 1. Now for Level 2: The Sound Mechanism. Tap the screen once to hear the START sound.'
        );
        break;
      case TutorialStep.listenStart:
        await AudioFeedbackService.requestInitiated();
        await Future.delayed(const Duration(milliseconds: 1000));
        await _ttsService.speakImmediate(
          'This sound and vibration means I am thinking. Now tap again to hear the SUCCESS sound.'
        );
        break;
      case TutorialStep.listenSuccess:
        await AudioFeedbackService.responseReceived();
        await Future.delayed(const Duration(milliseconds: 1000));
        await _ttsService.speakImmediate(
          'This means I found a result. Finally, tap again to hear the ERROR sound.'
        );
        break;
      case TutorialStep.listenError:
        await AudioFeedbackService.errorState();
        await Future.delayed(const Duration(milliseconds: 1000));
        await _ttsService.speakImmediate(
          'This heavy vibration means there was a network problem. You have completed the training! Welcome to EchoVision.'
        );
        await Future.delayed(const Duration(seconds: 6));
        _completeOnboarding();
        break;
      case TutorialStep.finished:
        break;
    }
    _isTransitioning = false;
  }

  Future<void> _completeOnboarding() async {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleWrongAction() {
    if (_isTransitioning) return;
    _hapticService.heavyImpact();
    AudioFeedbackService.error();
    
    switch (_currentStep) {
      case TutorialStep.welcome:
      case TutorialStep.swipe:
        _ttsService.speakImmediate('Please swipe left or right.');
        break;
      case TutorialStep.tap:
        _ttsService.speakImmediate('Please tap once.');
        break;
      case TutorialStep.doubleTap:
        _ttsService.speakImmediate('Please double tap quickly.');
        break;
      case TutorialStep.level2Welcome:
      case TutorialStep.listenStart:
      case TutorialStep.listenSuccess:
      case TutorialStep.listenError:
        _ttsService.speakImmediate('Please tap once.');
        break;
      default:
        break;
    }
  }

  void _advanceTo(TutorialStep step) async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    
    // Play transition sounds only for Level 1
    if (step.index <= TutorialStep.level2Welcome.index) {
      AudioFeedbackService.scanComplete();
      _hapticService.tick();
    }
    
    setState(() {
      _currentStep = step;
    });
    
    await _playCurrentInstruction();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // kDeepBlack
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentStep == TutorialStep.tap) {
            _advanceTo(TutorialStep.doubleTap);
          } else if (_currentStep == TutorialStep.level2Welcome) {
            _advanceTo(TutorialStep.listenStart);
          } else if (_currentStep == TutorialStep.listenStart) {
            _advanceTo(TutorialStep.listenSuccess);
          } else if (_currentStep == TutorialStep.listenSuccess) {
            _advanceTo(TutorialStep.listenError);
          } else {
            _handleWrongAction();
          }
        },
        onDoubleTap: () {
          if (_currentStep == TutorialStep.doubleTap) {
            _advanceTo(TutorialStep.level2Welcome);
          } else {
            _handleWrongAction();
          }
        },
        onHorizontalDragEnd: (details) {
          if (_currentStep == TutorialStep.welcome || _currentStep == TutorialStep.swipe) {
            _advanceTo(TutorialStep.tap);
          } else {
            _handleWrongAction();
          }
        },
        onVerticalDragEnd: (details) {
          _handleWrongAction();
        },
        child: const Center(
          child: Icon(
            Icons.school_rounded,
            size: 100,
            color: Color(0xFF333333),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}
