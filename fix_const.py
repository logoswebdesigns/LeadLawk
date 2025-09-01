import re
import sys

def fix_const_constructors(content):
    """Add const to constructors where appropriate"""
    patterns = [
        # Fix Text('...') to const Text('...')
        (r'(\s+)Text\(', r'\1const Text('),
        # Fix SizedBox(...) to const SizedBox(...)
        (r'(\s+)SizedBox\(', r'\1const SizedBox('),
        # Fix Icon(...) to const Icon(...)
        (r'(\s+)Icon\(', r'\1const Icon('),
        # Fix EdgeInsets to const EdgeInsets
        (r'(\s+)EdgeInsets\.(all|symmetric|only)\(', r'\1const EdgeInsets.\2('),
        # Fix Spacer() to const Spacer()
        (r'(\s+)Spacer\(\)', r'\1const Spacer()'),
    ]
    
    new_content = content
    for pattern, replacement in patterns:
        new_content = re.sub(pattern, replacement, new_content)
    
    # Remove duplicate const keywords
    new_content = re.sub(r'const const ', 'const ', new_content)
    
    return new_content

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_const.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    new_content = fix_const_constructors(content)
    
    if content != new_content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Fixed {file_path}")
    else:
        print(f"No changes needed in {file_path}")
