#!/usr/bin/env python3
"""
Comprehensive Flutter error fixing script
Principal Engineer approach: Fix ALL errors systematically
"""

import re
import os
import subprocess
import sys

def remove_all_const_keywords(content):
    """Remove ALL const keywords to fix const-related errors"""
    # Remove const from widget constructors
    patterns = [
        (r'\bconst\s+(\w+)\s*\(', r'\1('),  # const Widget(
        (r'\bconst\s+(\w+\.\w+)\s*\(', r'\1('),  # const Class.constructor(
        (r'\bconst\s+(<[\w<>,\s]+>)?\s*\[', r'\1['),  # const [] or const <Type>[]
        (r'\bconst\s+(<[\w<>,\s]+>)?\s*\{', r'\1{'),  # const {} or const <Type>{}
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_lead_constructor_calls(content):
    """Add all required parameters to Lead() constructor calls"""
    if 'Lead(' not in content:
        return content
    
    # Pattern to match Lead( ... ) constructor calls
    lead_pattern = r'(Lead\s*\([^)]*\))'
    
    def fix_lead(match):
        lead_call = match.group(1)
        
        # Check which required params are missing and add defaults
        required_params = {
            'id': "'test-id'",
            'businessName': "'Test Business'",
            'phone': "'555-0000'",
            'industry': "'unknown'",
            'location': "'unknown'",
            'source': "'manual'",
            'hasWebsite': 'false',
            'meetsRatingThreshold': 'false',
            'hasRecentReviews': 'false',
            'isCandidate': 'false',
            'status': 'LeadStatus.new_',
            'createdAt': 'DateTime.now()',
            'updatedAt': 'DateTime.now()',
        }
        
        for param, default in required_params.items():
            if f'{param}:' not in lead_call:
                # Add the parameter before the closing paren
                lead_call = lead_call[:-1] + f', {param}: {default})'
        
        return lead_call
    
    content = re.sub(lead_pattern, fix_lead, content)
    return content

def add_missing_imports(filepath, content):
    """Add missing imports based on undefined names"""
    missing_imports = []
    
    # Check for SortOption usage
    if 'SortOption' in content and "import '../providers/filter_providers.dart'" not in content:
        if '/widgets/' in filepath or '/pages/' in filepath:
            missing_imports.append("import '../providers/filter_providers.dart';")
    
    # Check for provider usage
    providers = [
        'sortStateProvider', 'searchFilterProvider', 'statusFilterProvider',
        'candidatesOnlyProvider', 'hasWebsiteFilterProvider', 'selectedLeadsProvider',
        'isSelectionModeProvider', 'pageSpeedFilterProvider', 'meetsRatingFilterProvider',
        'hasRecentReviewsFilterProvider', 'followUpFilterProvider', 'ratingRangeFilterProvider',
        'GroupByOption', 'SortState'
    ]
    
    for provider in providers:
        if provider in content and "import '../providers/filter_providers.dart'" not in content:
            if '/widgets/' in filepath or '/pages/' in filepath:
                missing_imports.append("import '../providers/filter_providers.dart';")
                break
    
    # Add imports after the last import statement
    if missing_imports:
        last_import = 0
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if line.startswith('import '):
                last_import = i
        
        for imp in set(missing_imports):
            lines.insert(last_import + 1, imp)
        
        content = '\n'.join(lines)
    
    return content

def fix_file(filepath):
    """Apply all fixes to a single file"""
    if not os.path.exists(filepath):
        return False
    
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        
        # Skip mock files - they will be regenerated
        if filepath.endswith('.mocks.dart'):
            return False
        
        # Apply all fixes
        content = remove_all_const_keywords(content)
        
        # Only fix Lead constructors in test files
        if '/test/' in filepath:
            content = fix_lead_constructor_calls(content)
        
        # Add missing imports
        content = add_missing_imports(filepath, content)
        
        if content != original:
            with open(filepath, 'w') as f:
                f.write(content)
            return True
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
    
    return False

def main():
    print("=== Comprehensive Error Fix ===")
    print("Fixing ALL errors to achieve ZERO ERRORS requirement")
    print()
    
    # Step 1: Remove all mock files
    print("Step 1: Removing mock files...")
    os.system("find . -name '*.mocks.dart' -delete")
    
    # Step 2: Get all Dart files
    print("Step 2: Processing all Dart files...")
    dart_files = []
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))
    
    for root, dirs, files in os.walk('test'):
        for file in files:
            if file.endswith('.dart') and not file.endswith('.mocks.dart'):
                dart_files.append(os.path.join(root, file))
    
    print(f"Found {len(dart_files)} Dart files to process")
    
    # Step 3: Fix all files
    fixed_count = 0
    for filepath in dart_files:
        if fix_file(filepath):
            fixed_count += 1
            print(f"  Fixed: {filepath}")
    
    print(f"\nFixed {fixed_count} files")
    
    # Step 4: Regenerate mocks
    print("\nStep 3: Regenerating mock files...")
    os.system("flutter pub run build_runner build --delete-conflicting-outputs 2>/dev/null")
    
    # Step 5: Final analysis
    print("\nStep 4: Running final analysis...")
    result = subprocess.run(['flutter', 'analyze'], capture_output=True, text=True)
    
    # Count errors
    error_lines = [line for line in result.stderr.split('\n') if '  error •' in line]
    error_count = len(error_lines)
    
    print(f"\n{'='*50}")
    print(f"FINAL RESULT: {error_count} errors")
    
    if error_count == 0:
        print("✅ SUCCESS: ZERO ERRORS ACHIEVED!")
    else:
        print(f"❌ {error_count} errors remaining")
        print("\nTop remaining errors:")
        # Show top error types
        error_types = {}
        for line in error_lines[:20]:
            if '•' in line:
                parts = line.split('•')
                if len(parts) >= 2:
                    error_type = parts[1].strip()
                    error_types[error_type] = error_types.get(error_type, 0) + 1
        
        for error_type, count in sorted(error_types.items(), key=lambda x: x[1], reverse=True)[:5]:
            print(f"  {count}: {error_type}")
    
    return error_count

if __name__ == '__main__':
    error_count = main()
    sys.exit(0 if error_count == 0 else 1)