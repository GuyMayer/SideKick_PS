"""
Create GHL + Refresh composite icon for SideKick_PS toolbar
Combines the GHL (Go High Level) logo with a refresh symbol overlay
"""
from PIL import Image, ImageDraw, ImageFont
import os
import sys

def create_refresh_icon(size=128, bg_color=(30, 30, 30, 255), arrow_color=(255, 255, 255, 255)):
    """Create a circular refresh/sync icon"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw circle background
    circle_margin = size // 10
    draw.ellipse([circle_margin, circle_margin, size - circle_margin, size - circle_margin], 
                 fill=bg_color)
    
    # Draw refresh symbol - two curved arrows
    center = size // 2
    radius = size // 3
    arc_width = max(4, size // 12)
    arrow_size = max(6, size // 12)
    
    # Top arc (right side)
    draw.arc([center - radius, center - radius, center + radius, center + radius], 
             200, 340, fill=arrow_color, width=arc_width)
    
    # Bottom arc (left side)
    draw.arc([center - radius, center - radius, center + radius, center + radius], 
             20, 160, fill=arrow_color, width=arc_width)
    
    # Arrow heads as triangles
    import math
    
    # Top-right arrow (pointing clockwise)
    angle1 = math.radians(340)
    ax1 = center + radius * math.cos(angle1)
    ay1 = center + radius * math.sin(angle1)
    draw.polygon([
        (ax1 + arrow_size, ay1 - arrow_size//2),
        (ax1 - arrow_size//2, ay1 - arrow_size),
        (ax1 - arrow_size//2, ay1 + arrow_size//2)
    ], fill=arrow_color)
    
    # Bottom-left arrow (pointing counter-clockwise)
    angle2 = math.radians(160)
    ax2 = center + radius * math.cos(angle2)
    ay2 = center + radius * math.sin(angle2)
    draw.polygon([
        (ax2 - arrow_size, ay2 + arrow_size//2),
        (ax2 + arrow_size//2, ay2 + arrow_size),
        (ax2 + arrow_size//2, ay2 - arrow_size//2)
    ], fill=arrow_color)
    
    return img

def create_ghl_base_icon(size=128):
    """Create GHL-style icon (three upward arrows matching official branding)"""
    img = Image.new('RGBA', (size, size), (255, 255, 255, 255))  # White background
    draw = ImageDraw.Draw(img)
    
    # Official GHL colors (yellow, blue, green arrows)
    yellow = (251, 188, 5, 255)      # #FBBC05 - left arrow
    blue = (52, 168, 83, 255)        # Actually the middle is blue: #4285F4
    green = (52, 168, 83, 255)       # #34A853 - right arrow
    
    # Corrected colors from the actual logo
    yellow = (251, 188, 5, 255)      # Yellow - left
    blue = (66, 133, 244, 255)       # Blue - middle  
    green = (52, 168, 83, 255)       # Green - right
    
    # Arrow dimensions proportional to size
    margin = size * 0.12
    arrow_width = size * 0.18
    arrow_gap = size * 0.06
    
    # Calculate positions - 3 arrows centered
    total_arrows_width = arrow_width * 3 + arrow_gap * 2
    start_x = (size - total_arrows_width) / 2
    
    # Arrow heights (yellow shortest, blue tallest, green medium)
    arrow_configs = [
        (yellow, 0.35, 0.85),   # Yellow: top at 35%, bottom at 85%
        (blue, 0.12, 0.85),    # Blue: top at 12%, bottom at 85%  
        (green, 0.22, 0.85),   # Green: top at 22%, bottom at 85%
    ]
    
    for i, (color, top_pct, bottom_pct) in enumerate(arrow_configs):
        x = start_x + i * (arrow_width + arrow_gap)
        
        # Arrow dimensions
        arrow_top = size * top_pct
        arrow_bottom = size * bottom_pct
        head_height = arrow_width * 0.9
        body_top = arrow_top + head_height
        
        # Arrow head (triangle pointing up)
        center_x = x + arrow_width / 2
        head_width = arrow_width * 1.4
        draw.polygon([
            (center_x, arrow_top),                    # Top point
            (center_x - head_width / 2, body_top),   # Bottom left
            (center_x + head_width / 2, body_top)    # Bottom right
        ], fill=color)
        
        # Arrow body (rectangle)
        body_width = arrow_width * 0.6
        body_x = center_x - body_width / 2
        draw.rectangle([body_x, body_top, body_x + body_width, arrow_bottom], fill=color)
        
        # Folded corner effect (darker shade on right side of head)
        dark_color = tuple(max(0, int(c * 0.7)) for c in color[:3]) + (255,)
        fold_width = head_width * 0.25
        draw.polygon([
            (center_x + head_width / 2, body_top),           # Right corner of head
            (center_x + head_width / 2 - fold_width, body_top),  # Left of fold
            (center_x, arrow_top + head_height * 0.5),       # Up toward center
        ], fill=dark_color)
    
    return img

def composite_ghl_refresh(ghl_image_path=None, output_path="Icon_GHL_Refresh.png", size=128):
    """Create composite icon with large refresh circle and GHL arrows in center"""
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw large refresh circle background
    import math
    
    circle_margin = size * 0.02
    circle_color = (255, 255, 255, 255)  # White background
    arrow_color = (0, 120, 212, 255)  # Blue refresh arrows
    
    # Main circle
    draw.ellipse([circle_margin, circle_margin, size - circle_margin, size - circle_margin], 
                 fill=circle_color)
    
    # Draw refresh arrows around the edge
    center = size / 2
    radius = size * 0.42
    arc_width = max(6, int(size * 0.08))
    arrow_size = max(8, int(size * 0.12))
    
    # Top arc
    draw.arc([center - radius, center - radius, center + radius, center + radius], 
             210, 330, fill=arrow_color, width=arc_width)
    
    # Bottom arc
    draw.arc([center - radius, center - radius, center + radius, center + radius], 
             30, 150, fill=arrow_color, width=arc_width)
    
    # Arrow heads
    # Top-right arrow
    angle1 = math.radians(330)
    ax1 = center + radius * math.cos(angle1)
    ay1 = center + radius * math.sin(angle1)
    draw.polygon([
        (ax1 + arrow_size * 0.9, ay1 - arrow_size * 0.3),
        (ax1 - arrow_size * 0.3, ay1 - arrow_size * 0.9),
        (ax1 - arrow_size * 0.5, ay1 + arrow_size * 0.5)
    ], fill=arrow_color)
    
    # Bottom-left arrow
    angle2 = math.radians(150)
    ax2 = center + radius * math.cos(angle2)
    ay2 = center + radius * math.sin(angle2)
    draw.polygon([
        (ax2 - arrow_size * 0.9, ay2 + arrow_size * 0.3),
        (ax2 + arrow_size * 0.3, ay2 + arrow_size * 0.9),
        (ax2 + arrow_size * 0.5, ay2 - arrow_size * 0.5)
    ], fill=arrow_color)
    
    # Now draw GHL arrows in the center (smaller)
    ghl_size = int(size * 0.55)  # GHL arrows take 55% of icon
    
    if ghl_image_path and os.path.exists(ghl_image_path):
        print(f"Loading GHL image from: {ghl_image_path}")
        ghl_img = Image.open(ghl_image_path).convert('RGBA')
        ghl_img = ghl_img.resize((ghl_size, ghl_size), Image.Resampling.LANCZOS)
    else:
        print("Creating GHL-style arrows...")
        ghl_img = create_ghl_base_icon(ghl_size)
    
    # Center the GHL arrows
    ghl_x = (size - ghl_size) // 2
    ghl_y = (size - ghl_size) // 2
    
    # Paste GHL arrows in center
    img.paste(ghl_img, (ghl_x, ghl_y), ghl_img)
    
    # Save PNG
    img.save(output_path, 'PNG')
    print(f"Saved: {output_path}")
    
    # Also save ICO version with multiple sizes
    ico_path = output_path.replace('.png', '.ico')
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128)]
    icons = []
    for s in sizes:
        icon = img.resize(s, Image.Resampling.LANCZOS)
        icons.append(icon)
    
    # Save as ICO
    icons[0].save(ico_path, format='ICO', sizes=[(i.width, i.height) for i in icons], 
                  append_images=icons[1:])
    print(f"Saved: {ico_path}")
    
    return img

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    media_dir = os.path.join(script_dir, "..", "Media")
    
    # Check for existing GHL image in common locations
    possible_paths = [
        os.path.join(script_dir, "ghl_logo.png"),
        os.path.join(script_dir, "ghl_icon.png"),
        os.path.join(media_dir, "Icon_GHL.png"),
    ]
    
    ghl_path = None
    for path in possible_paths:
        if os.path.exists(path):
            ghl_path = path
            break
    
    # Allow command line argument for image path
    if len(sys.argv) > 1:
        ghl_path = sys.argv[1]
    
    # Output to Media folder
    output_path = os.path.join(media_dir, "Icon_GHL_Refresh.png")
    
    # Create the composite icon
    composite_ghl_refresh(ghl_path, output_path, size=128)
    
    print("\nIcon created successfully!")
    print(f"PNG: {output_path}")
    print(f"ICO: {output_path.replace('.png', '.ico')}")
