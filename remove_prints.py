import re
import sys

def remove_print_statements(content):
    """Remove or comment out print statements in production code"""
    # Pattern to match print statements
    pattern = r'^(\s*)print\((.*?)\);?$'
    
    # Replace with commented version for debugging purposes
    replacement = r'\1// DEBUG: print(\2);'
    
    return re.sub(pattern, replacement, content, flags=re.MULTILINE)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python remove_prints.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    new_content = remove_print_statements(content)
    
    if content != new_content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Fixed {file_path}")
    else:
        print(f"No changes needed in {file_path}")
