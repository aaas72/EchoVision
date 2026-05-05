# EchoVision AI Models

This directory contains the optimized machine learning models for real-time visual assistance.

## Current Model
- **YOLO11n (Object Detection)**: `yolo11n.tflite`
- **Labels**: `labelmap.txt` (COCO dataset with Arabic translations in `yolo_service.dart`)

## Optimization
The YOLO11n model is optimized for on-device inference using TFLite, providing high accuracy for 80+ common objects with minimal latency.
