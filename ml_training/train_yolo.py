import os
import sys
import shutil
# pyrefly: ignore [missing-import]
from ultralytics import YOLO

# Suppress TF warnings
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(SCRIPT_DIR, "dataset")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output")
FINAL_ASSET_PATH = os.path.join(SCRIPT_DIR, "..", "assets", "models", "lira.tflite")

def main():
    print("=" * 60)
    # Replaced emojis with ASCII symbols to prevent Windows terminal encoding crashes
    print("  [YOLOv11] Custom Turkish Lira Banknote Classifier Training")
    print("  Backbone: YOLOv11-nano-classification (yolo11n-cls)")
    print("  Image Size: 640x640")
    print("=" * 60)

    # Verify dataset exists
    if not os.path.exists(DATASET_DIR):
        print(f"ERROR: Dataset not found at {DATASET_DIR}")
        sys.exit(1)

    # Step 1: Load pre-trained YOLOv11-nano classification model
    print("\n[STEP 1] Loading YOLOv11-nano-classification model...")
    model = YOLO("yolo11n-cls.pt")

    # Step 2: Train on banknote dataset
    # We use 20 epochs because YOLOv11 converges extremely fast on classification
    print("\n[STEP 2] Training model on banknote dataset at 640x640...")
    results = model.train(
        data=DATASET_DIR,
        epochs=8,
        imgsz=640,
        workers=2,
        project=os.path.join(SCRIPT_DIR, "yolo_runs"),
        name="lira_yolo11",
        exist_ok=True
    )

    # Step 3: Export the best trained model to TFLite format
    print("\n[STEP 3] Exporting trained model to TFLite format...")
    # This generates 'best_float32.tflite' or 'best.tflite' inside yolo_runs/lira_yolo11/weights/
    tflite_path = model.export(format="tflite", imgsz=640)
    print(f"Exported TFLite Path: {tflite_path}")

    # Step 4: Deploy model to assets
    print("\n[STEP 4] Deploying model to Flutter assets...")
    os.makedirs(os.path.dirname(FINAL_ASSET_PATH), exist_ok=True)
    
    # Locate the generated TFLite file
    # Ultralytics model.export normally creates it next to the weights, or in the weights folder
    weights_dir = os.path.join(SCRIPT_DIR, "yolo_runs", "lira_yolo11", "weights")
    tflite_source = None
    
    # Search for any tflite file in weights directory
    if os.path.exists(weights_dir):
        for file in os.listdir(weights_dir):
            if file.endswith(".tflite"):
                tflite_source = os.path.join(weights_dir, file)
                break
                
    if not tflite_source and tflite_path and os.path.exists(tflite_path):
        tflite_source = tflite_path

    if tflite_source and os.path.exists(tflite_source):
        shutil.copy2(tflite_source, FINAL_ASSET_PATH)
        print(f"[DEPLOYED] Model successfully deployed to: {FINAL_ASSET_PATH}")
        print(f"   Size: {os.path.getsize(FINAL_ASSET_PATH) / (1024 * 1024):.2f} MB")
    else:
        # Fallback search in case ultralytics exported somewhere else
        print("WARNING: Could not find exported TFLite file inside runs directory. Searching...")
        for root, dirs, files in os.walk(os.path.join(SCRIPT_DIR, "yolo_runs")):
            for file in files:
                if file.endswith(".tflite"):
                    tflite_source = os.path.join(root, file)
                    shutil.copy2(tflite_source, FINAL_ASSET_PATH)
                    print(f"[DEPLOYED] Found and deployed: {tflite_source}")
                    break
            if tflite_source:
                break
                
    print("\n" + "=" * 60)
    print("  [DONE] YOLOv11 BANKNOTE TRAINING COMPLETE!")
    print("=" * 60)

if __name__ == "__main__":
    main()
