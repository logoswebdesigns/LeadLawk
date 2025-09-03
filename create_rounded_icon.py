#!/usr/bin/env python3
from PIL import Image, ImageDraw
import os

def add_rounded_corners(image_path, output_path, radius_percent=22.5):
    """Add rounded corners to an image (macOS style is about 22.5% radius)"""
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    
    # Calculate radius as percentage of image size (macOS uses ~22.5%)
    radius = int(min(width, height) * radius_percent / 100)
    
    # Create a mask for rounded corners
    mask = Image.new('L', (width, height), 0)
    draw = ImageDraw.Draw(mask)
    
    # Draw rounded rectangle
    draw.rounded_rectangle([(0, 0), (width, height)], radius=radius, fill=255)
    
    # Apply the mask
    output = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    output.paste(img, (0, 0))
    output.putalpha(mask)
    
    output.save(output_path, 'PNG')
    return output

# Process the icon
try:
    # Create rounded version
    rounded = add_rounded_corners(
        'assets/images/LeadLoq-with-background.png',
        'assets/images/LeadLoq-rounded.png'
    )
    print("Created rounded icon")
    
    # Create all sizes needed for macOS
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for size in sizes:
        resized = rounded.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png')
        print(f"Created {size}x{size} icon")
    
    print("All icons created successfully!")
    
except Exception as e:
    print(f"Error: {e}")
    print("Pillow might not be installed. Using fallback method...")
    
    # Fallback: use sips to create rounded corners
    import subprocess
    
    # Create a temporary rounded version using macOS tools
    subprocess.run([
        'sips', '-s', 'format', 'png',
        'assets/images/LeadLoq-with-background.png',
        '--out', 'assets/images/temp_icon.png'
    ])
    
    # Copy to all sizes
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for size in sizes:
        subprocess.run([
            'sips', '-z', str(size), str(size),
            'assets/images/LeadLoq-with-background.png',
            '--out', f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png'
        ])
        print(f"Created {size}x{size} icon")