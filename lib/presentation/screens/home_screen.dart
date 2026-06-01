import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/camera_service.dart';
import '../../services/tts_service.dart';
import '../../services/haptic_service.dart';
import '../../services/yolo_service.dart';
import '../../services/audio_feedback_service.dart';
import '../../services/location_service.dart';
import '../../services/light_detector_service.dart';
import '../../services/orientation_service.dart';
import '../../services/gemini_service.dart';
import '../../services/lira_detector_service.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../core/enums/detection_mode.dart';
import '../../domain/models/detection_result.dart';
import '../widgets/focus_ring.dart';
import '../widgets/splash_screen.dart';
import '../widgets/camera_preview_box.dart';
import '../widgets/mode_pill.dart';
import '../widgets/result_card.dart';
import '../widgets/bounding_boxes.dart';
import '../widgets/top_status_bar.dart';



// ══════════════════════════════════════════════════════════════
// ██  DESIGN TOKENS
// ══════════════════════════════════════════════════════════════
const _kDeepBlack = Color(0xFF0A0A0A);
const _kAccentYellow = Color(0xFFFFD600);
const _kIdleGuidanceSeconds = 120; // 2 minutes

/// Main screen: edge-to-edge camera with premium, blind-first UI.
///
/// Gestures:
/// - Tap anywhere → capture → analyze → speak result
/// - Swipe Left/Right → switch mode
/// - Double Tap → mute/unmute
/// - Long Press → toggle flash
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Services ──
  final CameraService _cameraService = CameraService();
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();
  final YoloService _yoloService = YoloService();
  final LocationService _locationService = LocationService();
  final LightDetectorService _lightDetectorService = LightDetectorService();
  final OrientationService _orientationService = OrientationService();
  final GeminiService _geminiService = GeminiService();
  final LiraDetectorService _liraDetectorService = LiraDetectorService();
  final Battery _battery = Battery();

  // ── State ──
  DetectionMode _currentMode = DetectionMode.object;
  bool _isLowBattery = false;
  int _batteryLevel = 100;
  DateTime? _lastFrameTime;

  bool _isLoading = true;
  String? _errorMessage;
  bool _isFlashOn = false;
  bool _isAnalyzing = false;
  bool _isFetchingLocation = false;
  String? _lastResult;
  String? _currentSpokenWord;
  bool _isSpeaking = false;

  // ── Live Detection ──
  List<DetectionResult> _detections = [];
  bool _isProcessingFrame = false;

  // ── Idle voice guidance ──
  Timer? _idleTimer;
  bool _hasInteracted = false;

  // ── Animations ──
  late AnimationController _resultFadeController;
  late Animation<double> _resultFadeAnim;
  late AnimationController _modeSwitchController;
  late Animation<double> _modeSwitchAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _resultFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultFadeAnim = CurvedAnimation(
      parent: _resultFadeController,
      curve: Curves.easeOutCubic,
    );

    _modeSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _modeSwitchAnim = CurvedAnimation(
      parent: _modeSwitchController,
      curve: Curves.easeInOut,
    );

    _requestPermissionsAndInit();
  }

  // ══════════════════════════════════════════════════════════════
  // ██  INITIALIZATION
  // ══════════════════════════════════════════════════════════════

  Future<void> _requestPermissionsAndInit() async {
    final statuses = await [
      Permission.camera,
    ].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;

    if (!cameraGranted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Camera permission not granted. Please enable it in settings.';
      });
      await _ttsService.initialize();
      await _ttsService.speakImmediate('Camera permission required');
      return;
    }

    await _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _cameraService.initialize();
      await _ttsService.initialize();
      await _hapticService.initialize();
      await _yoloService.initialize();
      _geminiService.initialize();
      await _liraDetectorService.initialize();
      
      // Initialize offline speech service with download progress tracking (DISABLED per user request)
      // await _voiceCommandService.initialize(
      //   onDownloadProgress: (progress, status) {
      //     if (mounted) {
      //       setState(() {
      //         _isVoiceDownloading = progress < 1.0 && progress >= 0.0;
      //         _voiceDownloadProgress = progress;
      //         _voiceDownloadStatus = status;
      //       });
      //     }
      //   },
      // );

      // Get initial battery status
      try {
        _batteryLevel = await _battery.batteryLevel;
        _isLowBattery = _batteryLevel < 20;
        _battery.onBatteryStateChanged.listen((state) async {
          final level = await _battery.batteryLevel;
          if (mounted) {
            setState(() {
              _batteryLevel = level;
              _isLowBattery = level < 20;
            });
          }
        });
      } catch (e) {
        print('Battery init failed: $e');
      }


      // ── TTS Progress Logic ──
      _ttsService.onProgress = (text, start, end, word) {
        if (mounted) {
          setState(() {
            _currentSpokenWord = word;
            _isSpeaking = true;
          });
        }
      };
      _ttsService.onSpeechStart = () {
        if (mounted) {
          _hapticService.stopProcessingHaptic();
          setState(() {
            _isSpeaking = true;
          });
        }
      };
      _ttsService.onSpeechFinished = () {
        if (mounted) {
          _hapticService.stopProcessingHaptic();
          setState(() {
            _currentSpokenWord = null;
            _isSpeaking = false;
          });
        }
      };

      setState(() => _isLoading = false);

      // ── Startup chime: haptic + system click + welcome voice ──
      await AudioFeedbackService.scanComplete();
      await Future.delayed(const Duration(milliseconds: 200));
      await _ttsService.speakImmediate(
        'EchoVision ready. Tap to scan, swipe to change mode, swipe down for location.',
      );

      // ── Verify Gemini API Connection ──
      final isGeminiOk = await _geminiService.verifyConnection();
      if (!isGeminiOk && mounted) {
        print('Gemini API verification failed.');
        _ttsService.speakImmediate('Warning: Cloud features are currently offline.');
      }

      // ── Check accessibility service for volume button shortcut ──
      await _checkAccessibilityService();

      // ── Start idle guidance timer ──
      _resetIdleTimer();

      // ── Start live detection ──
      _startLiveDetection();

      // ── Start continuous voice listening (always-on) (DISABLED per user request) ──
      // await _startContinuousVoice();

      // ── Orientation guidance DISABLED for now ──
      // _orientationService.onGuidance = (msg) {
      //   if (!_ttsService.isMuted && !_isAnalyzing && mounted) {
      //     _ttsService.speakImmediate(msg);
      //   }
      // };
      // _orientationService.start();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      try {
        await _ttsService.initialize();
        await _ttsService.speakImmediate('Camera failed to start.');
      } catch (_) {}
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  ACCESSIBILITY SERVICE CHECK
  // ══════════════════════════════════════════════════════════════

  Future<void> _checkAccessibilityService() async {
    // App auto-starts on boot, no need for complex accessibility setup
    // Just inform the user on first launch
  }

  // ══════════════════════════════════════════════════════════════
  // ██  IDLE VOICE GUIDANCE
  // ══════════════════════════════════════════════════════════════

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: _kIdleGuidanceSeconds), () {
      if (!_isAnalyzing && !_ttsService.isMuted && mounted) {
        _ttsService.speakImmediate(
          'Tap the screen to scan or swipe left and right to change modes.',
        );
      }
    });
  }

  void _onUserInteraction() {
    _hasInteracted = true;
    _resetIdleTimer();
  }

  // ══════════════════════════════════════════════════════════════
  // ██  LIVE DETECTION
  // ══════════════════════════════════════════════════════════════

  void _startLiveDetection() {
    _cameraService.startImageStream((image) async {
      if (_isProcessingFrame || _isAnalyzing) return;
      
      // Only run live detection for local modes
      if (_currentMode != DetectionMode.object && _currentMode != DetectionMode.hazard) return;

      // Battery-Adaptive Frame Throttling
      final now = DateTime.now();
      final throttleMs = _isLowBattery ? 1000 : 333;
      if (_lastFrameTime != null && 
          now.difference(_lastFrameTime!).inMilliseconds < throttleMs) {
        return;
      }
      _lastFrameTime = now;

      
      _isProcessingFrame = true;
      try {
        final results = await _yoloService.analyzeFrame(image, _cameraService.sensorOrientation);
        if (mounted) {
          setState(() {
            _detections = results;
          });

          // In Hazard mode, provide urgent feedback for close objects
          if (_currentMode == DetectionMode.hazard) {
            _checkHazards(results);
          }
        }
      } catch (e) {
        print('Frame processing error: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  void _checkHazards(List<DetectionResult> results) {
    final closeHazards = results.where((d) => d.isClose).toList();
    if (closeHazards.isNotEmpty) {
      final names = closeHazards.map((h) => "${h.label} ${h.horizontalPosition}").toSet().join(', ');
      _ttsService.speakImmediate('Watch out! There is a $names right in front of you.');
      _hapticService.heavyImpact();
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  CORE: TAP TO SCAN
  // ══════════════════════════════════════════════════════════════

  Future<void> _onTapToScan() async {
    if (_isAnalyzing) return;
    _onUserInteraction();

    // In light mode, tap speaks current light level
    if (_currentMode == DetectionMode.light) {
      AudioFeedbackService.uiClick();
      await _ttsService.speakImmediate(_lightDetectorService.levelDescription);
      return;
    }

    _resultFadeController.reset();
    setState(() {
      _isAnalyzing = true;
      _lastResult = null;
      _currentSpokenWord = null;
    });

    _hapticService.startProcessingHaptic();

    // ── Audio-haptic sync: scan start ──
    await AudioFeedbackService.scanStart();
    _hapticService.tick();

    // Temporarily pause image stream to allow high-quality still capture without camera busy exceptions
    final wasStreaming = _cameraService.controller?.value.isStreamingImages ?? false;
    if (wasStreaming) {
      try {
        await _cameraService.stopImageStream();
      } catch (e) {
        print('Error pausing image stream: $e');
      }
    }

    try {
      final imageFile = await _cameraService.takePicture();
      if (imageFile == null) {
        _hapticService.stopProcessingHaptic();
        await AudioFeedbackService.error();
        await _ttsService.speakImmediate('Failed to take picture');
        if (wasStreaming && mounted) {
          _startLiveDetection();
        }
        setState(() => _isAnalyzing = false);
        return;
      }

      print('Captured: ${imageFile.path}');
      String result;

      if (_currentMode == DetectionMode.object) {
        final results = await _yoloService.analyzeImage(imageFile);
        
        if (results.isNotEmpty) {
          result = results.map((d) => d.description).join(', ');
        } else {
          result = 'No objects detected.';
        }
      } else if (_currentMode == DetectionMode.currency) {
        // 100% LOCAL & OFFLINE currency recognition using TFLite
        result = await _liraDetectorService.detectCurrency(File(imageFile.path));
      } else if (_currentMode == DetectionMode.medication || 
                 _currentMode == DetectionMode.scene ||
                 _currentMode == DetectionMode.hazard) {
        // Cloud processing via Gemini (including detailed Hazard scan)
        result = await _geminiService.describeImage(File(imageFile.path), _currentMode);
      } else {
        result = '';
      }

      _hapticService.stopProcessingHaptic();
      print('Result: $result');

      // ── Audio-haptic sync: scan complete ──
      await AudioFeedbackService.scanComplete();

      setState(() => _lastResult = result);
      _resultFadeController.forward();
      await _ttsService.speakImmediate(result);
    } catch (e) {
      _hapticService.stopProcessingHaptic();
      print('Scan Error: $e');
      await AudioFeedbackService.error();
      await _ttsService.speakImmediate('An error occurred during analysis');
    } finally {
      setState(() => _isAnalyzing = false);
      if (wasStreaming && mounted) {
        _startLiveDetection();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  GESTURES
  // ══════════════════════════════════════════════════════════════

  static const _modeOrder = [
    DetectionMode.hazard,
    DetectionMode.object,
    DetectionMode.currency,
    DetectionMode.medication,
    DetectionMode.scene,
    DetectionMode.light,
  ];

  void _onHorizontalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    _onUserInteraction();
    final currentIdx = _modeOrder.indexOf(_currentMode);
    if (details.primaryVelocity! > 0) {
      // Swipe right → previous mode
      final prevIdx = (currentIdx - 1 + _modeOrder.length) % _modeOrder.length;
      _switchMode(_modeOrder[prevIdx]);
    } else if (details.primaryVelocity! < 0) {
      // Swipe left → next mode
      final nextIdx = (currentIdx + 1) % _modeOrder.length;
      _switchMode(_modeOrder[nextIdx]);
    }
  }

  void _switchMode(DetectionMode mode) {
    if (_currentMode == mode) return;

    // Stop light detector if leaving light mode
    if (_currentMode == DetectionMode.light) {
      _lightDetectorService.stop(_cameraService.controller!);
    }

    // Orientation guidance DISABLED
    // if (mode == DetectionMode.light) {
    //   _orientationService.stop();
    // } else if (_currentMode == DetectionMode.light) {
    //   _orientationService.start();
    // }

    _modeSwitchController.forward(from: 0);
    setState(() {
      _currentMode = mode;
      _lastResult = null;
    });
    _resultFadeController.reset();
    _geminiService.clearSession();


    // ── Audio-haptic sync: mode switch click ──
    AudioFeedbackService.uiClick();
    _hapticService.tick();

    String name;
    switch (mode) {
      case DetectionMode.hazard:
        name = 'Hazard Detection';
        break;
      case DetectionMode.object:
        name = 'Object Scanner';
        break;
      case DetectionMode.currency:
        name = 'Currency Reader';
        break;
      case DetectionMode.medication:
        name = 'Medication Assistant';
        break;
      case DetectionMode.scene:
        name = 'Scene Description';
        break;
      case DetectionMode.light:
        name = 'Light Detector';
        break;
    }
    _ttsService.speakImmediate(name);

    // Start light detector if entering light mode
    if (mode == DetectionMode.light && _cameraService.controller != null) {
      _lightDetectorService.start(_cameraService.controller!);
    }
  }

  void _onDoubleTap() {
    _onUserInteraction();
    final muted = _ttsService.toggleMute();
    AudioFeedbackService.uiClick();
    _hapticService.tick();
    if (!muted) _ttsService.speakImmediate('Voice on');
    setState(() {});
  }



  /// Long press: toggle the camera flash/torch.
  void _onLongPress() async {
    _onUserInteraction();
    
    if (_cameraService.isInitialized) {
      _hapticService.tick();
      try {
        await _cameraService.toggleFlash();
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
        await _ttsService.speakImmediate(_isFlashOn ? 'Flash on' : 'Flash off');
      } catch (e) {
        print('Error toggling flash: $e');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  GPS LOCATION (Swipe Down)
  // ══════════════════════════════════════════════════════════════

  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    // Swipe down → get location
    if (details.primaryVelocity! > 300) {
      _onUserInteraction();
      _fetchLocation();
    }
    // Swipe up → speak camera orientation + compass
    else if (details.primaryVelocity! < -300) {
      _onUserInteraction();
      AudioFeedbackService.uiClick();
      _ttsService.speakImmediate(_orientationService.cameraDescription);
    }
  }

  Future<void> _fetchLocation() async {
    if (_isFetchingLocation) return;
    setState(() {
      _isFetchingLocation = true;
      _lastResult = null;
    });
    _resultFadeController.reset();

    AudioFeedbackService.scanStart();
    _hapticService.tick();
    await _ttsService.speakImmediate('Locating...');

    try {
      final description =
          await _locationService.getCurrentLocationDescription();
      await AudioFeedbackService.scanComplete();
      setState(() => _lastResult = description);
      _resultFadeController.forward();
      await _ttsService.speakImmediate(description);
    } catch (e) {
      await AudioFeedbackService.error();
      await _ttsService.speakImmediate('Could not determine location');
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  LIFECYCLE
  // ══════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraService.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _resetIdleTimer();
    } else {
      _idleTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _resultFadeController.dispose();
    _modeSwitchController.dispose();
    _lightDetectorService.dispose();
    _orientationService.dispose();
    _cameraService.dispose();
    _ttsService.dispose();
    _yoloService.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // ██  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDeepBlack,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTapToScan,
        onHorizontalDragEnd: _onHorizontalSwipe,
        onVerticalDragEnd: _onVerticalSwipe,
        onDoubleTap: _onDoubleTap,
        onLongPress: _onLongPress,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SplashScreen();
    }
    if (_errorMessage != null) return _buildError();
    if (!_cameraService.isInitialized || _cameraService.controller == null) {
      return _buildNoCameraState();
    }
    return _buildMainUI();
  }

  // ── Error ──
  Widget _buildError() {
    return Container(
      color: _kDeepBlack,
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade400,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  // ── No Camera ──
  Widget _buildNoCameraState() {
    return const Center(
      child: Text(
        'Camera unavailable',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ██  MAIN UI — THE CANVAS
  // ══════════════════════════════════════════════════════════════

  Widget _buildMainUI() {
    final padding = MediaQuery.of(context).padding;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. FULL-BLEED CAMERA (Adaptive Aspect Ratio) ──
        CameraPreviewBox(controller: _cameraService.controller!),

        // ── 1.5 BOUNDING BOX OVERLAY ──
        BoundingBoxes(detections: _detections, currentMode: _currentMode),

        // ── 2. TOP GRADIENT VEIL ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: padding.top + 90,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xDD0A0A0A),
                  Color(0x550A0A0A),
                  Colors.transparent,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // ── 3. BOTTOM GRADIENT VEIL ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 260,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xF00A0A0A),
                  Color(0xAA0A0A0A),
                  Color(0x440A0A0A),
                  Colors.transparent,
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // ── 4. CENTER FOCUS RING ──
        Center(
          child: FocusRing(isScanning: _isAnalyzing),
        ),

        // ── 5. "TAP TO SCAN" HINT — shows when idle ──
        if (!_isAnalyzing && _lastResult == null)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.38,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _hasInteracted ? 0.0 : 0.7,
                duration: const Duration(milliseconds: 800),
                child: Text(
                  'Tap to scan',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),

        // ── 6. "ANALYZING" / "LOCATING" TEXT ──
        if (_isAnalyzing || _isFetchingLocation)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.38,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _isFetchingLocation
                    ? 'Locating...'
                    : 'Analyzing...',
                style: TextStyle(
                  color: _kAccentYellow.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),

        // ── 7. TOP BAR: STATUS ──
        Positioned(
          top: padding.top + 14,
          left: 24,
          right: 24,
          child: TopStatusBar(
            isFlashOn: _isFlashOn,
            isMuted: _ttsService.isMuted,
          ),
        ),

        // ── 8. BOTTOM: RESULT + MODE PILL ──
        Positioned(
          bottom: padding.bottom + 20,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Result card
              ResultCard(
                isSpeaking: _isSpeaking,
                currentSpokenWord: _currentSpokenWord,
                resultFadeAnim: _resultFadeAnim,
              ),
              if (_lastResult != null && !_isAnalyzing && _isSpeaking && _currentSpokenWord != null)
                const SizedBox(height: 16),

              // Mode pill
              ModePill(
                currentMode: _currentMode,
                animation: _modeSwitchAnim,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

