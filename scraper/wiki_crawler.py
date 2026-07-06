import re
import os
import time
import subprocess
import json

CONTENT_MD = r"C:\Users\loivt\.gemini\antigravity-ide\brain\49c766dd-f76b-4422-8680-40eb3a980327\.system_generated\steps\2747\content.md"
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
BASE_URL = "https://minecraft.wiki"
IMAGE_DIR = "raw_data/images"

def setup():
    if not os.path.exists(IMAGE_DIR):
        os.makedirs(IMAGE_DIR)

def download_image_curl(url, filepath):
    try:
        cmd = ['curl.exe', '-A', USER_AGENT, '-s', url, '-o', filepath]
        subprocess.run(cmd, check=True)
        return True
    except:
        return False

def crawl_blocks(limit=10):
    print("Reading content.md...")
    with open(CONTENT_MD, "r", encoding="utf-8") as f:
        html = f.read()
        
    # Extract pattern: <img src="URL" ...> ... <a ... title="NAME">NAME</a>
    # We can use a simpler approach: find all <li> elements
    
    blocks_data = []
    count = 0
    
    # Split by <li>
    items = html.split("<li")
    for item in items:
        img_match = re.search(r'src="([^"]+)"', item)
        title_match = re.search(r'title="([^"]+)"', item)
        
        if img_match and title_match:
            img_url = img_match.group(1)
            name = title_match.group(1)
            
            # Filter out non-block images or layout images
            if "/images/thumb/" not in img_url or "Sprite" in name or "Category:" in name:
                continue
                
            if img_url.startswith("/"):
                img_url = BASE_URL + img_url
                
            # Clean url, remove thumbnail resize parameters if any
            # e.g. /images/thumb/Dirt_JE2_BE2.png/30px-Dirt_JE2_BE2.png?438ac -> /images/Dirt_JE2_BE2.png
            clean_url = img_url
            if "/thumb/" in clean_url:
                parts = clean_url.split("/")
                # The original image is usually the directory name of the thumb
                # /images/thumb/Dirt.png/30px-Dirt.png -> /images/Dirt.png
                original_img = parts[-2]
                clean_url = BASE_URL + "/images/" + original_img
                
            safe_name = "".join([c for c in name if c.isalpha() or c.isdigit() or c==' ']).rstrip().replace(" ", "_").lower()
            
            if any(b["id"] == safe_name for b in blocks_data):
                continue
                
            print(f"[{count+1}] Found block: {name} (ID: {safe_name})")
            print(f"    Image URL: {clean_url}")
            
            ext = clean_url.split(".")[-1].split("?")[0]
            if ext not in ["png", "webp", "gif"]:
                ext = "png"
                
            filename = f"{safe_name}.{ext}"
            filepath = os.path.join(IMAGE_DIR, filename)
            
            if download_image_curl(clean_url, filepath):
                print(f"    Saved to: {filepath}")
            else:
                print(f"    Error downloading image. Trying thumb URL...")
                if download_image_curl(img_url, filepath):
                    print(f"    Saved thumb to: {filepath}")
                else:
                    print("    Failed thumb too.")
                    continue
                
            blocks_data.append({
                "id": safe_name,
                "display_name": name,
                "texture": filename
            })
            
            count += 1
            if count >= limit:
                break
                
            time.sleep(0.2)
            
    with open("raw_data/extracted_blocks.json", "w", encoding="utf-8") as f:
        json.dump({"blocks": blocks_data}, f, ensure_ascii=False, indent=4)
    print(f"\nSaved {count} blocks to raw_data/extracted_blocks.json")

if __name__ == "__main__":
    setup()
    crawl_blocks(10)
