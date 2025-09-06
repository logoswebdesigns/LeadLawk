#!/usr/bin/env python3
import os
import re

def fix_with_opacity(content):
    """Fix withOpacity deprecation by replacing with withValues"""
    # Pattern to match .withOpacity(value)
    pattern = r'\.withOpacity\(([^)]+)\)'
    replacement = r'.withValues(alpha: \1)'
    
    updated_content = re.sub(pattern, replacement, content)
    return updated_content

def fix_surface_variant(content):
    """Fix surfaceVariant deprecation by replacing with surfaceContainerHighest"""
    updated_content = content.replace('surfaceVariant', 'surfaceContainerHighest')
    return updated_content

def fix_print_statements(content):
    """Replace print statements with proper logging"""
    # Only in Dart files, replace print with debugPrint
    if content.find('print(') != -1:
        # Check if debugPrint is imported
        if 'import \'package:flutter/foundation.dart\'' not in content:
            # Add import at the top after other imports
            lines = content.split('\n')
            import_index = 0
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    import_index = i + 1
            if import_index > 0:
                lines.insert(import_index, "import 'package:flutter/foundation.dart';")
                content = '\n'.join(lines)
        
        # Replace print with debugPrint
        content = re.sub(r'\bprint\(', 'debugPrint(', content)
    
    return content

def process_file(filepath):
    """Process a single file to fix deprecated members"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Apply fixes
        content = fix_with_opacity(content)
        content = fix_surface_variant(content)
        
        # Only fix print in Dart files
        if filepath.endswith('.dart'):
            content = fix_print_statements(content)
        
        # Write back if changed
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix deprecated members in all Dart files"""
    lib_dir = 'lib'
    test_dir = 'test'
    
    fixed_count = 0
    
    # Process lib directory
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    # Process test directory
    for root, dirs, files in os.walk(test_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()