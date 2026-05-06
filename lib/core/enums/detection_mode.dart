/// Represents the current operational mode of the app.
/// Modes are split into Local (Offline) and Cloud (Gemini).
enum DetectionMode {
  /// LIVE: Detect objects in the environment using local YOLO model.
  object,

  /// LIVE: Continuous audio-haptic feedback based on light levels.
  light,

  /// LIVE: High-speed detection of hazards (stairs, cars, etc.) - Local.
  hazard,

  /// CLOUD: Detailed currency recognition using Gemini.
  currency,

  /// CLOUD: Detailed medication label analysis using Gemini.
  medication,

  /// CLOUD: Full scene description using Gemini.
  scene,
}
