import os
import json
import urllib.request
import urllib.error

def get_api_key():
    if os.path.exists(".env"):
        with open(".env", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("GEMINI_API_KEY="):
                    return line.split("=", 1)[1].strip()
    return ""

def test_model(api_key, version, model):
    url = f"https://generativelanguage.googleapis.com/{version}/models/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": "Hello"}]}]
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as res:
            res_data = json.loads(res.read().decode("utf-8"))
            print(f"SUCCESS: version={version}, model={model}")
            return True
    except urllib.error.HTTPError as e:
        print(f"FAILED: version={version}, model={model}. HTTP Error {e.code}: {e.read().decode('utf-8').strip()}")
        return False
    except Exception as e:
        print(f"FAILED: version={version}, model={model}. Error: {e}")
        return False

def main():
    api_key = get_api_key()
    if not api_key:
        print("API Key not found.")
        return
    
    # Try different models and versions
    test_model(api_key, "v1", "gemini-1.5-flash")
    test_model(api_key, "v1beta", "gemini-1.5-flash-latest")
    test_model(api_key, "v1", "gemini-pro")
    
    # Let's also try ListModels to see what's available
    print("\nListing models:")
    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
    try:
        with urllib.request.urlopen(url) as res:
            data = json.loads(res.read().decode("utf-8"))
            for m in data.get("models", []):
                print(f"- {m.get('name')} (supported methods: {m.get('supportedGenerationMethods')})")
    except Exception as e:
        print(f"Failed to list models: {e}")

if __name__ == "__main__":
    main()
