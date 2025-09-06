#!/usr/bin/env python3
"""
Comprehensive Phase 2 error fixing script.
Achieves ZERO ERRORS by fixing all issues systematically.
"""

import os
import re
import subprocess
import json

def run_flutter_analyze():
    """Run flutter analyze and parse output."""
    result = subprocess.run(['flutter', 'analyze'], 
                          capture_output=True, text=True)
    output = result.stdout + result.stderr
    
    # Parse errors
    errors = []
    for line in output.split('\n'):
        if '• error •' in line or 'error •' in line:
            errors.append(line)
    
    return output, errors

def fix_file_content(file_path, fixes):
    """Apply multiple fixes to a file."""
    if not os.path.exists(file_path):
        return False
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original = content
    for old, new in fixes:
        if isinstance(old, str):
            content = content.replace(old, new)
        else:  # regex
            content = old.sub(new, content)
    
    if content != original:
        with open(file_path, 'w') as f:
            f.write(content)
        return True
    return False

def fix_ambiguous_imports():
    """Fix all ambiguous import issues."""
    print("🔧 Fixing ambiguous imports...")
    
    # First, fix leads_list_page.dart properly
    file_path = 'lib/features/leads/presentation/pages/leads_list_page.dart'
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Remove duplicate ui_filters.ui_filters references
        content = re.sub(r'ui_filters\.ui_filters\.', 'ui_filters.', content)
        
        # Fix import statements if needed
        if '../providers/filter_providers.dart' not in content:
            # Add the presentation filter providers import
            content = re.sub(
                r"(import '../../domain/providers/filter_providers\.dart' as domain_filters;)",
                r"\1\nimport '../providers/filter_providers.dart' as ui_filters;",
                content
            )
        
        with open(file_path, 'w') as f:
            f.write(content)
    
    # Fix other files that may have filter provider issues
    files_with_filters = [
        'lib/features/leads/presentation/widgets/filter_bar.dart',
        'lib/features/leads/presentation/widgets/advanced_filter_bar.dart',
        'lib/features/leads/presentation/widgets/leads_filter_bar.dart',
        'lib/features/leads/presentation/widgets/sort_bar.dart',
        'lib/features/leads/presentation/widgets/primary_filter_row.dart',
        'lib/features/leads/presentation/pages/lead_search_page.dart',
    ]
    
    for file_path in files_with_filters:
        if not os.path.exists(file_path):
            continue
        
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Check what imports exist
        has_domain = '/domain/providers/filter_providers.dart' in content
        has_presentation = '/presentation/providers/filter_providers.dart' in content or \
                          '../providers/filter_providers.dart' in content
        
        if has_domain and has_presentation:
            # Both imported - add aliases
            content = re.sub(
                r"import '(.*?/domain/providers/filter_providers\.dart)';",
                r"import '\1' as domain_filters;",
                content
            )
            content = re.sub(
                r"import '(.*?providers/filter_providers\.dart)';",
                r"import '\1' as ui_filters;",
                content
            )
            
            # Prefix UI providers
            ui_providers = [
                'searchFilterProvider', 'statusFilterProvider', 'candidatesOnlyProvider',
                'sortStateProvider', 'hasWebsiteFilterProvider', 'pageSpeedFilterProvider',
                'selectedLeadsProvider', 'isSelectionModeProvider'
            ]
            
            for provider in ui_providers:
                # Only prefix if not already prefixed
                content = re.sub(
                    rf'(?<!ui_filters\.)(?<!domain_filters\.)\b{provider}\b',
                    f'ui_filters.{provider}',
                    content
                )
        
        with open(file_path, 'w') as f:
            f.write(content)

def fix_const_and_default_errors():
    """Fix all const and default value errors."""
    print("🔧 Fixing const and default value errors...")
    
    fixes = {
        'lib/features/leads/domain/entities/automation_source.dart': [
            # Make constructor const
            ('AutomationSource({', 'const AutomationSource({'),
            # Fix default value
            ('Map<String, dynamic> config = {}', 'Map<String, dynamic> config = const {}'),
            # Keep static final (not const) for factory instances
            ('static const AutomationSource manual =', 'static final AutomationSource manual ='),
            ('static const AutomationSource googleMaps =', 'static final AutomationSource googleMaps ='),
            ('static const AutomationSource import =', 'static final AutomationSource import ='),
        ],
        'lib/features/leads/domain/entities/filter_state.dart': [
            # Fix default values
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
    
    for file_path, file_fixes in fixes.items():
        fix_file_content(file_path, file_fixes)

def fix_undefined_future():
    """Fix undefined future getter."""
    print("🔧 Fixing undefined future getter...")
    
    file_path = 'lib/features/leads/presentation/pages/leads_list_page.dart'
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        # Find and fix the filterStateProvider.future reference
        for i, line in enumerate(lines):
            if 'filterStateProvider.future' in line:
                # Replace with proper AsyncValue handling
                lines[i] = line.replace(
                    'await ref.read(filterStateProvider.future)',
                    'ref.read(filterStateProvider).valueOrNull'
                )
        
        with open(file_path, 'w') as f:
            f.writelines(lines)

def fix_missing_imports():
    """Add missing imports."""
    print("🔧 Adding missing imports...")
    
    # Check if files need specific imports
    files_needing_imports = {
        'lib/features/leads/presentation/pages/leads_list_page.dart': [
            ("import '../../../../core/utils/debug_logger.dart';", 
             "import '../providers/filter_providers.dart' as ui_filters;"),
        ],
    }
    
    for file_path, imports in files_needing_imports.items():
        if not os.path.exists(file_path):
            continue
        
        with open(file_path, 'r') as f:
            content = f.read()
        
        for check_import, add_import in imports:
            if check_import in content and add_import not in content:
                # Add after the check import
                content = content.replace(
                    check_import,
                    f"{check_import}\n{add_import}"
                )
        
        with open(file_path, 'w') as f:
            f.write(content)

def fix_sort_state_references():
    """Fix SortState field references."""
    print("🔧 Fixing SortState field references...")
    
    file_path = 'lib/features/leads/presentation/pages/leads_list_page.dart'
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Fix sortField -> proper field mapping
        content = re.sub(
            r'sortState\.sortField',
            '_getSortField(sortState)',
            content
        )
        
        # Fix ascending field
        content = re.sub(
            r'sortState\.ascending(?!\s*\?)',
            'sortState.isAscending',
            content
        )
        
        # Add helper method if not exists
        if '_getSortField' not in content:
            # Add after class declaration
            content = re.sub(
                r'(class _LeadsListPageState extends ConsumerState<LeadsListPage>.*?\{)',
                r'''\1
  
  String? _getSortField(ui_filters.SortState sortState) {
    switch (sortState.option) {
      case ui_filters.SortOption.businessNameAsc:
      case ui_filters.SortOption.businessNameDesc:
        return 'business_name';
      case ui_filters.SortOption.createdAtAsc:
      case ui_filters.SortOption.createdAtDesc:
        return 'created_at';
      case ui_filters.SortOption.ratingAsc:
      case ui_filters.SortOption.ratingDesc:
        return 'rating';
      case ui_filters.SortOption.pagespeedAsc:
      case ui_filters.SortOption.pagespeedDesc:
        return 'pagespeed_score';
      case ui_filters.SortOption.statusAsc:
      case ui_filters.SortOption.statusDesc:
        return 'status';
    }
  }''',
                content,
                count=1
            )
        
        with open(file_path, 'w') as f:
            f.write(content)

def fix_called_today_provider():
    """Add missing calledTodayProvider."""
    print("🔧 Adding calledTodayProvider...")
    
    provider_file = 'lib/features/leads/presentation/providers/filter_providers.dart'
    if os.path.exists(provider_file):
        with open(provider_file, 'r') as f:
            content = f.read()
        
        if 'calledTodayProvider' not in content:
            # Add after other filter providers
            content = re.sub(
                r'(// Follow up filter\nfinal followUpFilterProvider.*?\);)',
                r'''\1

// Called today filter
final calledTodayProvider = StateProvider<bool>((ref) => false);''',
                content
            )
        
        with open(provider_file, 'w') as f:
            f.write(content)

def main():
    print("=" * 60)
    print("PHASE 2 COMPREHENSIVE ERROR FIX")
    print("=" * 60)
    
    # Apply all fixes
    fix_ambiguous_imports()
    fix_const_and_default_errors()
    fix_undefined_future()
    fix_missing_imports()
    fix_sort_state_references()
    fix_called_today_provider()
    
    print("\n✅ All fixes applied. Running flutter analyze...")
    
    # Run analysis
    output, errors = run_flutter_analyze()
    
    # Count results
    error_count = len(errors)
    warning_count = len(re.findall(r'^\s*warning •', output, re.MULTILINE))
    info_count = len(re.findall(r'^\s*info •', output, re.MULTILINE))
    
    print(f"\n📊 ANALYSIS RESULTS:")
    print(f"  Errors: {error_count}")
    print(f"  Warnings: {warning_count}")
    print(f"  Info: {info_count}")
    
    if error_count == 0:
        print("\n" + "=" * 60)
        print("🎉 SUCCESS: ZERO ERRORS ACHIEVED!")
        print("=" * 60)
        print("\n✨ Phase 2 is ready for completion!")
        print("\nNext steps:")
        print("  1. Update REFACTORING_PLAN.md to mark Phase 2 complete")
        print("  2. Create Phase 2 completion report")
        print("  3. Begin Phase 3: Data Layer & API Refactoring")
    else:
        print(f"\n❌ Still have {error_count} errors")
        print("\nShowing first 10 errors:")
        for error in errors[:10]:
            print(f"  {error.strip()}")
        
        # Analyze error patterns
        print("\n📊 Error pattern analysis:")
        patterns = {}
        for error in errors:
            if 'non_constant_default_value' in error:
                patterns['non_constant_default_value'] = patterns.get('non_constant_default_value', 0) + 1
            elif 'const_initialized_with_non_constant_value' in error:
                patterns['const_initialized_with_non_constant_value'] = patterns.get('const_initialized_with_non_constant_value', 0) + 1
            elif 'ambiguous_import' in error:
                patterns['ambiguous_import'] = patterns.get('ambiguous_import', 0) + 1
            elif 'undefined' in error:
                patterns['undefined'] = patterns.get('undefined', 0) + 1
        
        for pattern, count in patterns.items():
            print(f"  {pattern}: {count} errors")

if __name__ == "__main__":
    main()