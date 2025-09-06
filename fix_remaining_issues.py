#!/usr/bin/env python3
import os
import re

def fix_dangling_comments(content):
    """Fix dangling library doc comments"""
    # If file starts with ///, convert to //
    lines = content.split('\n')
    changed = False
    
    for i in range(min(10, len(lines))):  # Check first 10 lines
        if lines[i].strip().startswith('///'):
            lines[i] = lines[i].replace('///', '//', 1)
            changed = True
        elif lines[i].strip() and not lines[i].strip().startswith('//'):
            break
    
    if changed:
        return '\n'.join(lines)
    return content

def add_const_constructors(content):
    """Add const to constructors where appropriate"""
    patterns = [
        # Duration constructors
        (r'Duration\(([^)]+)\)', r'const Duration(\1)'),
        # EdgeInsets constructors
        (r'EdgeInsets\.all\(([^)]+)\)', r'const EdgeInsets.all(\1)'),
        (r'EdgeInsets\.symmetric\(([^)]+)\)', r'const EdgeInsets.symmetric(\1)'),
        (r'EdgeInsets\.only\(([^)]+)\)', r'const EdgeInsets.only(\1)'),
        # SizedBox constructors
        (r'SizedBox\(([^)]+)\)', r'const SizedBox(\1)'),
        # Text constructors (be careful with dynamic content)
        (r'Text\([\'"](.*?)[\'"]\)', r"const Text('\1')"),
        # Icon constructors
        (r'Icon\(([^)]+)\)', r'const Icon(\1)'),
        # Container with no child
        (r'Container\(\s*\)', r'const Container()'),
    ]
    
    for pattern, replacement in patterns:
        # Don't add const if already there
        if not re.search(r'const\s+' + pattern, content):
            content = re.sub(pattern, replacement, content)
    
    return content

def fix_foreach_calls(content):
    """Replace forEach with for-in loops"""
    # This is complex, so we'll just flag it for manual review
    if '.forEach(' in content:
        # Simple cases where we can auto-fix
        pattern = r'(\w+)\.forEach\(\((\w+)\)\s*\{\s*([^}]+)\s*\}\)'
        replacement = r'for (final \2 in \1) { \3 }'
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_unused_imports(content):
    """Remove unused imports (conservative approach)"""
    lines = content.split('\n')
    new_lines = []
    
    for line in lines:
        # Skip obvious unused imports from test files
        if 'import' in line and ('// ignore: unused_import' in line or 
                                 'package:leadloq/main.dart' in line and 'test/' in content):
            continue
        new_lines.append(line)
    
    return '\n'.join(new_lines)

def fix_super_parameters(content):
    """Convert regular parameters to super parameters where applicable"""
    # This is complex and requires AST analysis, so we'll leave it for manual fixing
    return content

def fix_deprecated_listen_self(content):
    """Fix deprecated listenSelf usage"""
    content = content.replace('.listenSelf(', '.listen(')
    return content

def fix_prefer_interpolation(content):
    """Fix string concatenation to use interpolation"""
    # Replace simple string concatenations
    pattern = r"'([^']+)'\s*\+\s*(\w+)\.toString\(\)"
    replacement = r"'\1$\2'"
    content = re.sub(pattern, replacement, content)
    
    pattern = r'"([^"]+)"\s*\+\s*(\w+)\.toString\(\)'
    replacement = r'"\1$\2"'
    content = re.sub(pattern, replacement, content)
    
    return content

def process_file(filepath):
    """Process a single file to fix issues"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Apply fixes
        content = fix_dangling_comments(content)
        
        # Only apply Dart-specific fixes to .dart files
        if filepath.endswith('.dart'):
            content = add_const_constructors(content)
            content = fix_foreach_calls(content)
            content = fix_unused_imports(content)
            content = fix_deprecated_listen_self(content)
            content = fix_prefer_interpolation(content)
        
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
    """Fix remaining issues in all Dart files"""
    directories = ['lib', 'test']
    
    fixed_count = 0
    
    for directory in directories:
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.endswith('.dart'):
                    filepath = os.path.join(root, file)
                    if process_file(filepath):
                        print(f"Fixed: {filepath}")
                        fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")
    
    # Print manual fixes needed
    print("\n=== Manual fixes needed ===")
    print("1. Convert parameters to super parameters where applicable")
    print("2. Fix unrelated_type_equality_checks warnings")
    print("3. Remove unused local variables")
    print("4. Add args package to dev_dependencies if needed for test files")

if __name__ == '__main__':
    main()