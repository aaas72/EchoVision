# EchoVision

**An AI-powered visual assistant for visually impaired people.** EchoVision follows a "Zero-UI" philosophy: the camera reads the world and the app speaks it back, with haptic feedback, so the user never needs to look at the screen.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![TensorFlow Lite](https://img.shields.io/badge/TensorFlow_Lite-FF6F00?style=flat-square&logo=tensorflow&logoColor=white)
![YOLO](https://img.shields.io/badge/YOLO11-111F68?style=flat-square)
![Gemini](https://img.shields.io/badge/Google_Gemini-8E75B2?style=flat-square&logo=googlegemini&logoColor=white)
![ML Kit](https://img.shields.io/badge/ML_Kit-4285F4?style=flat-square&logo=google&logoColor=white)

## Detection Modes

Seven modes, switched with a horizontal swipe:

| Mode | What it does | Runs |
|---|---|---|
| **Object identification** | Live detection of everyday objects around the user | On-device (YOLO11n) |
| **Object in hand** | Crops the hand region and identifies the item being held | On-device |
| **Currency recognition** | Identifies Turkish Lira banknotes | On-device (custom model) |
| **Text reading** | Reads documents and signs aloud | On-device (ML Kit) |
| **Medication assistant** | Reads drug names and dosages, and refuses to guess when text is unclear | Cloud (Gemini) |
| **Scene description** | Describes the surroundings, layout and obstacles with spatial references | Cloud (Gemini) |
| **Light detection** | Continuous audio-haptic feedback on ambient light | On-device |

## Gestures

| Gesture | Action |
|---|---|
| Single tap | Capture and analyze (cloud modes) |
| Horizontal swipe | Switch mode |
| Vertical swipe | Announce current location and status |
| Double tap | Mute / unmute |
| Long press | Toggle flashlight |

## AI Models

| Model | Purpose | Notes |
|---|---|---|
| YOLO11n (TFLite) | Real-time object detection | Fully offline, low latency |
| YOLO11n-cls — custom trained | Turkish Lira classification | **97.2 % validation accuracy**, 6 denominations — see the [model card](ml_training/yolo_runs/lira_yolo11/MODEL_CARD.md) |
| Google ML Kit | Text recognition | Documents and signs |
| Gemini Flash | Scene and medication analysis | Images resized to 1024 px before upload, cutting data use by up to 95 % |

## Accessibility & UX Details

- **"Thinking" haptics** — a rhythmic vibration while a cloud request is in progress, so the user knows the app is working
- **Synchronized speech** — minimal, fading subtitles timed word by word with text-to-speech
- **Medical safety** — the assistant is instructed never to guess a dosage and to warn when text is not fully legible
- **Audio cues** — distinct sounds for start, success and error states
- **Spoken onboarding** — a voice-guided introduction on first launch

## Architecture

```text
lib/
├── core/            # Constants, detection-mode enums, theme
├── domain/models/   # DetectedObject, DetectionResult
├── services/        # camera, yolo, lira_detector, text_recognition, gemini,
│                    # tts, haptic, audio_feedback, light_detector, location, orientation
└── presentation/    # Home and onboarding screens, camera preview, bounding boxes, mode pill

ml_training/         # Dataset preparation, YOLO training scripts and run artifacts
assets/models/       # Bundled TFLite models and label maps
```

Each capability is an isolated service, so the gesture-driven UI state machine stays independent from hardware, ML and network concerns.

## Getting Started

**Requirements:** Flutter SDK, an Android device (camera required), a Google Gemini API key

```bash
flutter pub get
```

Create a `.env` file in the project root:

```env
GEMINI_API_KEY=your_key_here
```

Run on a physical device — release mode is recommended for real-time inference:

```bash
flutter run --release
```

## Training the Currency Model

```bash
cd ml_training
python download_dataset.py   # fetches the Turkish banknote dataset (not stored in this repo)
python train_yolo.py
```

Export the best weights to TFLite and place the file at `assets/models/lira.tflite`. Training parameters and results are recorded in the model card.

## Author

**Abdellah Sheikh** — [abdellahsheikh.dev](https://abdellahsheikh.dev) · [LinkedIn](https://www.linkedin.com/in/abdellahsheikh)
