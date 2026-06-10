import os
import json
import urllib.request
import urllib.parse
import urllib.error
import re

def get_api_key():
    if os.path.exists(".env"):
        with open(".env", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("GEMINI_API_KEY="):
                    return line.split("=", 1)[1].strip()
    return os.environ.get("GEMINI_API_KEY", "")

def call_gemini(api_key, prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
    payload = {
        "contents": [{
            "parts": [{
                "text": prompt
            }]
        }],
        "generationConfig": {
            "responseMimeType": "application/json"
        }
    }
    
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    
    try:
        with urllib.request.urlopen(req) as res:
            res_data = json.loads(res.read().decode("utf-8"))
            text = res_data["candidates"][0]["content"]["parts"][0]["text"]
            # Clean markdown code blocks
            text = text.replace("```json", "").replace("```", "").strip()
            return json.loads(text)
    except urllib.error.HTTPError as e:
        print(f"Gemini API HTTP Error {e.code}: {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Gemini API Error: {e}")
        return None

def main():
    api_key = get_api_key()
    if not api_key:
        print("Error: GEMINI_API_KEY not found in .env or environment.")
        return
        
    if not os.path.exists("assets/models/labelmap.txt"):
        print("Error: assets/models/labelmap.txt does not exist. Run generate_labels.py first.")
        return
        
    print("Reading class names from assets/models/labelmap.txt...")
    with open("assets/models/labelmap.txt", "r", encoding="utf-8") as f:
        classes = [line.strip() for line in f if line.strip()]
        
    print(f"Loaded {len(classes)} classes.")
    
    # Batch translation (100 classes per batch)
    translated_map = {}
    batch_size = 100
    
    for i in range(0, len(classes), batch_size):
        batch = classes[i:i+batch_size]
        print(f"Translating batch {i // batch_size + 1} ({i} to {i + len(batch)})...")
        
        prompt = (
            "You are a translation assistant. Translate the following list of English object names/classes "
            "into warm, natural, singular Turkish object names (lowercase, no explanations, no descriptions, just the direct name). "
            "Return ONLY a JSON dictionary where keys are the original English words exactly as given (case-sensitive) "
            "and values are the Turkish translations. Here is the list:\n" + json.dumps(batch)
        )
        
        translations = call_gemini(api_key, prompt)
        if translations:
            translated_map.update(translations)
        else:
            print("Failed to translate batch, falling back to original English names.")
            for item in batch:
                translated_map[item] = item.lower()
                
    # Lowercase keys for mapping lookup consistency
    final_map = {k.lower(): v.lower() for k, v in translated_map.items()}
    
    print("Generating Dart Map code...")
    dart_map_str = "const Map<String, String> cocoLabelsTr = {\n"
    for k, v in sorted(final_map.items()):
        # Escape single quotes
        k_escaped = k.replace("'", "\\'")
        v_escaped = v.replace("'", "\\'")
        dart_map_str += f"  '{k_escaped}': '{v_escaped}',\n"
    dart_map_str += "};"
    
    # Read detection_result.dart
    dart_file_path = "lib/domain/models/detection_result.dart"
    if not os.path.exists(dart_file_path):
        print(f"Error: {dart_file_path} not found.")
        return
        
    with open(dart_file_path, "r", encoding="utf-8") as f:
        dart_content = f.read()
        
    # Replace the cocoLabelsTr map in the dart file
    pattern = re.compile(r"const Map<String, String> cocoLabelsTr = \{.*?\};", re.DOTALL)
    new_dart_content = pattern.sub(dart_map_str, dart_content)
    
    with open(dart_file_path, "w", encoding="utf-8") as f:
        f.write(new_dart_content)
        
    print(f"Successfully updated {dart_file_path} with 600 Turkish translations!")

if __name__ == "__main__":
    main()
