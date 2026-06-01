"""
Step 1: Download Turkish Lira Banknote Dataset from GitHub
Source: https://github.com/ozgurshn/TurkishBanknoteDataset
"""
import os
import sys
import zipfile
import urllib.request
import shutil

DATASET_URL = "https://github.com/ozgurshn/TurkishBanknoteDataset/archive/refs/heads/master.zip"
DOWNLOAD_DIR = os.path.dirname(os.path.abspath(__file__))
ZIP_PATH = os.path.join(DOWNLOAD_DIR, "dataset.zip")
EXTRACT_DIR = os.path.join(DOWNLOAD_DIR, "dataset_raw")
FINAL_DIR = os.path.join(DOWNLOAD_DIR, "dataset")

def download_with_progress(url, filepath):
    """Download a file with progress reporting."""
    print(f"Downloading dataset from:\n  {url}")
    print(f"Saving to: {filepath}")
    
    def reporthook(blocknum, blocksize, totalsize):
        downloaded = blocknum * blocksize
        if totalsize > 0:
            percent = min(100, downloaded * 100 / totalsize)
            mb_down = downloaded / (1024 * 1024)
            mb_total = totalsize / (1024 * 1024)
            sys.stdout.write(f"\r  Progress: {percent:.1f}% ({mb_down:.1f}/{mb_total:.1f} MB)")
            sys.stdout.flush()
        else:
            mb_down = downloaded / (1024 * 1024)
            sys.stdout.write(f"\r  Downloaded: {mb_down:.1f} MB")
            sys.stdout.flush()
    
    urllib.request.urlretrieve(url, filepath, reporthook)
    print("\n  Download complete!")

def organize_dataset(raw_dir, final_dir):
    """
    Organize the downloaded dataset into a clean structure:
    dataset/
      train/
        5/
        10/
        20/
        50/
        100/
        200/
      val/
        5/
        10/
        20/
        50/
        100/
        200/
    """
    denominations = ["5", "10", "20", "50", "100", "200"]
    
    # Create directory structure
    for split in ["train", "val"]:
        for denom in denominations:
            os.makedirs(os.path.join(final_dir, split, denom), exist_ok=True)
    
    # Find the extracted repo directory
    repo_dir = None
    for item in os.listdir(raw_dir):
        full_path = os.path.join(raw_dir, item)
        if os.path.isdir(full_path) and "Turkish" in item:
            repo_dir = full_path
            break
    
    if repo_dir is None:
        # Try to find any directory
        for item in os.listdir(raw_dir):
            full_path = os.path.join(raw_dir, item)
            if os.path.isdir(full_path):
                repo_dir = full_path
                break
    
    if repo_dir is None:
        print(f"ERROR: Could not find dataset directory in {raw_dir}")
        print(f"Contents: {os.listdir(raw_dir)}")
        sys.exit(1)
    
    print(f"\nFound dataset directory: {repo_dir}")
    print(f"Contents: {os.listdir(repo_dir)}")
    
    # Map folder names to denomination labels
    # The dataset may use various naming conventions
    denomination_mapping = {}
    for item in os.listdir(repo_dir):
        item_path = os.path.join(repo_dir, item)
        if not os.path.isdir(item_path):
            continue
        
        # Try to extract denomination from folder name
        item_lower = item.lower().replace("tl", "").replace("lira", "").replace("_", "").replace(" ", "").replace("türk", "").replace("turk", "")
        
        for denom in denominations:
            if denom in item_lower or item == denom:
                denomination_mapping[item] = denom
                break
        
        # If we couldn't map it, check if the folder contains subfolders with denominations
        if item not in denomination_mapping:
            # Maybe this is a "train"/"test"/"val" split folder
            sub_items = os.listdir(item_path)
            if any(d in sub_items for d in denominations) or any("tl" in s.lower() or "lira" in s.lower() for s in sub_items):
                print(f"  Found split folder: {item} with contents: {sub_items}")
                # This is a split directory, process recursively
                for sub_item in sub_items:
                    sub_path = os.path.join(item_path, sub_item)
                    if os.path.isdir(sub_path):
                        sub_lower = sub_item.lower().replace("tl", "").replace("lira", "").replace("_", "").replace(" ", "")
                        for denom in denominations:
                            if denom in sub_lower or sub_item == denom:
                                denomination_mapping[os.path.join(item, sub_item)] = denom
                                break
    
    print(f"\nDenomination mapping: {denomination_mapping}")
    
    # If no mapping found, scan deeper
    if not denomination_mapping:
        print("\nNo direct mapping found. Scanning all subdirectories...")
        for root, dirs, files in os.walk(repo_dir):
            image_files = [f for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]
            if image_files:
                rel_path = os.path.relpath(root, repo_dir)
                folder_name = os.path.basename(root)
                folder_lower = folder_name.lower().replace("tl", "").replace("lira", "").replace("_", "").replace(" ", "")
                for denom in denominations:
                    if denom in folder_lower or folder_name == denom:
                        denomination_mapping[rel_path] = denom
                        print(f"  Mapped: {rel_path} -> {denom} ({len(image_files)} images)")
                        break
    
    if not denomination_mapping:
        print("\nERROR: Could not determine denomination folders.")
        print("Listing all directories found:")
        for root, dirs, files in os.walk(repo_dir):
            image_files = [f for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]
            if image_files:
                print(f"  {os.path.relpath(root, repo_dir)}: {len(image_files)} images")
        sys.exit(1)
    
    # Copy images with 80/20 train/val split
    total_copied = 0
    for folder_rel_path, denom in denomination_mapping.items():
        src_dir = os.path.join(repo_dir, folder_rel_path)
        if not os.path.isdir(src_dir):
            continue
        
        images = [f for f in os.listdir(src_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]
        
        # 80% train, 20% val
        split_idx = int(len(images) * 0.8)
        train_images = images[:split_idx]
        val_images = images[split_idx:]
        
        for img_name in train_images:
            src = os.path.join(src_dir, img_name)
            dst = os.path.join(final_dir, "train", denom, img_name)
            shutil.copy2(src, dst)
            total_copied += 1
        
        for img_name in val_images:
            src = os.path.join(src_dir, img_name)
            dst = os.path.join(final_dir, "val", denom, img_name)
            shutil.copy2(src, dst)
            total_copied += 1
        
        print(f"  Denomination {denom} TL: {len(train_images)} train + {len(val_images)} val = {len(images)} total")
    
    print(f"\nTotal images organized: {total_copied}")
    return total_copied

def main():
    print("=" * 60)
    print("  Turkish Lira Banknote Dataset Downloader")
    print("=" * 60)
    
    # Step 1: Download
    if not os.path.exists(ZIP_PATH):
        download_with_progress(DATASET_URL, ZIP_PATH)
    else:
        print(f"ZIP already exists: {ZIP_PATH}")
    
    # Step 2: Extract
    if os.path.exists(EXTRACT_DIR):
        shutil.rmtree(EXTRACT_DIR)
    
    print(f"\nExtracting to: {EXTRACT_DIR}")
    with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
        zip_ref.extractall(EXTRACT_DIR)
    print("  Extraction complete!")
    
    # Step 3: Organize
    if os.path.exists(FINAL_DIR):
        shutil.rmtree(FINAL_DIR)
    
    print("\nOrganizing dataset into train/val splits...")
    count = organize_dataset(EXTRACT_DIR, FINAL_DIR)
    
    if count > 0:
        print("\n" + "=" * 60)
        print("  Dataset ready!")
        print(f"  Location: {FINAL_DIR}")
        print("=" * 60)
    else:
        print("\nERROR: No images were organized. Please check the dataset structure.")
        sys.exit(1)

if __name__ == "__main__":
    main()
