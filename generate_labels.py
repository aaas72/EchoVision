import urllib.request
import yaml

def main():
    print("Fetching open-images-v7.yaml from GitHub...")
    url = "https://raw.githubusercontent.com/ultralytics/ultralytics/main/ultralytics/cfg/datasets/open-images-v7.yaml"
    
    try:
        response = urllib.request.urlopen(url)
        yaml_content = response.read()
        
        print("Parsing YAML...")
        data = yaml.safe_load(yaml_content)
        names = data['names']
        
        print("Writing to assets/models/labelmap.txt...")
        with open("assets/models/labelmap.txt", "w", encoding="utf-8") as f:
            for i in range(600):
                name = names.get(i, f"class_{i}")
                f.write(name + "\n")
        print("Successfully generated labelmap.txt with 600 classes!")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
