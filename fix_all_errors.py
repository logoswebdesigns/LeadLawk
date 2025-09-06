#!/usr/bin/env python3
"""
Fix all Flutter analyze errors systematically
"""

import re
import os
import subprocess

def fix_const_withValues(content):
    """Fix const errors with withValues method calls"""
    # Remove const from any widget containing .withValues(
    content = re.sub(
        r'const\s+([\w<>]+)\s*\(([^)]*\.withValues\([^)]*\)[^)]*)\)',
        r'\1(\2)',
        content
    )
    return content

def fix_const_theme_of(content):
    """Fix const errors with Theme.of(context)"""
    # Remove const from widgets containing Theme.of(context)
    content = re.sub(
        r'const\s+([\w<>]+)\s*\(([^)]*Theme\.of\(context\)[^)]*)\)',
        r'\1(\2)',
        content
    )
    return content

def fix_missing_required_params(content):
    """Add missing required parameters to Lead constructors"""
    # Find Lead( constructors
    lead_pattern = r'Lead\s*\(((?:[^()]*|\([^)]*\))*)\)'
    
    def add_missing_params(match):
        params = match.group(1)
        
        # Check what's missing and add defaults
        if 'createdAt:' not in params:
            params += ',\n        createdAt: DateTime.now()'
        if 'updatedAt:' not in params:
            params += ',\n        updatedAt: DateTime.now()'
        if 'status:' not in params:
            params += ',\n        status: LeadStatus.new_'
        if 'source:' not in params:
            params += ',\n        source: \'manual\''
        if 'industry:' not in params:
            params += ',\n        industry: \'unknown\''
        if 'location:' not in params:
            params += ',\n        location: \'unknown\''
        if 'hasWebsite:' not in params:
            params += ',\n        hasWebsite: false'
        if 'meetsRatingThreshold:' not in params:
            params += ',\n        meetsRatingThreshold: false'
        if 'hasRecentReviews:' not in params:
            params += ',\n        hasRecentReviews: false'
        if 'isCandidate:' not in params:
            params += ',\n        isCandidate: false'
            
        return f'Lead({params})'
    
    content = re.sub(lead_pattern, add_missing_params, content)
    return content

def fix_file(filepath):
    """Fix all errors in a single file"""
    if not os.path.exists(filepath):
        return False
    
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        
        # Apply fixes
        content = fix_const_withValues(content)
        content = fix_const_theme_of(content)
        
        # Only fix Lead constructors in test files
        if 'test/' in filepath:
            content = fix_missing_required_params(content)
        
        if content != original:
            with open(filepath, 'w') as f:
                f.write(content)
            return True
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
    
    return False

def main():
    # Get all Dart files
    dart_files = []
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))
    
    for root, dirs, files in os.walk('test'):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))
    
    print(f"Processing {len(dart_files)} files...")
    
    fixed_count = 0
    for filepath in dart_files:
        if fix_file(filepath):
            fixed_count += 1
            print(f"Fixed: {filepath}")
    
    print(f"\nFixed {fixed_count} files")
    
    # Run flutter analyze to show remaining errors
    print("\nRunning flutter analyze...")
    result = subprocess.run(['flutter', 'analyze'], capture_output=True, text=True)
    error_count = result.stderr.count('error •')
    print(f"Remaining errors: {error_count}")

if __name__ == '__main__':
    main()