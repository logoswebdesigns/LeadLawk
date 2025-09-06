#!/usr/bin/env python3
"""
Fix all provider .notifier issues by converting to proper state notifier calls.
"""

import os
import re
import subprocess

def fix_provider_notifier_patterns():
    """Fix all incorrect provider.notifier.state = patterns."""
    
    # Map of providers to their state notifier methods
    provider_mappings = {
        # Filter providers - use currentFilterStateProvider.notifier methods
        'searchFilterProvider': ('currentFilterStateProvider', 'updateSearchFilter'),
        'statusFilterProvider': ('currentFilterStateProvider', 'updateStatusFilter'),
        'candidatesOnlyProvider': ('currentFilterStateProvider', 'updateCandidatesOnly'),
        'hasWebsiteFilterProvider': ('currentFilterStateProvider', 'updateHasWebsiteFilter'),
        'pageSpeedFilterProvider': ('currentFilterStateProvider', 'updatePageSpeedFilter'),
        'meetsRatingFilterProvider': ('currentFilterStateProvider', 'updateMeetsRatingFilter'),
        'hasRecentReviewsFilterProvider': ('currentFilterStateProvider', 'updateHasRecentReviewsFilter'),
        'followUpFilterProvider': ('currentFilterStateProvider', 'updateFollowUpFilter'),
        'locationFilterProvider': ('currentFilterStateProvider', 'updateLocationFilter'),
        'industryFilterProvider': ('currentFilterStateProvider', 'updateIndustryFilter'),
        'ratingRangeFilterProvider': ('currentFilterStateProvider', 'updateRatingRange'),
        'reviewCountRangeFilterProvider': ('currentFilterStateProvider', 'updateReviewCountRange'),
        
        # UI state providers - these can use StateProvider.notifier.state
        'selectedLeadsProvider': None,  # This one can stay as is
        'isSelectionModeProvider': None,  # This one can stay as is
        'calledTodayProvider': None,  # This one can stay as is
        'groupByProvider': None,  # This one can stay as is
        
        # Sort state - use currentSortStateProvider.notifier
        'sortStateProvider': ('currentSortStateProvider', 'updateSort'),
    }
    
    files_to_fix = [
        'lib/features/leads/presentation/widgets/filter_bar.dart',
        'lib/features/leads/presentation/widgets/advanced_filter_bar.dart',
        'lib/features/leads/presentation/widgets/leads_filter_bar.dart',
        'lib/features/leads/presentation/widgets/sort_bar.dart',
        'lib/features/leads/presentation/widgets/primary_filter_row.dart',
        'lib/features/leads/presentation/widgets/advanced_filter_extras.dart',
        'lib/features/leads/presentation/widgets/advanced_filter_search.dart',
        'lib/features/leads/presentation/widgets/advanced_filter_section.dart',
        'lib/features/leads/presentation/widgets/unified_filter_modal.dart',
        'lib/features/leads/presentation/widgets/pagespeed_filter.dart',
        'lib/features/leads/presentation/pages/lead_search_page.dart',
        'lib/features/leads/presentation/pages/leads_list_page.dart',
    ]
    
    fixed_count = 0
    
    for file_path in files_to_fix:
        if not os.path.exists(file_path):
            continue
        
        with open(file_path, 'r') as f:
            content = f.read()
        
        original = content
        
        # Fix each provider pattern
        for provider, mapping in provider_mappings.items():
            if mapping is None:
                # These providers can use .notifier.state pattern
                continue
            
            state_notifier, method = mapping
            
            # Pattern 1: ref.read(provider.notifier).state = value
            pattern1 = rf'ref\.read\({provider}\.notifier\)\.state\s*=\s*([^;]+);'
            replacement1 = rf'ref.read({state_notifier}.notifier).{method}(\1);'
            content = re.sub(pattern1, replacement1, content)
            
            # Pattern 2: ref.watch(provider.notifier).state = value
            pattern2 = rf'ref\.watch\({provider}\.notifier\)\.state\s*=\s*([^;]+);'
            replacement2 = rf'ref.read({state_notifier}.notifier).{method}(\1);'
            content = re.sub(pattern2, replacement2, content)
            
            # Pattern 3: final notifier = ref.read(provider.notifier); notifier.state = value
            pattern3 = rf'final\s+\w+\s*=\s*ref\.read\({provider}\.notifier\);'
            replacement3 = rf'final notifier = ref.read({state_notifier}.notifier);'
            content = re.sub(pattern3, replacement3, content)
        
        # Add necessary imports if not present
        if 'currentFilterStateProvider' in content and \
           "import '../../domain/providers/filter_providers.dart'" not in content:
            # Add import after other imports
            import_line = "import '../../domain/providers/filter_providers.dart';"
            content = re.sub(
                r"(import '[^']+';)\n",
                rf"\1\n{import_line}\n",
                content,
                count=1
            )
        
        if content != original:
            with open(file_path, 'w') as f:
                f.write(content)
            fixed_count += 1
            print(f"Fixed {file_path}")
    
    return fixed_count

def add_missing_state_notifier_methods():
    """Add any missing methods to FilterStateNotifier."""
    
    file_path = 'lib/features/leads/domain/providers/filter_providers.dart'
    if not os.path.exists(file_path):
        return
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if methods exist, if not add them
    methods_to_add = [
        ('updateSearchFilter', 'String?', 'searchQuery'),
        ('updateStatusFilter', 'LeadStatus?', 'statusFilter'),
        ('updateCandidatesOnly', 'bool', 'candidatesOnly'),
        ('updateHasWebsiteFilter', 'bool?', 'hasWebsite'),
        ('updatePageSpeedFilter', 'int?', 'pageSpeedThreshold'),
        ('updateMeetsRatingFilter', 'bool?', 'meetsRating'),
        ('updateHasRecentReviewsFilter', 'bool?', 'hasRecentReviews'),
        ('updateFollowUpFilter', 'bool', 'followUp'),
        ('updateLocationFilter', 'List<String>', 'locations'),
        ('updateIndustryFilter', 'List<String>', 'industries'),
        ('updateRatingRange', 'RangeValues?', 'range'),
        ('updateReviewCountRange', 'RangeValues?', 'range'),
    ]
    
    # Find the FilterStateNotifier class
    class_match = re.search(r'class FilterStateNotifier[^{]*\{', content)
    if not class_match:
        return
    
    # Find the end of the class
    class_start = class_match.end()
    brace_count = 1
    pos = class_start
    while brace_count > 0 and pos < len(content):
        if content[pos] == '{':
            brace_count += 1
        elif content[pos] == '}':
            brace_count -= 1
        pos += 1
    class_end = pos - 1
    
    class_content = content[class_start:class_end]
    
    # Add missing methods
    new_methods = []
    for method_name, param_type, param_name in methods_to_add:
        if f'void {method_name}' not in class_content:
            method_code = f'''
  void {method_name}({param_type} {param_name}) {{
    state = state.copyWith({param_name}: {param_name});
  }}'''
            new_methods.append(method_code)
    
    if new_methods:
        # Insert methods before the closing brace
        content = content[:class_end] + '\n'.join(new_methods) + '\n' + content[class_end:]
        
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Added {len(new_methods)} methods to FilterStateNotifier")

def main():
    print("🔧 Fixing provider .notifier errors...")
    
    # Fix provider patterns
    fixed = fix_provider_notifier_patterns()
    print(f"Fixed {fixed} files with provider patterns")
    
    # Add missing methods
    add_missing_state_notifier_methods()
    
    # Run flutter analyze
    print("\n📊 Running flutter analyze...")
    result = subprocess.run(['flutter', 'analyze'], 
                          capture_output=True, text=True)
    output = result.stdout + result.stderr
    
    # Count errors
    error_count = len(re.findall(r'^\s*error •', output, re.MULTILINE))
    
    print(f"\n📊 Errors remaining: {error_count}")
    
    if error_count > 0:
        # Show first 5 errors
        errors = re.findall(r'^\s*error •.*$', output, re.MULTILINE)[:5]
        print("\nFirst 5 errors:")
        for error in errors:
            print(f"  {error.strip()}")
    
    return error_count

if __name__ == "__main__":
    error_count = main()
    if error_count == 0:
        print("\n🎉 SUCCESS: All provider .notifier errors fixed!")
    else:
        print(f"\n⚠️  Still {error_count} errors to fix")