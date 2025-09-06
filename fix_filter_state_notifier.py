#!/usr/bin/env python3
"""
Fix FilterStateNotifier to remove duplicates and fix AsyncValue issues.
"""

import os
import re

def fix_filter_state_notifier():
    """Fix the FilterStateNotifier class."""
    
    file_path = 'lib/features/leads/domain/providers/filter_providers.dart'
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return
    
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # Find and remove duplicate methods (lines 343-389)
    # These are the problematic duplicate methods that use wrong syntax
    start_line = None
    end_line = None
    
    for i, line in enumerate(lines):
        if 'void updateSearchFilter(String? searchQuery) {' in line and i > 340:
            start_line = i
        if start_line and 'void updateReviewCountRange(RangeValues? range) {' in line:
            # Find the closing brace
            for j in range(i, min(i+5, len(lines))):
                if lines[j].strip() == '}':
                    end_line = j + 1
                    break
            break
    
    if start_line and end_line:
        # Remove the duplicate methods
        del lines[start_line:end_line]
        print(f"Removed duplicate methods from lines {start_line+1} to {end_line+1}")
    
    # Fix the existing async methods to properly use state.whenData
    content = ''.join(lines)
    
    # Fix methods that incorrectly try to call copyWith on AsyncValue
    # The pattern should be: state.whenData((currentState) async { ... })
    # Not: state = state.copyWith(...)
    
    # Also need to add missing imports
    if 'import \'../../domain/entities/lead.dart\';' not in content:
        # Add after other imports
        import_line = "import '../../domain/entities/lead.dart';"
        content = re.sub(
            r"(import '[^']+/filter_state\.dart';)",
            rf"\1\n{import_line}",
            content,
            count=1
        )
    
    # Add RangeValues import if missing
    if 'import \'package:flutter/material.dart\';' not in content:
        import_line = "import 'package:flutter/material.dart' show RangeValues;"
        content = re.sub(
            r"(import 'package:flutter_riverpod/flutter_riverpod\.dart';)",
            rf"\1\n{import_line}",
            content,
            count=1
        )
    
    # Write the fixed content
    with open(file_path, 'w') as f:
        f.write(content)
    
    print(f"Fixed {file_path}")

def fix_provider_references():
    """Fix references to use the async methods properly."""
    
    files_to_fix = [
        'lib/features/leads/presentation/widgets/leads_filter_bar.dart',
        'lib/features/leads/presentation/widgets/filter_bar.dart',
        'lib/features/leads/presentation/widgets/primary_filter_row.dart',
        'lib/features/leads/presentation/widgets/unified_filter_modal.dart',
    ]
    
    for file_path in files_to_fix:
        if not os.path.exists(file_path):
            continue
        
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Fix method calls to match the async signatures
        # updateSearchFilter -> updateSearch
        content = re.sub(
            r'\.updateSearchFilter\(',
            '.updateSearch(',
            content
        )
        
        # updateStatusFilter -> updateStatus  
        content = re.sub(
            r'\.updateStatusFilter\(',
            '.updateStatus(',
            content
        )
        
        # Fix followUpFilter calls - the async version takes String?
        content = re.sub(
            r'\.updateFollowUpFilter\((true|false)\)',
            r'.updateFollowUpFilter(null)',
            content
        )
        
        # Fix ratingRange and reviewCountRange calls
        content = re.sub(
            r'\.updateRatingRange\(',
            '.updateRatingRangeFilter(',
            content
        )
        
        content = re.sub(
            r'\.updateReviewCountRange\(',
            '.updateReviewCountRangeFilter(',
            content
        )
        
        with open(file_path, 'w') as f:
            f.write(content)
        
        print(f"Fixed references in {file_path}")

def main():
    print("🔧 Fixing FilterStateNotifier...")
    
    fix_filter_state_notifier()
    fix_provider_references()
    
    print("\n✅ Fixes applied")

if __name__ == "__main__":
    main()