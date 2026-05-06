# EchoVision: Advanced AI-Powered Assistant for the Visually Impaired

EchoVision is a high-performance mobile application designed to provide real-time visual intelligence and auditory guidance for visually impaired individuals. It follows a "Zero-UI" philosophy, where the entire environment is translated into speech and tactile feedback through advanced computer vision and Google Gemini AI integration.

## Project Overview

EchoVision acts as a real-time digital companion, allowing users to understand their surroundings, identify critical objects, read medication details, and detect hazards safely. The system combines local, ultra-fast on-device processing (YOLO11) with powerful cloud-based intelligence (Gemini Vision) to offer a comprehensive sensory experience.

## Intelligent Detection Modes

The application features six specialized operating modes, easily switched via simple gestures:

1. Hazard Detection: Identifies immediate physical dangers such as stairs, holes, or cables on the floor.
2. Scene Description: Provides a high-level overview of the surroundings, layout, and spatial references.
3. Medication Assistant: Reads medical packaging, names, and dosages with strict safety protocols.
4. Currency Recognition: Identifies banknotes and coins to calculate total amounts in hand.
5. Object Identification: Real-time, offline detection of common daily objects.
6. Light Detection: Monitors ambient light levels and sources for environmental orientation.

## Core Technology Stack

- Framework: Flutter (High-performance cross-platform development).
- Local AI Engine: YOLO11n (Real-time, offline object detection with zero latency).
- Cloud AI Engine: Google Gemini 2.0 Flash (Advanced scene analysis and complex visual reasoning).
- Speech Engine: Flutter TTS (Optimized for US English with high-quality network voices).
- Haptics: Advanced vibration patterns for proximity alerts and system state feedback.

## Advanced Features and Optimizations

- Smart Haptic Feedback: The system provides a rhythmic "thinking" vibration while processing cloud requests, ensuring the user knows the app is working.
- Seamless Speech Synchronization: Visual subtitles are minimalist, faded, and perfectly synchronized word-by-word with the audio output.
- Medical Safety Protocols: Strict instructions prevent the AI from guessing medication dosages; it explicitly warns the user if text is not 100% clear.
- Data Efficiency: Intelligent image processing resizes and compresses captures to 1024px before transmission, reducing data usage by up to 95%.
- Secure Architecture: API credentials are never hardcoded and are managed through protected environment variables (.env).

## Interface and Gestures

EchoVision is designed to be used without looking at the screen:

- Single Tap: Capture and analyze (in Cloud modes).
- Horizontal Swipe: Switch between detection modes.
- Vertical Swipe: Get current location and environment status.
- Double Tap: Toggle Mute/Unmute for audio feedback.
- Long Press: Toggle camera flash for low-light environments.

## Architecture and Security

The project follows Clean Architecture principles to ensure modularity and reliability:

- Domain Layer: Contains the core business logic and detection entities.
- Data/Service Layer: Handles camera hardware, TTS engine, and API communication.
- Presentation Layer: Manages the camera preview and gesture-driven state machine.

Security is a priority; the application uses flutter_dotenv to handle sensitive API keys, ensuring that credentials are never leaked to version control systems.

## Getting Started

1. Clone the repository.
2. Run 'flutter pub get' to install dependencies.
3. Create a '.env' file in the root directory.
4. Add your API key: GEMINI_API_KEY=your_key_here.
5. Ensure your AndroidManifest.xml includes INTERNET permissions for cloud features.
6. Build and run in Release mode for optimal performance.

## License

This project is licensed under the MIT License.
