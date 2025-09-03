#!/usr/bin/env python3
import sys
import os

# Create an SVG with green background and white logo
svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">
  <!-- Green money background -->
  <rect width="1024" height="1024" fill="#2ECC71"/>
  
  <!-- White LeadLoq logo centered -->
  <g transform="translate(512, 350)">
    <!-- Lock shape -->
    <path d="M -80,-120 C -80,-180 -40,-220 0,-220 C 40,-220 80,-180 80,-120 L 80,-40 L 60,-40 L 60,-120 C 60,-160 30,-190 0,-190 C -30,-190 -60,-160 -60,-120 L -60,-40 L -80,-40 Z" fill="white"/>
    
    <!-- Shield with pin -->
    <path d="M -100,0 C -100,-20 -80,-40 -60,-40 L 60,-40 C 80,-40 100,-20 100,0 L 100,100 C 100,180 0,220 0,220 C 0,220 -100,180 -100,100 Z" fill="white"/>
    
    <!-- Location pin in shield -->
    <circle cx="0" cy="40" r="25" fill="#2ECC71"/>
    <path d="M 0,20 C -15,20 -25,30 -25,45 C -25,70 0,95 0,95 C 0,95 25,70 25,45 C 25,30 15,20 0,20 Z" fill="#2ECC71"/>
    <path d="M 0,120 L 0,180" stroke="#2ECC71" stroke-width="15"/>
  </g>
  
  <!-- LeadLoq text -->
  <text x="512" y="680" font-family="Arial, sans-serif" font-size="140" font-weight="bold" text-anchor="middle" fill="white">LeadLoq</text>
</svg>'''

# Save the SVG
with open('assets/images/app_icon.svg', 'w') as f:
    f.write(svg_content)

print("SVG icon created at assets/images/app_icon.svg")

# Create a simple PNG version too (1024x1024 green square for now)
try:
    from PIL import Image
    img = Image.new('RGBA', (1024, 1024), color=(46, 204, 113, 255))
    img.save('assets/images/app_icon.png')
    print("PNG icon created at assets/images/app_icon.png")
except ImportError:
    print("PIL not available, creating placeholder PNG...")
    # Create a minimal PNG with pure Python
    import struct
    import zlib
    
    def create_png(width, height, rgb):
        def output_chunk(out, chunk_type, data):
            out.write(struct.pack('>I', len(data)))
            out.write(chunk_type)
            out.write(data)
            crc = zlib.crc32(chunk_type + data)
            out.write(struct.pack('>I', crc))
        
        with open('assets/images/app_icon.png', 'wb') as out:
            # PNG signature
            out.write(b'\x89PNG\r\n\x1a\n')
            
            # IHDR chunk
            ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
            output_chunk(out, b'IHDR', ihdr_data)
            
            # IDAT chunk (simplified - creates solid color)
            raw_data = b''
            for y in range(height):
                raw_data += b'\x00'  # filter type
                for x in range(width):
                    raw_data += struct.pack('BBB', rgb[0], rgb[1], rgb[2])
            
            compressed = zlib.compress(raw_data)
            output_chunk(out, b'IDAT', compressed)
            
            # IEND chunk
            output_chunk(out, b'IEND', b'')
    
    create_png(1024, 1024, (46, 204, 113))
    print("Minimal PNG icon created")