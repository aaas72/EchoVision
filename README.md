# EchoVision: AI-Powered Auditory Assistant for the Visually Impaired

EchoVision is a "Zero-UI" mobile application designed to empower visually impaired individuals by providing real-time auditory and haptic feedback about their surroundings. Built with Flutter and powered by on-device machine learning, it acts as a digital guide, enhancing safety and independence.

---

## 🎯 Core Mission

The primary goal of EchoVision is to translate the visual world into an intuitive sensory experience. By leveraging advanced computer vision and text-to-speech technology, the app helps users navigate their environment, identify objects, and recognize currency without needing to interact with a complex visual interface.

---

## 🏗️ System Architecture

EchoVision is built on a **Clean Architecture** philosophy, ensuring a modular, scalable, and maintainable codebase. The system is divided into three main engines:

1.  **Vision Pipeline (Input Layer):**
    *   **Technology:** Flutter `camera` plugin.
    *   **Function:** Captures a real-time video stream from the device's camera.
    *   **Optimization:** Implements **Frame Throttling**, processing only a few frames per second (e.g., 3 FPS) to conserve battery and prevent overheating, while still providing real-time feedback.

2.  **Inference Core (AI Processing Layer):**
    *   **Technology:** `tflite_flutter` for on-device inference.
    *   **Function:** Operates **100% offline** for maximum privacy and zero latency. It uses the **YOLO11n** model to analyze frames, outputting bounding boxes and labels.

3.  **Sensory Feedback Engine (Output Layer):**
    *   **Audio Module (`flutter_tts`):** Converts detection labels (e.g., "chair", "car") into clear, localized speech. A **debounce** mechanism prevents repetitive announcements of the same object.
    *   **Haptic Module (`vibration`):** Translates object proximity and position into tactile feedback. A large, centered object triggers a stronger, more distinct vibration, alerting the user to immediate obstacles.

---

## ✨ Key Features

*   **Real-Time Object Detection:** Identifies over 80 common objects from the COCO dataset with high accuracy using the **YOLO11n** model.
*   **Zero-UI Interface:** The application is controlled entirely through full-screen gestures:
    *   **Swipe Right/Left:** Switch between Object Detection and Light Detection modes.
    *   **Double Tap:** Pause or resume all sensory feedback.
*   **Multi-Modal Feedback:** Combines auditory announcements with haptic vibrations for a rich, intuitive user experience.
*   **Cloud-Enhanced Scene Description:** Integrates with the **Gemini Vision API** to provide detailed, natural-language descriptions of complex scenes upon user request.
*   **Environmental Awareness:** Uses device sensors (`sensors_plus`, `geolocator`) to provide context like location, orientation, and ambient light levels.

---

## 📂 Project Structure

```
lib/
├── main.dart                  # Application entry point
├── core/                      # Core constants, enums, and utilities
├── domain/                    # Business logic, entities, and use cases
├── presentation/              # UI Layer (Screens, Widgets, and State Management)
│   └── screens/
│       └── home_screen.dart   # Main camera view and gesture handler
└── services/                  # Isolated services for specific functionalities
    ├── object_detection_service.dart
    ├── currency_detection_service.dart
    ├── tts_service.dart
    ├── camera_service.dart
    └── haptic_service.dart
```

---

## 🛠️ Getting Started

### Prerequisites
*   Flutter SDK (3.6.0 or higher)
*   An Android or iOS physical device (for camera and sensor access)
*   Android Studio / VS Code

### Installation
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/aaas72/EchoVision.git
    cd EchoVision
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Models:**
    *   Place your primary object detection model at `assets/models/detect.tflite`.
    *   The application will automatically adapt to the model's specific input/output signature.

4.  **Run the application:**
    ```bash
    flutter run
    ```

---

## 🚀 Future Roadmap

*   **Depth Estimation:** Integrate depth-sensing capabilities to announce the *distance* to detected objects (e.g., "Car, 5 meters away").
*   **Optical Character Recognition (OCR):** Add a module to read text from signs, documents, and product labels.
*   **Advanced Navigation Mode:** Provide turn-by-turn walking directions that are integrated with real-time obstacle avoidance.

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

