#!/usr/bin/env python3
"""
Fix const errors in Flutter files by removing inappropriate const keywords
"""

import re
import os
import sys

def fix_const_errors(filepath):
    """Fix const errors in a single file"""
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return False
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern 1: Remove const from Theme.of(context) calls
    content = re.sub(
        r'const\s+(Text|Icon|Container|Padding|Column|Row|SizedBox|Expanded|Flexible)\s*\([^)]*Theme\.of\(context\)',
        r'\1(' + r'\2Theme.of(context)',
        content
    )
    
    # Pattern 2: Remove const from widgets containing non-const expressions
    # This matches const Widget( ... non-const-expression ... )
    patterns = [
        (r'const\s+(Padding|Container|Column|Row|Wrap|Stack)\s*\(', r'\1('),
        (r'const\s+(Text|Icon|IconButton|TextButton|ElevatedButton)\s*\(', r'\1('),
        (r'const\s+(Card|Chip|ChoiceChip|FilterChip)\s*\(', r'\1('),
        (r'const\s+(ListTile|ExpansionTile|GridTile)\s*\(', r'\1('),
    ]
    
    # Check if the widget contains method calls or non-const variables
    for pattern, replacement in patterns:
        # Find all matches
        matches = re.finditer(pattern, content)
        for match in reversed(list(matches)):
            start = match.start()
            # Look ahead to find the matching closing paren
            paren_count = 1
            i = match.end()
            while i < len(content) and paren_count > 0:
                if content[i] == '(':
                    paren_count += 1
                elif content[i] == ')':
                    paren_count -= 1
                i += 1
            
            widget_content = content[match.end():i-1]
            # Check if it contains method calls or variable references
            if ('Theme.of(' in widget_content or 
                'MediaQuery.of(' in widget_content or
                '.withValues(' in widget_content or
                'isSelected' in widget_content or
                'isCenter' in widget_content or
                'widget.' in widget_content or
                'ref.' in widget_content):
                # Remove const
                content = content[:start] + content[start:].replace('const ', '', 1)
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed: {filepath}")
        return True
    return False

def main():
    # Get list of files with const errors from flutter analyze
    import subprocess
    
    result = subprocess.run(
        ['flutter', 'analyze'],
        capture_output=True,
        text=True
    )
    
    files_to_fix = set()
    for line in result.stderr.split('\n'):
        if 'const_eval_method_invocation' in line or 'invalid_constant' in line or 'const_with_non_const' in line:
            # Extract filepath
            parts = line.split('•')
            if len(parts) >= 3:
                filepath = parts[2].strip().split(':')[0]
                if filepath.startswith('lib/'):
                    files_to_fix.add(filepath)
    
    print(f"Found {len(files_to_fix)} files with const errors")
    
    fixed_count = 0
    for filepath in sorted(files_to_fix):
        if fix_const_errors(filepath):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files")

if __name__ == '__main__':
    main()