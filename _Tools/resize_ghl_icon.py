"""
Create GHL Refresh icon from uploaded image
Resize for toolbar use in SideKick_LB and SideKick_PS
"""
from PIL import Image
import os

def create_ghl_refresh_icons():
    # The user uploaded image should be saved first
    # For now, we'll use the generated one and create proper sizes
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    media_dir = r"c:\Stash\Media"
    lb_media = r"c:\Stash\SideKick_LB\media"
    
    # Check for source image - user should save their uploaded image here
    source_paths = [
        os.path.join(script_dir, "ghl_refresh_source.png"),
        r"c:\Stash\Media\Icon_GHL_Refresh.png",
        os.path.join(media_dir, "Icon_GHL_Refresh.png"),
    ]
    
    source_img = None
    for path in source_paths:
        if os.path.exists(path):
            source_img = Image.open(path).convert('RGBA')
            print(f"Loaded source: {path}")
            break
    
    if source_img is None:
        print("ERROR: No source image found!")
        print("Please save your GHL Refresh icon as:")
        print(f"  {source_paths[0]}")
        return
    
    # Output sizes for toolbar icons
    sizes = {
        "Icon GHL Refresh.png": 40,      # LB toolbar standard size
        "Icon_GHL_Refresh_32.png": 32,   # Small
        "Icon_GHL_Refresh_48.png": 48,   # Medium  
        "Icon_GHL_Refresh_64.png": 64,   # Large
        "Icon_GHL_Refresh.png": 128,     # Full size
    }
    
    # Save to Media folder
    print(f"\nSaving to: {media_dir}")
    os.makedirs(media_dir, exist_ok=True)
    for filename, size in sizes.items():
        output_path = os.path.join(media_dir, filename)
        resized = source_img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_path, 'PNG')
        print(f"  {filename} ({size}x{size})")
    
    # Copy toolbar icon to SideKick_LB media
    if os.path.exists(lb_media):
        print(f"\nSaving to: {lb_media}")
        lb_icon = os.path.join(lb_media, "Icon GHL Refresh.png")
        resized = source_img.resize((40, 40), Image.Resampling.LANCZOS)
        resized.save(lb_icon, 'PNG')
        print(f"  Icon GHL Refresh.png (40x40)")
    
    print("\nDone!")

if __name__ == "__main__":
    create_ghl_refresh_icons()
