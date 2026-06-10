import os
from ultralytics import YOLO

def main():
    print("Loading yolov8n-oiv7.pt...")
    # This will automatically download and load the Open Images v7 model
    model = YOLO("yolov8n-oiv7.pt")
    
    print("Exporting model to TFLite...")
    # Export the model
    # We use int8=False, float16=False for default FP32 precision
    model.export(format="tflite", imgsz=640)
    print("Export completed successfully!")

if __name__ == "__main__":
    main()
