#!/usr/bin/env python3
import os
import re

def remove_const_from_widgets_with_expressions(content):
    """Remove const from widgets that have non-const expressions"""
    
    # Pattern to find const Icon/Text/Container/SizedBox with expressions
    patterns = [
        # Icon with ternary or method calls
        (r'const Icon\([^)]*\?[^)]*:[^)]*\)', lambda m: m.group(0).replace('const ', '')),
        (r'const Icon\([^)]*\.withValues[^)]*\)', lambda m: m.group(0).replace('const ', '')),
        
        # Text with interpolation
        (r"const Text\([^)]*\$[^)]*\)", lambda m: m.group(0).replace('const ', '')),
        
        # Any widget with withValues method
        (r'const (\w+)\([^)]*\.withValues[^)]*\)', lambda m: m.group(0).replace('const ', '')),
        
        # Any widget with ternary operator
        (r'const (\w+)\([^)]*\?[^)]*:[^)]*\)', lambda m: m.group(0).replace('const ', '')),
        
        # Remove const from widgets with variable references
        (r'const Icon\(\s*\n?\s*[^I][^c][^o][^n][^s][^.][^)]*\)', lambda m: m.group(0).replace('const ', '')),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
    
    # More specific fixes
    content = re.sub(r'const Icon\(\s*CupertinoIcons\.[^,)]*,\s*size:[^,)]*,\s*color:\s*[^I)][^)]*\)',
                     lambda m: m.group(0).replace('const ', '') if '?' in m.group(0) or 'withValues' in m.group(0) else m.group(0),
                     content, flags=re.MULTILINE | re.DOTALL)
    
    return content

def process_file(filepath):
    """Process a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        content = remove_const_from_widgets_with_expressions(content)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Remove all invalid const from all Dart files"""
    fixed_count = 0
    
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()