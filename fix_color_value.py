import re
import sys

def fix_color_value(content):
    """Replace deprecated .value with .toARGB32"""
    # Pattern to match color.value
    pattern = r'(\w+)\.value\b'
    
    # Check if it's likely a color reference (simple heuristic)
    def replacement(match):
        var_name = match.group(1)
        # Common color variable names
        if any(word in var_name.lower() for word in ['color', 'Color', 'theme', 'Theme', 'AppTheme']):
            return f'{var_name}.toARGB32'
        return match.group(0)  # Keep unchanged if not likely a color
    
    return re.sub(pattern, replacement, content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_color_value.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    new_content = fix_color_value(content)
    
    if content != new_content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Fixed {file_path}")
    else:
        print(f"No changes needed in {file_path}")
