#!/usr/bin/env python3
"""
Fix incorrect enum usage in server files.
Replaces uppercase enum attributes with correct lowercase versions.
"""

import os
import re

# Mapping of incorrect to correct enum usage
ENUM_FIXES = {
    # LeadStatus fixes (uppercase to lowercase)
    'LeadStatus.NEW': 'LeadStatus.new',
    'LeadStatus.VIEWED': 'LeadStatus.viewed',
    'LeadStatus.CALLED': 'LeadStatus.called',
    'LeadStatus.CALLBACK_SCHEDULED': 'LeadStatus.callbackScheduled',
    'LeadStatus.INTERESTED': 'LeadStatus.interested',
    'LeadStatus.CONVERTED': 'LeadStatus.converted',
    'LeadStatus.DNC': 'LeadStatus.doNotCall',
    'LeadStatus.DO_NOT_CALL': 'LeadStatus.doNotCall',
    'LeadStatus.DID_NOT_CONVERT': 'LeadStatus.didNotConvert',
}

def fix_file(filepath):
    """Fix enum usage in a single file."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    fixes_made = []
    
    for incorrect, correct in ENUM_FIXES.items():
        if incorrect in content:
            # Count occurrences
            count = content.count(incorrect)
            content = content.replace(incorrect, correct)
            fixes_made.append(f"  - Fixed {count} occurrences of {incorrect} → {correct}")
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        return fixes_made
    return []

def main():
    """Fix enum usage in all Python files."""
    print("=" * 60)
    print("FIXING ENUM USAGE IN SERVER FILES")
    print("=" * 60)
    
    # Files to check
    files_to_fix = [
        'main.py',
        'conversion_scoring_service.py',
        'analytics_engine.py',
        'lead_management.py',
        'scraper_runner.py',
        'job_management.py',
    ]
    
    total_fixes = 0
    
    for filename in files_to_fix:
        filepath = os.path.join(os.path.dirname(__file__), filename)
        if os.path.exists(filepath):
            print(f"\nChecking {filename}...")
            fixes = fix_file(filepath)
            if fixes:
                print(f"✓ Fixed {filename}:")
                for fix in fixes:
                    print(fix)
                total_fixes += len(fixes)
            else:
                print(f"  No changes needed")
        else:
            print(f"⚠️  File not found: {filename}")
    
    print("\n" + "=" * 60)
    if total_fixes > 0:
        print(f"✅ Fixed {total_fixes} enum usage issues")
        print("\n⚠️  IMPORTANT: Rebuild Docker container for changes to take effect:")
        print("  docker-compose down && docker-compose up -d --build")
    else:
        print("✓ No enum usage issues found")
    print("=" * 60)

if __name__ == "__main__":
    main()