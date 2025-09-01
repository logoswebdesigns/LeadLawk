import re
import sys

def fix_withopacity(content):
    """Replace withOpacity(value) with withValues(opacity: value)"""
    # Pattern to match .withOpacity(value)
    pattern = r'\.withOpacity\s*\(\s*([\d.]+|[a-zA-Z_][\w.]*(?:\([^)]*\))?)\s*\)'
    replacement = r'.withValues(opacity: \1)'
    
    return re.sub(pattern, replacement, content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_opacity.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    new_content = fix_withopacity(content)
    
    if content != new_content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Fixed {file_path}")
    else:
        print(f"No changes needed in {file_path}")
