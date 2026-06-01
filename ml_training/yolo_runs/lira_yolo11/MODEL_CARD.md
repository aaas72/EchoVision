# 🏆 YOLOv11n-cls — Turkish Lira Currency Model (Official v2)

**Status:** ✅ OFFICIALLY ADOPTED — 2026-06-01  
**Deployed to:** `assets/models/lira.tflite`

---

## Training Summary

| Parameter | Value |
|-----------|-------|
| Architecture | YOLOv11n-cls |
| Base Model | yolo11n-cls.pt (pretrained) |
| Input Size | 640 × 640 px |
| Epochs | 8 |
| Batch Size | 16 |
| Optimizer | Auto (SGD) |
| Device | CPU |

## Results

| Metric | Value |
|--------|-------|
| **Validation Accuracy** | **97.2%** |
| Top-1 | 97.2% |
| Top-5 | 100% |

## Classes (Alphabetical — matches model output indices)

| Index | Class |
|-------|-------|
| 0 | 10 Turkish Lira |
| 1 | 100 Turkish Lira |
| 2 | 20 Turkish Lira |
| 3 | 200 Turkish Lira |
| 4 | 5 Turkish Lira |
| 5 | 50 Turkish Lira |

## Deployment Pipeline

```
best.pt  →  best.onnx  →  lira.tflite
  3.2 MB       6.2 MB        6.2 MB
```

## Key Improvement Over v1

- **v1 (MobileNetV2):** ~70% accuracy, confused 5 vs 50 Lira due to low resolution (224×224)
- **v2 (YOLOv11n-cls):** 97.2% accuracy at 640×640 — enough resolution to "read" the digit on the banknote

## Files

- `weights/best.pt` — PyTorch source weights
- `weights/best.onnx` — ONNX intermediate
- `weights/best_saved_model/` — TFLite saved model directory
- `args.yaml` — Full training configuration
- `results.csv` — Per-epoch training metrics
- `confusion_matrix.png` — Per-class confusion matrix
