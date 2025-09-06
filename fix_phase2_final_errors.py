#!/usr/bin/env python3
"""
Fix all remaining Phase 2 errors to achieve ZERO ERRORS.
"""

import os
import re
import subprocess

def run_flutter_analyze():
    """Run flutter analyze and capture output."""
    result = subprocess.run(['flutter', 'analyze'], 
                          capture_output=True, text=True)
    return result.stdout + result.stderr

def fix_ambiguous_imports():
    """Fix ambiguous imports by using import aliases."""
    files_to_fix = [
        'lib/features/leads/presentation/pages/leads_list_page.dart',
        'lib/features/leads/presentation/widgets/filter_bar.dart',
        'lib/features/leads/presentation/widgets/advanced_filter_bar.dart',
        'lib/features/leads/presentation/widgets/leads_filter_bar.dart',
        'lib/features/leads/presentation/widgets/sort_bar.dart',
        'lib/features/leads/presentation/widgets/primary_filter_row.dart',
        'lib/features/leads/presentation/pages/lead_search_page.dart',
    ]
    
    for file_path in files_to_fix:
        if not os.path.exists(file_path):
            continue
            
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Check if file imports both filter_providers
        has_domain = 'import \'../../domain/providers/filter_providers.dart\'' in content
        has_presentation = 'import \'../providers/filter_providers.dart\'' in content or \
                          'import \'../../presentation/providers/filter_providers.dart\'' in content
        
        if has_domain and has_presentation:
            # Add aliases
            content = re.sub(
                r"import '(.*?/domain/providers/filter_providers\.dart)';",
                r"import '\1' as domain_filters;",
                content
            )
            content = re.sub(
                r"import '(.*?/presentation/providers/filter_providers\.dart)';",
                r"import '\1' as ui_filters;",
                content
            )
            
            # Update references - presentation providers should be used for UI state
            ui_providers = [
                'searchFilterProvider', 'statusFilterProvider', 'candidatesOnlyProvider',
                'sortStateProvider', 'hasWebsiteFilterProvider', 'pageSpeedFilterProvider',
                'meetsRatingFilterProvider', 'hasRecentReviewsFilterProvider',
                'followUpFilterProvider', 'isSelectionModeProvider', 'selectedLeadsProvider',
                'groupByProvider', 'SortOption', 'SortState', 'GroupByOption'
            ]
            
            for provider in ui_providers:
                # For providers used in ref.watch/read
                content = re.sub(
                    rf'ref\.(watch|read)\({provider}',
                    rf'ref.\1(ui_filters.{provider}',
                    content
                )
                # For direct references
                content = re.sub(
                    rf'\b{provider}\b(?!\.)',
                    f'ui_filters.{provider}',
                    content
                )
            
            with open(file_path, 'w') as f:
                f.write(content)
            print(f"Fixed ambiguous imports in {file_path}")

def fix_default_value_errors():
    """Fix non-constant default values."""
    files_to_fix = {
        'lib/features/leads/domain/entities/automation_source.dart': [
            ('Map<String, dynamic> config = {}', 'Map<String, dynamic> config = const {}'),
        ],
        'lib/features/leads/domain/entities/filter_state.dart': [
            ('List<String> statusFilters = []', 'List<String> statusFilters = const []'),
            ('List<String> industries = []', 'List<String> industries = const []'),
            ('Map<String, dynamic> additionalFilters = {}', 'Map<String, dynamic> additionalFilters = const {}'),
        ],
        'lib/features/leads/domain/entities/lead.dart': [
            ('List<CallLog> callLogs = []', 'List<CallLog> callLogs = const []'),
        ],
        'lib/features/leads/domain/usecases/browser_automation_usecase.dart': [
            ('List<String> industries = []', 'List<String> industries = const []'),
            ('List<String> cities = []', 'List<String> cities = const []'),
        ],
    }
    
    for file_path, replacements in files_to_fix.items():
        if not os.path.exists(file_path):
            continue
            
        with open(file_path, 'r') as f:
            content = f.read()
        
        for old, new in replacements:
            content = content.replace(old, new)
        
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Fixed default values in {file_path}")

def fix_const_initialization_errors():
    """Fix const variables initialized with non-const values."""
    file_path = 'lib/features/leads/domain/entities/automation_source.dart'
    
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Remove const from factory variables
        content = re.sub(
            r'static const AutomationSource manual = AutomationSource\(',
            r'static final AutomationSource manual = AutomationSource(',
            content
        )
        content = re.sub(
            r'static const AutomationSource googleMaps = AutomationSource\(',
            r'static final AutomationSource googleMaps = AutomationSource(',
            content
        )
        content = re.sub(
            r'static const AutomationSource import = AutomationSource\(',
            r'static final AutomationSource import = AutomationSource(',
            content
        )
        
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Fixed const initialization in {file_path}")

def fix_undefined_future_getter():
    """Fix undefined 'future' getter error."""
    file_path = 'lib/features/leads/presentation/pages/leads_list_page.dart'
    
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Replace .future with proper AsyncValue handling
        content = re.sub(
            r'final filterState = await ref\.read\(filterStateProvider\.future\);',
            r'final filterStateAsync = ref.read(filterStateProvider);\n    if (filterStateAsync.hasValue) {\n      final filterState = filterStateAsync.value!;',
            content
        )
        
        # Close the if block properly
        content = re.sub(
            r'(\s+)(ref\.read\(updateFilterStateProvider\)\.execute\(filterState\);)',
            r'\1\2\n\1}',
            content
        )
        
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Fixed undefined future getter in {file_path}")

def main():
    print("🔧 Fixing Phase 2 final errors...")
    
    # Fix all issues
    fix_ambiguous_imports()
    fix_default_value_errors()
    fix_const_initialization_errors()
    fix_undefined_future_getter()
    
    print("\n✅ All fixes applied. Running flutter analyze...")
    
    # Run flutter analyze
    output = run_flutter_analyze()
    
    # Count errors
    error_count = len(re.findall(r'^\s*error •', output, re.MULTILINE))
    warning_count = len(re.findall(r'^\s*warning •', output, re.MULTILINE))
    info_count = len(re.findall(r'^\s*info •', output, re.MULTILINE))
    
    print(f"\n📊 Analysis Results:")
    print(f"  Errors: {error_count}")
    print(f"  Warnings: {warning_count}")
    print(f"  Info: {info_count}")
    
    if error_count == 0:
        print("\n🎉 SUCCESS: ZERO ERRORS ACHIEVED!")
        print("Phase 2 is ready for completion!")
    else:
        print(f"\n❌ Still have {error_count} errors to fix")
        # Show first 10 errors
        errors = re.findall(r'^\s*error •.*$', output, re.MULTILINE)[:10]
        print("\nFirst 10 errors:")
        for error in errors:
            print(f"  {error}")

if __name__ == "__main__":
    main()