#!/usr/bin/env python3

from PIL import Image, ImageDraw

# Create a green money background (rich green color)
# Using a vibrant money green: #2ECC71 or similar
GREEN_BACKGROUND = (46, 204, 113)  # Nice money green
ICON_SIZE = 1024

# Create the background
icon = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), color=GREEN_BACKGROUND)

# Open the LeadLoq logo
try:
    logo = Image.open('assets/images/LeadLoq-logo.png')
    
    # Convert logo to RGBA if not already
    if logo.mode != 'RGBA':
        logo = logo.convert('RGBA')
    
    # For accessibility, we'll use white version of the logo
    # Since the original is black, we'll invert it
    pixels = logo.load()
    width, height = logo.size
    
    # Create a new image for the white logo
    white_logo = Image.new('RGBA', (width, height), (255, 255, 255, 0))
    white_pixels = white_logo.load()
    
    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            # If pixel is black (or dark), make it white
            if r < 128 and g < 128 and b < 128 and a > 0:
                white_pixels[x, y] = (255, 255, 255, a)
            else:
                white_pixels[x, y] = (255, 255, 255, 0)
    
    # Calculate size for logo (about 60% of icon size)
    logo_size = int(ICON_SIZE * 0.6)
    white_logo = white_logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    
    # Calculate position to center the logo
    x_pos = (ICON_SIZE - logo_size) // 2
    y_pos = (ICON_SIZE - logo_size) // 2
    
    # Paste the white logo onto the green background
    icon.paste(white_logo, (x_pos, y_pos), white_logo)
    
    # Save the icon
    icon.save('assets/images/app_icon.png', 'PNG')
    print("App icon created successfully at assets/images/app_icon.png")
    
except FileNotFoundError:
    print("LeadLoq-logo.png not found in assets/images/")
except Exception as e:
    print(f"Error creating icon: {e}")