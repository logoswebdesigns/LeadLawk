#!/usr/bin/env python3
import os
import re

def fix_mangled_method_names(content):
    """Fix method names that got mangled with const"""
    # Fix patterns like "_getSomethingconst Icon" to "_getSomethingIcon"
    content = re.sub(r'_get(\w+)const\s+\w+', r'_get\1Icon', content)
    content = re.sub(r'_get(\w+)const\s+', r'_get\1', content)
    
    return content

def remove_invalid_const(content):
    """Remove const from places where it can't be used"""
    
    # Remove const when using variables in constructors
    patterns = [
        # Duration with variable
        (r'const Duration\(seconds: (\w+)\)', r'Duration(seconds: \1)'),
        (r'const Duration\(milliseconds: (\w+[^)]*)\)', r'Duration(milliseconds: \1)'),
        (r'const Duration\(minutes: (\w+)\)', r'Duration(minutes: \1)'),
        
        # SizedBox with variables
        (r'const SizedBox\(\s*width: (\w+)', r'SizedBox(\n        width: \1'),
        (r'const SizedBox\(\s*height: (\w+)', r'SizedBox(\n        height: \1'),
        
        # EdgeInsets with variables  
        (r'const EdgeInsets\.symmetric\(([^)]*\w+[^)]*)\)', r'EdgeInsets.symmetric(\1)'),
        (r'const EdgeInsets\.all\((\w+)\)', r'EdgeInsets.all(\1)'),
        
        # Icon with variables
        (r'const Icon\((\w+)[^)]*\)', r'Icon(\1)'),
        
        # Remove const from method calls
        (r'const (\w+)\.(\w+)\(', r'\1.\2('),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_file(filepath):
    """Fix a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Apply fixes
        content = fix_mangled_method_names(content)
        content = remove_invalid_const(content)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all Dart files"""
    lib_dir = 'lib'
    test_dir = 'test'
    
    fixed_count = 0
    
    for directory in [lib_dir, test_dir]:
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.endswith('.dart'):
                    filepath = os.path.join(root, file)
                    if fix_file(filepath):
                        print(f"Fixed: {filepath}")
                        fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()