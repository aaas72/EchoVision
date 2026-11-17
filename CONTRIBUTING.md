# Contributing to EchoVision

EchoVision helps visually impaired people understand their surroundings. Every contribution — code, tests, translations or accessibility feedback — makes a real difference. Thank you for being here!

## Ground rules

- **Zero-UI first.** Every result must be spoken (TTS) and, where relevant, confirmed with haptics. Never add a feature that only shows something on screen.
- **On-device when possible.** Detection runs locally with TensorFlow Lite; only scene description and text reading use the Gemini API.
- **Test with a screen reader.** If you touch the UI, try it with TalkBack enabled.

## Getting started

**Requirements:** Flutter SDK, an Android device with a camera, a Google Gemini API key.

```bash
git clone https://github.com/aaas72/EchoVision.git
cd EchoVision
flutter pub get
echo "GEMINI_API_KEY=your_key_here" > .env
flutter run --release
```

Never commit your `.env` file.

## Where things live

| Path | What it does |
|---|---|
| `lib/services/` | Camera, YOLO detection, currency model, OCR, TTS, haptics, Gemini |
| `lib/presentation/` | Screens and widgets |
| `lib/domain/models/` | Detection result models |
| `ml_training/` | Dataset download and YOLO training scripts for the currency model |
| `test/` | Flutter tests |

## Making a change

1. Look for issues labelled [`good first issue`](https://github.com/aaas72/EchoVision/labels/good%20first%20issue), or open an issue describing what you'd like to change.
2. Create a branch: `git checkout -b feat/short-description`.
3. Run `flutter analyze` and `flutter test` — both must pass.
4. Open a pull request describing the change and how you tested it (device model, Android version).

## Retraining the currency model

Follow the steps in the README. The dataset is downloaded by `ml_training/download_dataset.py` and must not be committed. Include the updated metrics in `ml_training/yolo_runs/*/MODEL_CARD.md`.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
