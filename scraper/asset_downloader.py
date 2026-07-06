import json
import os
import subprocess
import time

# Minecraft assets repository (InventivetalentDev mirror via JSDelivr CDN)
GITHUB_BASE_URL = "https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.20.1/assets/minecraft/textures/block/"
IMAGE_DIR = "raw_data/images"

def setup():
    if not os.path.exists(IMAGE_DIR):
        os.makedirs(IMAGE_DIR)

def download_image_curl(url, filepath):
    try:
        cmd = ['curl.exe', '-s', '-o', filepath, url]
        subprocess.run(cmd, check=True)
        # Verify size
        if os.path.exists(filepath) and os.path.getsize(filepath) < 50:
            content = open(filepath, "r").read()
            if "404" in content or "Not Found" in content:
                os.remove(filepath)
                return False
        return True
    except:
        return False

def main():
    setup()
    print("Reading extracted_blocks.json...")
    with open("raw_data/extracted_blocks.json", "r", encoding="utf-8") as f:
        data = json.load(f)
        
    for block in data.get("blocks", []):
        texture = block.get("texture")
        if not texture:
            continue
            
        filepath = os.path.join(IMAGE_DIR, texture)
        print(f"Downloading {texture}...")
        
        # Try block first
        url_block = f"https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.20.1/assets/minecraft/textures/block/{texture}"
        if download_image_curl(url_block, filepath):
            print(f"  -> Saved (Block) to {filepath}")
            continue
            
        # Try item
        url_item = f"https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.20.1/assets/minecraft/textures/item/{texture}"
        if download_image_curl(url_item, filepath):
            print(f"  -> Saved (Item) to {filepath}")
        else:
            print(f"  -> Failed to download {texture}")
            
        time.sleep(0.1)
        
    print("Download complete!")

if __name__ == "__main__":
    main()
