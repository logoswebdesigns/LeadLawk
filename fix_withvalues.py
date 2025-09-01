import re
import sys

def fix_withvalues(content):
    """Fix withValues usage - it should be withValues(alpha: value) not withValues(opacity: value)"""
    # Pattern to match .withValues(opacity: value)
    pattern = r'\.withValues\s*\(\s*opacity:\s*([\d.]+|[a-zA-Z_][\w.]*(?:\([^)]*\))?)\s*\)'
    replacement = r'.withOpacity(\1)'  # Revert back to withOpacity for now
    
    return re.sub(pattern, replacement, content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_withvalues.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    new_content = fix_withvalues(content)
    
    if content != new_content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Fixed {file_path}")
    else:
        print(f"No changes needed in {file_path}")
