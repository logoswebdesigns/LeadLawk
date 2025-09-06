#!/usr/bin/env python3
import os
import re

def fix_icon_issues(content):
    """Fix all Icon-related issues"""
    # Fix Icons.refresh. patterns (wrongly inserted)
    content = content.replace('Icons.refresh.list_alt_rounded', 'Icons.list_alt_rounded')
    content = content.replace('Icons.refresh.add_circle_outline', 'Icons.add_circle_outline')
    content = content.replace('Icons.refresh.insights', 'Icons.insights')
    content = content.replace('Icons.refresh.person_outline', 'Icons.person_outline')
    content = content.replace('Icons.refresh.close', 'Icons.close')
    content = content.replace('Icons.refresh.error', 'Icons.error')
    content = content.replace('Icons.refresh.warning', 'Icons.warning')
    content = content.replace('Icons.refresh.info', 'Icons.info')
    content = content.replace('Icons.refresh.check_circle', 'Icons.check_circle')
    
    # Fix EdgeInsets const issues
    patterns = [
        # Fix const SizedBox with variables
        (r'const SizedBox\(\s*height: (\d+)\)', r'SizedBox(height: \1)'),
        (r'const SizedBox\(\s*width: (\d+)\)', r'SizedBox(width: \1)'),
        
        # Fix const EdgeInsets
        (r'const EdgeInsets\.all\((\d+)\)', r'EdgeInsets.all(\1)'),
        (r'const EdgeInsets\.symmetric\(horizontal: (\d+), vertical: (\d+)\)', r'EdgeInsets.symmetric(horizontal: \1, vertical: \2)'),
        
        # Fix const Icon with literal IconData
        (r'const Icon\((Icons\.\w+)\)', r'Icon(\1)'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_const_constructor_issues(content):
    """Fix const constructor issues"""
    # Remove const from ErrorDisplay constructor
    content = content.replace('const ErrorDisplay(', 'ErrorDisplay(')
    
    # Fix Icon widget const issues
    patterns = [
        # Match variations of Icon widget with size parameter
        (r'const Icon\(\s*icon,\s*size:\s*[^)]+\)', lambda m: m.group(0).replace('const ', '')),
        # Icon with single parameter should remain const if it's Icons.something
        (r'Icon\((Icons\.\w+)\)', r'Icon(\1)'),
    ]
    
    for pattern, replacement in patterns:
        if callable(replacement):
            content = re.sub(pattern, replacement, content)
        else:
            content = re.sub(pattern, replacement, content)
    
    return content

def fix_sizedbox_issues(content):
    """Fix SizedBox const issues"""
    # Remove const from SizedBox when using expressions or method calls
    patterns = [
        (r'const SizedBox\(\s*height:\s*[^,\)]*\(\)', lambda m: m.group(0).replace('const ', '')),
        (r'const SizedBox\(\s*width:\s*[^,\)]*\(\)', lambda m: m.group(0).replace('const ', '')),
        (r'SizedBox\(\s*height:\s*(\d+)\)', r'const SizedBox(height: \1)'),
        (r'SizedBox\(\s*width:\s*(\d+)\)', r'const SizedBox(width: \1)'),
    ]
    
    for pattern, replacement in patterns:
        if callable(replacement):
            content = re.sub(pattern, replacement, content)
        else:
            content = re.sub(pattern, replacement, content)
    
    return content

def fix_duration_issues(content):
    """Fix Duration const issues in default parameters"""
    # These should have const in default parameters
    patterns = [
        (r'Duration\(milliseconds: (\d+)\)', r'const Duration(milliseconds: \1)'),
        (r'Duration\(seconds: (\d+)\)', r'const Duration(seconds: \1)'),
        (r'Duration\(minutes: (\d+)\)', r'const Duration(minutes: \1)'),
    ]
    
    for pattern, replacement in patterns:
        # Only in parameter defaults
        if 'this.' in content or '=' in content:
            content = re.sub(pattern, replacement, content)
    
    return content

def process_file(filepath):
    """Process a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Apply fixes in order
        content = fix_icon_issues(content)
        content = fix_const_constructor_issues(content)
        content = fix_sizedbox_issues(content)
        
        # Special handling for specific files
        if 'bottom_navigation.dart' in filepath:
            # Fix Icon constructor issues
            content = content.replace('const Icon(\n                    icon,', 'Icon(\n                    icon,')
        
        if 'error_boundary.dart' in filepath or 'error_handler.dart' in filepath:
            # Fix Icon(Icons.refresh) patterns
            content = content.replace('Icon(Icons.refresh)', 'const Icon(Icons.refresh)')
            content = content.replace('Icon(Icons.refresh.close)', 'const Icon(Icons.close)')
        
        if 'app_modal.dart' in filepath:
            # Fix Icon constructor
            content = content.replace('icon: Icons.refresh', 'icon: const Icon(Icons.close)')
            content = content.replace('Icon(icon)', 'icon ?? const Icon(Icons.info)')
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all errors in Dart files"""
    fixed_count = 0
    
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    for root, dirs, files in os.walk('test'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()