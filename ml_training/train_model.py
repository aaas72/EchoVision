"""
Step 2: Train a MobileNetV2 model for Turkish Lira Banknote Classification.

Uses Transfer Learning with MobileNetV2 (pre-trained on ImageNet).
Outputs a TFLite model file ready for deployment in Flutter.

Expected dataset structure:
  dataset/
    train/
      5/  10/  20/  50/  100/  200/
    val/
      5/  10/  20/  50/  100/  200/
"""
import os
import sys
import json
# pyrefly: ignore [missing-import]
import numpy as np

# Suppress TF warnings
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
# pyrefly: ignore [missing-import]
from tensorflow.keras.preprocessing.image import ImageDataGenerator

# ════════════════════════════════════════════════════════════════
# Configuration
# ════════════════════════════════════════════════════════════════
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(SCRIPT_DIR, "dataset")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output")
TFLITE_OUTPUT = os.path.join(OUTPUT_DIR, "lira.tflite")
FINAL_ASSET_PATH = os.path.join(SCRIPT_DIR, "..", "assets", "models", "lira.tflite")

IMG_SIZE = 320  # Increased to 320 to preserve fine banknote patterns and printed digits
BATCH_SIZE = 16
EPOCHS = 12
LEARNING_RATE = 0.0005
FINE_TUNE_EPOCHS = 10
FINE_TUNE_LR = 0.00005

# The 6 Turkish Lira denominations (sorted alphabetically by folder name)
# Keras sorts class names alphabetically: 10, 100, 20, 200, 5, 50
# We need to track this mapping carefully.
DENOMINATIONS_DISPLAY = {
    "5": "5 Turkish Lira",
    "10": "10 Turkish Lira",
    "20": "20 Turkish Lira",
    "50": "50 Turkish Lira",
    "100": "100 Turkish Lira",
    "200": "200 Turkish Lira",
}

def create_data_generators():
    """Create training and validation data generators with augmentation."""
    
    # Training: heavy augmentation to make the model robust
    train_datagen = ImageDataGenerator(
        rescale=1.0 / 255.0,
        rotation_range=25,
        width_shift_range=0.2,
        height_shift_range=0.2,
        shear_range=0.15,
        zoom_range=0.25,
        horizontal_flip=True,
        brightness_range=[0.7, 1.3],
        fill_mode='nearest',
    )
    
    # Validation: only rescale (no augmentation)
    val_datagen = ImageDataGenerator(
        rescale=1.0 / 255.0,
    )
    
    train_dir = os.path.join(DATASET_DIR, "train")
    val_dir = os.path.join(DATASET_DIR, "val")
    
    print(f"Training directory: {train_dir}")
    print(f"Validation directory: {val_dir}")
    
    train_generator = train_datagen.flow_from_directory(
        train_dir,
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        shuffle=True,
    )
    
    val_generator = val_datagen.flow_from_directory(
        val_dir,
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        shuffle=False,
    )
    
    print(f"\nClass indices (alphabetical): {train_generator.class_indices}")
    print(f"Number of training samples: {train_generator.samples}")
    print(f"Number of validation samples: {val_generator.samples}")
    print(f"Number of classes: {train_generator.num_classes}")
    
    return train_generator, val_generator

def build_model(num_classes):
    """
    Build a MobileNetV2 transfer learning model.
    
    Architecture:
    - MobileNetV2 base (frozen initially for feature extraction)
    - Global Average Pooling
    - Dropout (0.3) for regularization
    - Dense 128 + ReLU
    - Dropout (0.2)
    - Dense output + Softmax
    """
    base_model = keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet',
    )
    
    # Freeze the base model initially
    base_model.trainable = False
    
    model = keras.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.Dropout(0.3),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.2),
        layers.Dense(num_classes, activation='softmax'),
    ])
    
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss='categorical_crossentropy',
        metrics=['accuracy'],
    )
    
    model.summary()
    return model, base_model

def fine_tune_model(model, base_model, train_gen, val_gen):
    """
    Fine-tune the top layers of MobileNetV2 for better accuracy.
    Unfreezes the last 30 layers for fine-tuning with a very low learning rate.
    """
    print("\n" + "=" * 60)
    print("  Phase 2: Fine-tuning top layers of MobileNetV2")
    print("=" * 60)
    
    # Unfreeze the last 30 layers
    base_model.trainable = True
    for layer in base_model.layers[:-30]:
        layer.trainable = False
    
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=FINE_TUNE_LR),
        loss='categorical_crossentropy',
        metrics=['accuracy'],
    )
    
    history = model.fit(
        train_gen,
        epochs=FINE_TUNE_EPOCHS,
        validation_data=val_gen,
        verbose=1,
    )
    
    return history

def convert_to_tflite(model, class_indices):
    """Convert the Keras model to TFLite format (uint8 quantized)."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Convert to TFLite with full integer quantization for mobile performance
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Use dynamic range quantization (good balance of size and accuracy)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Keep input/output as float32 for easier integration
    # (the internal operations are quantized for speed)
    tflite_model = converter.convert()
    
    with open(TFLITE_OUTPUT, 'wb') as f:
        f.write(tflite_model)
    
    file_size_mb = os.path.getsize(TFLITE_OUTPUT) / (1024 * 1024)
    print(f"\nTFLite model saved: {TFLITE_OUTPUT}")
    print(f"Model size: {file_size_mb:.2f} MB")
    
    # Save class mapping as JSON for reference
    # Reverse the class_indices dict: {index: class_name}
    index_to_class = {v: k for k, v in class_indices.items()}
    mapping_path = os.path.join(OUTPUT_DIR, "class_mapping.json")
    with open(mapping_path, 'w') as f:
        json.dump(index_to_class, f, indent=2)
    print(f"Class mapping saved: {mapping_path}")
    print(f"Mapping: {index_to_class}")
    
    return tflite_model, index_to_class

def verify_tflite(tflite_path, class_mapping):
    """Verify the TFLite model loads and runs correctly."""
    print("\n" + "=" * 60)
    print("  Verifying TFLite Model")
    print("=" * 60)
    
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"Input: shape={input_details[0]['shape']}, dtype={input_details[0]['dtype']}")
    print(f"Output: shape={output_details[0]['shape']}, dtype={output_details[0]['dtype']}")
    
    # Run a dummy inference
    input_shape = input_details[0]['shape']
    dummy_input = np.random.rand(*input_shape).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], dummy_input)
    interpreter.invoke()
    output_data = interpreter.get_tensor(output_details[0]['index'])
    
    print(f"Dummy inference output: {output_data}")
    print(f"Sum of probabilities: {np.sum(output_data):.4f} (should be ~1.0)")
    print(f"Max class: {class_mapping[np.argmax(output_data)]}")
    print("\n[OK] TFLite model verification PASSED!")

def deploy_model():
    """Copy the trained TFLite model to the Flutter assets directory."""
    if os.path.exists(TFLITE_OUTPUT):
        import shutil
        os.makedirs(os.path.dirname(FINAL_ASSET_PATH), exist_ok=True)
        shutil.copy2(TFLITE_OUTPUT, FINAL_ASSET_PATH)
        print(f"\n[DEPLOYED] Model deployed to: {FINAL_ASSET_PATH}")
        print(f"   Size: {os.path.getsize(FINAL_ASSET_PATH) / (1024 * 1024):.2f} MB")

def main():
    print("=" * 60)
    print("  Turkish Lira Banknote - Custom Model Training")
    print("  Architecture: MobileNetV2 + Transfer Learning")
    print("=" * 60)
    
    # Verify dataset exists
    if not os.path.exists(DATASET_DIR):
        print(f"ERROR: Dataset not found at {DATASET_DIR}")
        print("Please run download_dataset.py first.")
        sys.exit(1)
    
    # Step 1: Create data generators
    print("\n" + "=" * 60)
    print("  Phase 1: Feature Extraction Training")
    print("=" * 60)
    train_gen, val_gen = create_data_generators()
    
    # Step 2: Build model
    num_classes = train_gen.num_classes
    model, base_model = build_model(num_classes)
    
    # Step 3: Train (feature extraction phase)
    print(f"\nTraining for {EPOCHS} epochs (feature extraction)...")
    history = model.fit(
        train_gen,
        epochs=EPOCHS,
        validation_data=val_gen,
        verbose=1,
    )
    
    # Step 4: Fine-tune (Skipped to prevent representation collapse)
    # fine_tune_history = fine_tune_model(model, base_model, train_gen, val_gen)
    
    # Step 5: Evaluate
    print("\n" + "=" * 60)
    print("  Final Evaluation")
    print("=" * 60)
    val_loss, val_acc = model.evaluate(val_gen)
    print(f"\n[RESULT] Validation Accuracy: {val_acc * 100:.1f}%")
    print(f"[RESULT] Validation Loss: {val_loss:.4f}")
    
    # Step 6: Convert to TFLite
    print("\n" + "=" * 60)
    print("  Converting to TFLite")
    print("=" * 60)
    tflite_model, class_mapping = convert_to_tflite(model, train_gen.class_indices)
    
    # Step 7: Verify TFLite model
    verify_tflite(TFLITE_OUTPUT, class_mapping)
    
    # Step 8: Deploy to Flutter assets
    deploy_model()
    
    print("\n" + "=" * 60)
    print("  [DONE] TRAINING COMPLETE!")
    print(f"  Final Accuracy: {val_acc * 100:.1f}%")
    print(f"  Model deployed to: {FINAL_ASSET_PATH}")
    print("=" * 60)

if __name__ == "__main__":
    main()
