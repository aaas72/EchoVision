"""
Step 1 (Fixed): Re-organize Turkish Lira Banknote Dataset properly.
Fixes the denomination mapping where 100 was merged with 10, 200 with 20, 50 with 5.
"""
import os
import sys
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RAW_DIR = os.path.join(SCRIPT_DIR, "dataset_raw")
FINAL_DIR = os.path.join(SCRIPT_DIR, "dataset")

DENOMINATIONS = ["5", "10", "20", "50", "100", "200"]

def main():
    print("=" * 60)
    print("  Re-organizing dataset with CORRECT denomination mapping")
    print("=" * 60)
    
    # Find the repo directory
    repo_dir = os.path.join(RAW_DIR, "TurkishBanknoteDataset-master")
    if not os.path.exists(repo_dir):
        print(f"ERROR: {repo_dir} not found")
        sys.exit(1)
    
    # Clean up the incorrectly organized dataset
    if os.path.exists(FINAL_DIR):
        shutil.rmtree(FINAL_DIR)
    
    # Create clean directory structure
    for split in ["train", "val"]:
        for denom in DENOMINATIONS:
            os.makedirs(os.path.join(FINAL_DIR, split, denom), exist_ok=True)
    
    total = 0
    
    # Process the original 'train' and 'test' folders from the repo
    for source_split in ["train", "test"]:
        source_dir = os.path.join(repo_dir, source_split)
        if not os.path.exists(source_dir):
            print(f"WARNING: {source_dir} not found, skipping")
            continue
        
        print(f"\nProcessing source: {source_split}/")
        
        for denom_folder in sorted(os.listdir(source_dir)):
            denom_path = os.path.join(source_dir, denom_folder)
            if not os.path.isdir(denom_path):
                continue
            
            # EXACT match only - folder name must be exactly one of our denominations
            if denom_folder not in DENOMINATIONS:
                print(f"  WARNING: Unknown folder '{denom_folder}', skipping")
                continue
            
            images = [f for f in os.listdir(denom_path) 
                     if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]
            
            if not images:
                print(f"  {denom_folder} TL: 0 images (empty)")
                continue
            
            # 80/20 split for our train/val
            split_idx = int(len(images) * 0.8)
            train_imgs = images[:split_idx]
            val_imgs = images[split_idx:]
            
            # Copy to final structure (prefix with source to avoid name collisions)
            for img_name in train_imgs:
                src = os.path.join(denom_path, img_name)
                dst_name = f"{source_split}_{img_name}"
                dst = os.path.join(FINAL_DIR, "train", denom_folder, dst_name)
                shutil.copy2(src, dst)
                total += 1
            
            for img_name in val_imgs:
                src = os.path.join(denom_path, img_name)
                dst_name = f"{source_split}_{img_name}"
                dst = os.path.join(FINAL_DIR, "val", denom_folder, dst_name)
                shutil.copy2(src, dst)
                total += 1
            
            print(f"  {denom_folder} TL: {len(train_imgs)} train + {len(val_imgs)} val = {len(images)} total")
    
    # Print summary
    print("\n" + "=" * 60)
    print("  Final Dataset Summary")
    print("=" * 60)
    
    for split in ["train", "val"]:
        print(f"\n  {split}/")
        for denom in DENOMINATIONS:
            denom_dir = os.path.join(FINAL_DIR, split, denom)
            count = len([f for f in os.listdir(denom_dir) 
                        if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]) if os.path.exists(denom_dir) else 0
            print(f"    {denom} TL: {count} images")
    
    print(f"\n  Total images: {total}")
    print("=" * 60)

if __name__ == "__main__":
    main()
