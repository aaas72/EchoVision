import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/camera_service.dart';
import '../../services/tts_service.dart';
import '../../services/haptic_service.dart';
import '../../services/object_detection_service.dart';
import '../../services/mlkit_detection_service.dart';
import '../../services/currency_detection_service.dart';
import '../../services/gemini_vision_service.dart';
import '../../services/audio_feedback_service.dart';
import '../../services/location_service.dart';
import '../../services/light_detector_service.dart';
import '../../services/orientation_service.dart';
import '../../core/enums/detection_mode.dart';
import '../widgets/focus_ring.dart';

// ══════════════════════════════════════════════════════════════
// ██  DESIGN TOKENS
// ══════════════════════════════════════════════════════════════
const _kDeepBlack = Color(0xFF0A0A0A);
const _kAccentYellow = Color(0xFFFFD600);
const _kAccentCyan = Color(0xFF00E5FF);
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
  final MLKitDetectionService _mlkitDetectionService = MLKitDetectionService();
  final ObjectDetectionService _objectDetectionService =
      ObjectDetectionService();
  final CurrencyDetectionService _currencyDetectionService =
      CurrencyDetectionService();
  final GeminiVisionService _geminiVisionService = GeminiVisionService();
  final LocationService _locationService = LocationService();
  final LightDetectorService _lightDetectorService = LightDetectorService();
  final OrientationService _orientationService = OrientationService();

  // ── State ──
  DetectionMode _currentMode = DetectionMode.object;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFlashOn = false;
  bool _isAnalyzing = false;
  bool _isFetchingLocation = false;
  String? _lastResult;

  // ── Idle voice guidance ──
  Timer? _idleTimer;
  bool _hasInteracted = false;

  // ── Animations ──
  late AnimationController _resultFadeController;
  late Animation<double> _resultFadeAnim;
  late AnimationController _modeSwitchController;
  late Animation<double> _modeSwitchAnim;
  late AnimationController _splashFadeController;
  late Animation<double> _splashFadeAnim;

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

    _splashFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _splashFadeAnim = CurvedAnimation(
      parent: _splashFadeController,
      curve: Curves.easeIn,
    );

    _requestPermissionsAndInit();
  }

  // ══════════════════════════════════════════════════════════════
  // ██  INITIALIZATION
  // ══════════════════════════════════════════════════════════════

  Future<void> _requestPermissionsAndInit() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kamera izni verilmedi. Lütfen ayarlardan izin verin.';
      });
      await _ttsService.initialize();
      await _ttsService.speakImmediate('Kamera izni gerekli');
      return;
    }
    await _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _cameraService.initialize();
      await _ttsService.initialize();
      await _hapticService.initialize();
      await _mlkitDetectionService.initialize();
      await _objectDetectionService.initialize();
      await _currencyDetectionService.initialize();
      await _geminiVisionService.initialize();

      setState(() => _isLoading = false);

      // ── Startup chime: haptic + system click + welcome voice ──
      await AudioFeedbackService.scanComplete();
      await Future.delayed(const Duration(milliseconds: 200));
      await _ttsService.speakImmediate(
        'EchoVision hazır. Taramak için ekrana dokunun, mod değiştirmek için kaydırın, konumunuzu öğrenmek için aşağı kaydırın.',
      );

      // ── Check accessibility service for volume button shortcut ──
      await _checkAccessibilityService();

      // ── Start idle guidance timer ──
      _resetIdleTimer();

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
        await _ttsService.speakImmediate('Kamera başlatılamadı.');
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
          'Taramak için ekrana dokunun veya mod değiştirmek için sağa sola kaydırın.',
        );
      }
    });
  }

  void _onUserInteraction() {
    _hasInteracted = true;
    _resetIdleTimer();
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
    });

    // ── Audio-haptic sync: scan start ──
    await AudioFeedbackService.scanStart();
    _hapticService.tick();

    try {
      final imageFile = await _cameraService.takePicture();
      if (imageFile == null) {
        await AudioFeedbackService.error();
        await _ttsService.speakImmediate('Fotoğraf çekilemedi');
        setState(() => _isAnalyzing = false);
        return;
      }

      print('Captured: ${imageFile.path}');
      String result;

      if (_currentMode == DetectionMode.object) {
        // Combine ML Kit + TFLite for maximum detection coverage
        final allDetections = <String>{};

        // 1. ML Kit detection (hundreds of objects)
        final mlkitResults =
            await _mlkitDetectionService.analyzeImage(imageFile);
        allDetections.addAll(mlkitResults);

        // 2. TFLite detection (COCO 80 classes)
        final tfliteResults =
            await _objectDetectionService.analyzeImage(imageFile);
        allDetections.addAll(tfliteResults);

        if (allDetections.isNotEmpty) {
          result = allDetections.take(10).join(', ');
        } else {
          // 3. Fallback to Gemini Vision AI (requires internet)
          print('Local detection empty, trying Gemini Vision...');
          result = await _geminiVisionService.analyzeImage(imageFile);
        }
      } else {
        final currency =
            await _currencyDetectionService.analyzeImage(imageFile);
        result = currency ?? 'Para birimi tanınamadı. Tekrar deneyin.';
      }

      print('Result: $result');

      // ── Audio-haptic sync: scan complete ──
      await AudioFeedbackService.scanComplete();

      setState(() => _lastResult = result);
      _resultFadeController.forward();
      await _ttsService.speakImmediate(result);
    } catch (e) {
      print('Analysis error: $e');
      await AudioFeedbackService.error();
      await _ttsService.speakImmediate('Analiz sırasında hata oluştu');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  GESTURES
  // ══════════════════════════════════════════════════════════════

  static const _modeOrder = [
    DetectionMode.object,
    DetectionMode.currency,
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

    // ── Audio-haptic sync: mode switch click ──
    AudioFeedbackService.uiClick();
    _hapticService.tick();

    String name;
    switch (mode) {
      case DetectionMode.object:
        name = 'Nesne Tanıma Modu';
        break;
      case DetectionMode.currency:
        name = 'Para Tanıma Modu';
        break;
      case DetectionMode.light:
        name = 'Işık Algılayıcı';
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
    if (!muted) _ttsService.speakImmediate('Ses açıldı');
    setState(() {});
  }

  void _onLongPress() async {
    _onUserInteraction();
    try {
      await _cameraService.toggleFlash();
      _isFlashOn = !_isFlashOn;
      AudioFeedbackService.uiClick();
      _hapticService.tick();
      await _ttsService.speakImmediate(
        _isFlashOn ? 'Flaş açıldı' : 'Flaş kapatıldı',
      );
      setState(() {});
    } catch (_) {}
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
    await _ttsService.speakImmediate('Konumunuz belirleniyor...');

    try {
      final description =
          await _locationService.getCurrentLocationDescription();
      await AudioFeedbackService.scanComplete();
      setState(() => _lastResult = description);
      _resultFadeController.forward();
      await _ttsService.speakImmediate(description);
    } catch (e) {
      await AudioFeedbackService.error();
      await _ttsService.speakImmediate('Konum belirlenemedi');
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
    _splashFadeController.dispose();
    _lightDetectorService.dispose();
    _orientationService.dispose();
    _cameraService.dispose();
    _ttsService.dispose();
    _mlkitDetectionService.dispose();
    _objectDetectionService.dispose();
    _currencyDetectionService.dispose();
    _geminiVisionService.dispose();
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
    if (_isLoading) return _buildSplash();
    if (_errorMessage != null) return _buildError();
    if (!_cameraService.isInitialized || _cameraService.controller == null) {
      return _buildNoCameraState();
    }
    return _buildMainUI();
  }

  // ══════════════════════════════════════════════════════════════
  // ██  SPLASH / LOADING
  // ══════════════════════════════════════════════════════════════

  Widget _buildSplash() {
    return Container(
      color: _kDeepBlack,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing eye icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kAccentYellow.withValues(alpha: 0.15),
                    _kAccentYellow.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
                border: Border.all(
                  color: _kAccentYellow.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kAccentYellow.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.visibility_rounded,
                color: _kAccentYellow,
                size: 42,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'ECHOVISION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Akıllı Asistanınız',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.white10,
                  color: _kAccentYellow,
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        'Kamera kullanılamıyor',
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
        // ── 1. FULL-BLEED CAMERA ──
        CameraPreview(_cameraService.controller!),

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
                  'Taramak için dokunun',
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
                    ? 'Konum belirleniyor...'
                    : 'Analiz ediliyor...',
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
          child: _buildTopBar(),
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
              if (_lastResult != null && !_isAnalyzing) _buildResultCard(),
              if (_lastResult != null && !_isAnalyzing)
                const SizedBox(height: 16),

              // Mode pill
              _buildModePill(),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ██  TOP BAR
  // ══════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand wordmark
        const Text(
          'ECHOVISION',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        const Spacer(),
        // Flash pill
        if (_isFlashOn)
          _statusPill(
            icon: Icons.flashlight_on_rounded,
            label: 'Flaş',
            color: _kAccentYellow,
          ),
        if (_isFlashOn) const SizedBox(width: 8),
        // Mute pill
        if (_ttsService.isMuted)
          _statusPill(
            icon: Icons.volume_off_rounded,
            label: 'Sessiz',
            color: Colors.red.shade400,
          ),
      ],
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kDeepBlack.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ██  MODE PILL — Massive AAA-contrast typography
  // ══════════════════════════════════════════════════════════════

  Widget _buildModePill() {
    String label;
    IconData icon;
    switch (_currentMode) {
      case DetectionMode.object:
        label = 'Nesne Tarayıcı';
        icon = Icons.center_focus_strong_rounded;
        break;
      case DetectionMode.currency:
        label = 'Para Tarayıcı';
        icon = Icons.payments_rounded;
        break;
      case DetectionMode.light:
        label = 'Işık Algılayıcı';
        icon = Icons.lightbulb_rounded;
        break;
    }

    return AnimatedBuilder(
      animation: _modeSwitchAnim,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _kDeepBlack.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: _kAccentYellow.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left swipe hint arrow
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 24,
              ),
              const SizedBox(width: 10),
              // Mode icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccentYellow.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: _kAccentYellow, size: 20),
              ),
              const SizedBox(width: 12),
              // Mode label — oversized for AAA contrast
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kAccentYellow,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              // Right swipe hint arrow
              Icon(
                Icons.chevron_left_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 24,
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ██  RESULT CARD — Oversized, readable, cyan-accented
  // ══════════════════════════════════════════════════════════════

  Widget _buildResultCard() {
    return FadeTransition(
      opacity: _resultFadeAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: BoxDecoration(
          color: _kDeepBlack.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _kAccentCyan.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _kAccentCyan.withValues(alpha: 0.06),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: _kAccentCyan.withValues(alpha: 0.7),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'SONUÇ',
                  style: TextStyle(
                    color: _kAccentCyan.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Result text — oversized, high-weight
            Text(
              _lastResult!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}
