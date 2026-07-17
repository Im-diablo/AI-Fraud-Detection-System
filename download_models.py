import os
import zipfile
import shutil
import re
from pathlib import Path
import requests

BASE_DIR = Path(__file__).parent
MODELS_DIR = BASE_DIR / "models"
ZIP_PATH = BASE_DIR / "MODELS.zip"
GOOGLE_DRIVE_FILE_ID = "1BNgF215iWN5GJoyP9BH2X_-gn2G0rrmW"

def is_models_ready() -> bool:
    # Check if critical model files exist and have non-zero size
    files = [
        MODELS_DIR / "xgboost_fraud.ubj",
        MODELS_DIR / "siamese_resnet18.pt",
        MODELS_DIR / "distilbert_fraud" / "model.safetensors"
    ]
    for f in files:
        if not f.exists() or f.stat().st_size == 0:
            return False
    return True

def download_file_from_google_drive(file_id, destination):
    print(f"Downloading models from Google Drive (ID: {file_id})...")
    url = "https://docs.google.com/uc?export=download"
    session = requests.Session()
    
    # Send request to docs.google.com
    response = session.get(url, params={'id': file_id}, stream=True)
    
    # Check if we hit the large file scan warning page
    if "Google Drive - Virus scan warning" in response.text:
        print("Bypassing Google Drive virus scan warning page...")
        
        # Extract action URL from the HTML form
        action_match = re.search(r'action="([^"]+)"', response.text)
        action_url = action_match.group(1) if action_match else "https://drive.usercontent.google.com/download"
        
        # Extract hidden input fields (confirm token, uuid, id, etc.)
        inputs = re.findall(r'<input\s+type=["\']hidden["\']\s+name=["\']([^"\']+)["\']\s+value=["\']([^"\']+)["\']\s*/?>', response.text)
        params = {name: val for name, val in inputs}
        
        # Send second request to the action URL with the parsed parameters
        response = session.get(action_url, params=params, stream=True)
    
    total_downloaded = 0
    with open(destination, "wb") as f:
        for chunk in response.iter_content(chunk_size=1024 * 1024):  # 1MB chunks
            if chunk:
                f.write(chunk)
                total_downloaded += len(chunk)
                print(f"Downloaded {total_downloaded / (1024 * 1024):.1f} MB...", end="\r")
    print("\nDownload complete.")

def ensure_models_extracted():
    if is_models_ready():
        print("Models are already present and ready.")
        return

    print("Models not found or incomplete. Starting download...")
    MODELS_DIR.mkdir(exist_ok=True)
    
    try:
        download_file_from_google_drive(GOOGLE_DRIVE_FILE_ID, ZIP_PATH)
        print("Extracting MODELS.zip...")
        with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
            namelist = zip_ref.namelist()
            # If zip contains a parent "models/" directory, extract to BASE_DIR
            has_models_parent = any(name.startswith("models/") for name in namelist)
            
            extract_target = BASE_DIR if has_models_parent else MODELS_DIR
            zip_ref.extractall(extract_target)
            
        print("Extraction complete.")
    except Exception as e:
        print(f"Error during model setup: {e}")
        # Clean up models folder to avoid partial/corrupt states
        if MODELS_DIR.exists():
            shutil.rmtree(MODELS_DIR)
        raise e
    finally:
        # Clean up the zip file
        if ZIP_PATH.exists():
            os.remove(ZIP_PATH)
            print("Temporary zip file cleaned up.")

if __name__ == "__main__":
    ensure_models_extracted()
