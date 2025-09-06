#!/usr/bin/env python3
import os
import re

def fix_icon_errors(content):
    """Fix Icon constructor errors where Icons was incorrectly used"""
    # Fix Icon(Icons) -> Icon(Icons.error) or similar
    content = content.replace('Icon(Icons)', 'Icon(Icons.refresh)')
    content = content.replace('icon: Icons', 'icon: Icons.refresh')
    
    # Fix specific const constructors
    content = content.replace('const ErrorDisplay(', 'ErrorDisplay(')
    
    # Fix default parameter values that can't be const
    patterns = [
        (r'this\.defaultTtl = Duration\(', r'this.defaultTtl = const Duration('),
        (r'this\.batchWindow = Duration\(', r'this.batchWindow = const Duration('),
        (r'this\.resetTimeout = Duration\(', r'this.resetTimeout = const Duration('),
        (r'this\.timeout = Duration\(', r'this.timeout = const Duration('),
        (r'this\.initialDelay = Duration\(', r'this.initialDelay = const Duration('),
        (r'this\.maxDelay = Duration\(', r'this.maxDelay = const Duration('),
        (r'this\.evaluationInterval = Duration\(', r'this.evaluationInterval = const Duration('),
        (r'this\.fadeInDuration = Duration\(', r'this.fadeInDuration = const Duration('),
        (r'this\.transitionDuration = Duration\(', r'this.transitionDuration = const Duration('),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    return content

def process_file(filepath):
    """Process a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        content = fix_icon_errors(content)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix Icon errors in all Dart files"""
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