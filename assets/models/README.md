# EchoVision AI Models

This directory contains the optimized machine learning models for real-time visual assistance.

## Active Models

### 🟢 Object Detection (General)
- **Model:** `yolov8n-oiv7.tflite`
- **Labels:** `labelmap.txt` (Open Images v7 dataset, 600 classes with Turkish translations in `detection_result.dart`)
- **Architecture:** YOLOv8n
- **Purpose:** Detecting 600+ common objects in real-time

### 🟢 Currency Recognition (Turkish Lira) — **OFFICIAL v2**
- **Model:** `lira.tflite`
- **Architecture:** YOLOv11n-cls (Classification)
- **Input Size:** 640 × 640 px
- **Classes:** 6 denominations (5, 10, 20, 50, 100, 200 Turkish Lira)
- **Validation Accuracy:** 97.2%
- **Adopted:** 2026-06-01
- **Training Run:** `ml_training/yolo_runs/lira_yolo11/`
- **Source Weights:** `ml_training/yolo_runs/lira_yolo11/weights/best.pt`

## Model History

| Version | File | Architecture | Accuracy | Status |
|---------|------|--------------|----------|--------|
| v1 | `lira.tflite` (old) | MobileNetV2 | ~70% | ❌ Retired |
| **v2** | **`lira.tflite`** | **YOLOv11n-cls** | **97.2%** | ✅ **Official** |

## Optimization
All models are optimized for on-device inference using TFLite, providing high accuracy with minimal latency on Android devices.
