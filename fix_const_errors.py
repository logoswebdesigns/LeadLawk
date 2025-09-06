#!/usr/bin/env python3
import os
import re

def remove_invalid_const(content):
    """Remove const from invalid places"""
    
    # Remove const from Duration when it has non-const arguments
    content = re.sub(r'const Duration\(milliseconds: \w+\)', r'Duration(milliseconds: \1)', content)
    
    # Remove const from constructors that have variables
    patterns = [
        (r'const EdgeInsets\.all\((\w+)\)', r'EdgeInsets.all(\1)'),
        (r'const EdgeInsets\.symmetric\(([^)]*\w+[^)]*)\)', r'EdgeInsets.symmetric(\1)'),
        (r'const SizedBox\(([^)]*\w+[^)]*)\)', r'SizedBox(\1)'),
        (r'const Text\((\w+)\)', r'Text(\1)'),  # When using variables
        (r'const Icon\(([^)]*\w+[^)]*)\)', r'Icon(\1)'),
    ]
    
    for pattern, replacement in patterns:
        # Only remove const if the argument contains a variable (not a literal)
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_specific_files(files_with_errors):
    """Fix specific files with const errors"""
    for filepath in files_with_errors:
        if not os.path.exists(filepath):
            continue
            
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original = content
            
            # Specific fixes based on error messages
            if 'cache_manager.dart' in filepath:
                content = content.replace('const Duration(milliseconds: ttl.inMilliseconds)', 'Duration(milliseconds: ttl.inMilliseconds)')
                content = content.replace('maximumSize: const maximumSize', 'maximumSize: maximumSize')
            
            if 'app_button.dart' in filepath:
                content = content.replace('const Duration(milliseconds: 200)', 'Duration(milliseconds: 200)')
                content = content.replace('const EdgeInsets.symmetric(horizontal: padding', 'EdgeInsets.symmetric(horizontal: padding')
                content = content.replace('const Icon(icon)', 'Icon(icon)')
            
            if 'app_card.dart' in filepath:
                content = content.replace('const Duration(milliseconds: 200)', 'Duration(milliseconds: 200)')
            
            if 'app_loading.dart' in filepath:
                content = content.replace('const Duration(seconds: duration)', 'Duration(seconds: duration)')
            
            if 'error_boundary.dart' in filepath:
                content = content.replace('const ErrorDisplay(', 'ErrorDisplay(')
            
            if 'error_handler.dart' in filepath:
                content = content.replace('const Duration(milliseconds: delay)', 'Duration(milliseconds: delay)')
            
            if content != original:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Fixed: {filepath}")
                
        except Exception as e:
            print(f"Error processing {filepath}: {e}")

def main():
    # Files identified with const errors from flutter analyze
    files_with_errors = [
        'lib/core/cache/cache_manager.dart',
        'lib/core/components/buttons/app_button.dart',
        'lib/core/components/cards/app_card.dart',
        'lib/core/components/loading/app_loading.dart',
        'lib/core/errors/error_boundary.dart',
        'lib/core/errors/error_handler.dart',
    ]
    
    fix_specific_files(files_with_errors)
    
    print("\nConst errors fixed. Run 'flutter analyze' to verify.")

if __name__ == '__main__':
    main()