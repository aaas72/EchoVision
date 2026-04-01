import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Rotation-Vector-style orientation service fusing:
///   - Accelerometer (gravity → pitch & roll)
///   - Magnetometer  (compass → heading / azimuth)
///   - Gyroscope     (smoothing via complementary filter)
///
/// All guidance is from the **camera's point of view** (back camera,
/// phone in portrait). The camera looks along the -Z axis of the device.
///
/// Camera-perspective angles (degrees):
///   cameraPitch:  0 = forward,  +90 = ceiling,  -90 = floor
///   cameraRoll:   0 = level,    + = tilted right, - = tilted left
///   heading:      0 = North,    90 = East, etc.
class OrientationService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  bool _isActive = false;

  // Callback to speak guidance
  void Function(String message)? onGuidance;

  // ── Latest raw readings ──
  double _ax = 0, _ay = 0, _az = 0; // accelerometer (m/s²)
  double _mx = 0, _my = 0, _mz = 0; // magnetometer  (µT)
  double _gx = 0, _gy = 0, _gz = 0; // gyroscope     (rad/s)

  // ── Fused orientation (degrees) ──
  double _cameraPitch = 0; // camera vertical aim
  double _cameraRoll = 0;  // camera horizon tilt
  double _heading = 0;     // compass heading

  // ── Complementary filter ──
  static const double _alpha = 0.92; // gyro trust (0.0–1.0)
  DateTime? _lastGyroTime;

  // ── Guidance cooldown ──
  DateTime _lastGuidanceTime = DateTime(2000);
  static const _kCooldownSeconds = 4;
  Timer? _guidanceTimer;

  // ── Thresholds (degrees from ideal) ──
  static const _kPitchWarn = 25.0;  // > 25° up or down
  static const _kRollWarn = 20.0;   // > 20° tilted sideways

  // ── Public getters ──
  double get cameraPitch => _cameraPitch;
  double get cameraRoll => _cameraRoll;
  double get heading => _heading;
  bool get isActive => _isActive;

  /// Turkish description of where the camera is pointing right now.
  String get cameraDescription {
    final parts = <String>[];

    // Pitch
    if (_cameraPitch < -55) {
      parts.add('Kamera yere bakıyor');
    } else if (_cameraPitch < -_kPitchWarn) {
      parts.add('Kamera aşağı eğik');
    } else if (_cameraPitch > 55) {
      parts.add('Kamera tavana bakıyor');
    } else if (_cameraPitch > _kPitchWarn) {
      parts.add('Kamera yukarı eğik');
    } else {
      parts.add('Kamera ileriye bakıyor');
    }

    // Roll
    if (_cameraRoll.abs() > _kRollWarn) {
      parts.add(_cameraRoll > 0 ? 'sağa eğik' : 'sola eğik');
    } else {
      parts.add('düz');
    }

    // Compass
    parts.add('Yön: ${_headingToTurkish(_heading)}');

    return '${parts.join(', ')}.';
  }

  /// Start all three sensor streams + periodic guidance check.
  void start() {
    if (_isActive) return;
    _isActive = true;
    _lastGyroTime = null;

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((e) {
      _ax = e.x;
      _ay = e.y;
      _az = e.z;
      _updateOrientationFromAccel();
    });

    _magSub = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((e) {
      _mx = e.x;
      _my = e.y;
      _mz = e.z;
      _updateHeading();
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((e) {
      _gx = e.x;
      _gy = e.y;
      _gz = e.z;
      _fuseGyro();
    });

    // Check orientation every 500ms and emit guidance if needed
    _guidanceTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _emitGuidanceIfNeeded(),
    );
  }

  /// Stop all streams.
  void stop() {
    _isActive = false;
    _accelSub?.cancel();
    _magSub?.cancel();
    _gyroSub?.cancel();
    _guidanceTimer?.cancel();
    _accelSub = null;
    _magSub = null;
    _gyroSub = null;
    _guidanceTimer = null;
  }

  // ════════════════════════════════════════════════════════════
  //  SENSOR FUSION
  // ════════════════════════════════════════════════════════════

  /// Compute camera pitch & roll from accelerometer (gravity reference).
  ///
  /// Phone portrait axes: x=right, y=up, z=out-of-screen-toward-user.
  /// Camera (back) looks along -Z.
  ///
  /// cameraPitch = angle of -Z from horizontal:
  ///   - Phone upright → z≈0, y≈+g → pitch≈0 (camera forward) ✓
  ///   - Phone tilted forward (camera down) → z goes negative → pitch < 0
  ///   - Phone tilted back (camera up)     → z goes positive → pitch > 0
  ///
  /// cameraRoll = sideways rotation:
  ///   - Level → x≈0 → roll≈0
  ///   - Tilted right → x < 0 → roll > 0 (from camera's POV, image tilts right)
  void _updateOrientationFromAccel() {
    final g = sqrt(_ax * _ax + _ay * _ay + _az * _az);
    if (g < 0.1) return; // free-fall guard

    // Camera pitch: positive = looking up, negative = looking down
    final accelPitch = atan2(_az, _ay) * (180.0 / pi);

    // Camera roll: positive = tilted right (from camera's view)
    final accelRoll = atan2(-_ax, _ay) * (180.0 / pi);

    // If gyro hasn't started yet, snap directly
    if (_lastGyroTime == null) {
      _cameraPitch = accelPitch;
      _cameraRoll = accelRoll;
    }
  }

  /// Fuse gyroscope for smooth, low-latency orientation.
  /// Complementary filter: fused = α*(gyro integral) + (1-α)*(accel).
  void _fuseGyro() {
    final now = DateTime.now();
    if (_lastGyroTime != null) {
      final dt = now.difference(_lastGyroTime!).inMicroseconds / 1e6;
      if (dt > 0 && dt < 0.5) {
        // Gyroscope axes in device frame:
        //   gx = rotation around X (pitch change)
        //   gy = rotation around Y (roll change from camera POV)
        final gyroPitchDelta = _gx * dt * (180.0 / pi);
        final gyroRollDelta = -_gy * dt * (180.0 / pi);

        // Accelerometer reference
        final g = sqrt(_ax * _ax + _ay * _ay + _az * _az);
        if (g > 0.1) {
          final accelPitch = atan2(_az, _ay) * (180.0 / pi);
          final accelRoll = atan2(-_ax, _ay) * (180.0 / pi);

          _cameraPitch = _alpha * (_cameraPitch + gyroPitchDelta) +
              (1 - _alpha) * accelPitch;
          _cameraRoll = _alpha * (_cameraRoll + gyroRollDelta) +
              (1 - _alpha) * accelRoll;
        }
      }
    }
    _lastGyroTime = now;
  }

  /// Compute tilt-compensated compass heading from magnetometer.
  void _updateHeading() {
    // Convert pitch/roll to radians for tilt compensation
    final p = _cameraPitch * (pi / 180.0);
    final r = _cameraRoll * (pi / 180.0);

    // Tilt-compensated magnetic components
    final cosP = cos(p);
    final sinP = sin(p);
    final cosR = cos(r);
    final sinR = sin(r);

    final xH = _mx * cosR + _my * sinR * sinP - _mz * sinR * cosP;
    final yH = _my * cosP + _mz * sinP;

    var hdg = atan2(-xH, yH) * (180.0 / pi);
    if (hdg < 0) hdg += 360;
    _heading = hdg;
  }

  // ════════════════════════════════════════════════════════════
  //  GUIDANCE
  // ════════════════════════════════════════════════════════════

  void _emitGuidanceIfNeeded() {
    if (!_isActive || onGuidance == null) return;

    final now = DateTime.now();
    if (now.difference(_lastGuidanceTime).inSeconds < _kCooldownSeconds) return;

    String? guidance;

    // Priority 1: Camera pointing at floor
    if (_cameraPitch < -55) {
      guidance = 'Kamera yere bakıyor. Telefonu biraz kaldırın.';
    }
    // Priority 2: Camera pointing at ceiling
    else if (_cameraPitch > 55) {
      guidance = 'Kamera tavana bakıyor. Telefonu biraz indirin.';
    }
    // Priority 3: Camera tilted down
    else if (_cameraPitch < -_kPitchWarn) {
      guidance = 'Kamera aşağı eğik. Telefonu biraz kaldırın.';
    }
    // Priority 4: Camera tilted up
    else if (_cameraPitch > _kPitchWarn) {
      guidance = 'Kamera yukarı eğik. Telefonu biraz indirin.';
    }
    // Priority 5: Camera tilted sideways
    else if (_cameraRoll > _kRollWarn) {
      guidance = 'Kamera sağa eğik. Telefonu düzeltin.';
    } else if (_cameraRoll < -_kRollWarn) {
      guidance = 'Kamera sola eğik. Telefonu düzeltin.';
    }

    if (guidance != null) {
      _lastGuidanceTime = now;
      onGuidance!(guidance);
    }
  }

  /// Convert compass heading to Turkish cardinal direction.
  String _headingToTurkish(double h) {
    if (h >= 337.5 || h < 22.5) return 'Kuzey';
    if (h < 67.5) return 'Kuzeydoğu';
    if (h < 112.5) return 'Doğu';
    if (h < 157.5) return 'Güneydoğu';
    if (h < 202.5) return 'Güney';
    if (h < 247.5) return 'Güneybatı';
    if (h < 292.5) return 'Batı';
    return 'Kuzeybatı';
  }

  void dispose() {
    stop();
    onGuidance = null;
  }
}
