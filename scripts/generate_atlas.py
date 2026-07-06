import os
import json
from PIL import Image

ICONS_DIR = "../assets/textures/icons"
ATLAS_PATH = "../assets/textures/atlas.png"
UV_MAP_PATH = "../assets/textures/atlas_uv.json"

TILE_SIZE = 16
ATLAS_WIDTH = 1024
ATLAS_HEIGHT = 1024

DIRS_TO_SCAN = [
    "../assets/textures/blocks",
    "../assets/textures/items"
]

def generate():
    atlas = Image.new("RGBA", (ATLAS_WIDTH, ATLAS_HEIGHT), (0, 0, 0, 0))
    
    files_with_paths = []
    for d in DIRS_TO_SCAN:
        if os.path.exists(d):
            for f in os.listdir(d):
                if f.endswith(".png"):
                    files_with_paths.append((f, os.path.join(d, f)))
    
    # Sort by filename
    files_with_paths.sort(key=lambda x: x[0])
    
    uv_map = {}
    
    cols = ATLAS_WIDTH // TILE_SIZE
    rows = ATLAS_HEIGHT // TILE_SIZE
    
    current_col = 0
    current_row = 0
    
    for filename, filepath in files_with_paths:
        try:
            img = Image.open(filepath).convert("RGBA")
            
            # Cắt lấy frame đầu tiên nếu là ảnh động (ví dụ 16x512)
            if img.width >= TILE_SIZE and img.height >= TILE_SIZE:
                img = img.crop((0, 0, TILE_SIZE, TILE_SIZE))
            else:
                # Bỏ qua nếu ảnh quá nhỏ
                continue
                
            x = current_col * TILE_SIZE
            y = current_row * TILE_SIZE
            
            atlas.paste(img, (x, y))
            
            # Calculate UVs (u_min, v_min, u_max, v_max)
            u_min = x / ATLAS_WIDTH
            v_min = y / ATLAS_HEIGHT
            u_max = (x + TILE_SIZE) / ATLAS_WIDTH
            v_max = (y + TILE_SIZE) / ATLAS_HEIGHT
            
            name_without_ext = os.path.splitext(filename)[0]
            uv_map[name_without_ext] = {
                "u_min": u_min,
                "v_min": v_min,
                "u_max": u_max,
                "v_max": v_max
            }
            
            current_col += 1
            if current_col >= cols:
                current_col = 0
                current_row += 1
                if current_row >= rows:
                    print("Warning: Atlas is full!")
                    break
        except Exception as e:
            print(f"Failed to process {filename}: {e}")
            
    atlas.save(ATLAS_PATH)
    with open(UV_MAP_PATH, "w", encoding="utf-8") as f:
        json.dump(uv_map, f, indent=4)
        
    print(f"Atlas generated with {len(uv_map)} textures at {ATLAS_PATH}")

if __name__ == "__main__":
    generate()
