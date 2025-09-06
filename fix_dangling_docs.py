#!/usr/bin/env python3
"""Fix dangling library doc comments in Dart files."""

import os
import re

def fix_dangling_docs(file_path):
    """Fix dangling doc comments in a file."""
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    if not lines:
        return False
    
    # Check if first non-empty lines are doc comments
    modified = False
    new_lines = []
    in_initial_docs = True
    
    for i, line in enumerate(lines):
        # If we're at the start and see /// comments before any code
        if in_initial_docs and line.startswith('///'):
            # Convert to regular comment
            new_lines.append(line.replace('///', '//', 1))
            modified = True
        else:
            # Once we hit non-doc content, stop converting
            if line.strip() and not line.startswith('///'):
                in_initial_docs = False
            new_lines.append(line)
    
    if modified:
        with open(file_path, 'w') as f:
            f.writelines(new_lines)
    
    return modified

def main():
    lib_dir = '/Users/jacobanderson/Documents/GitHub/LeadLawk/lib'
    fixed_count = 0
    
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                if fix_dangling_docs(file_path):
                    fixed_count += 1
                    print(f"Fixed: {file_path}")
    
    print(f"\nFixed {fixed_count} files with dangling doc comments")

if __name__ == '__main__':
    main()