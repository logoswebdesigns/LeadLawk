#!/usr/bin/env python3
import os
import re

# Map of incorrect icon names to correct ones
ICON_FIXES = {
    'Icons.refresh.reviews': 'Icons.rate_review',
    'Icons.refresh.g_mobiledata': 'Icons.phone_android',
    'Icons.refresh.apple': 'Icons.phone_iphone',
    'Icons.refresh.campaign_outlined': 'Icons.campaign',
    'Icons.refresh.mail_lock_outlined': 'Icons.mail_lock',
    'Icons.refresh.security_outlined': 'Icons.security',
    'Icons.refresh.storage_outlined': 'Icons.storage',
    'Icons.refresh.palette_outlined': 'Icons.palette',
    'Icons.refresh.language_outlined': 'Icons.language',
    'Icons.refresh.article_outlined': 'Icons.article',
    'Icons.refresh.privacy_tip_outlined': 'Icons.privacy_tip',
    'Icons.reviews': 'Icons.rate_review',
    'Icons.g_mobiledata': 'Icons.phone_android',
    'Icons.apple': 'Icons.phone_iphone',
    'Icons.campaign_outlined': 'Icons.campaign',
    'Icons.mail_lock_outlined': 'Icons.mail_lock',
    'Icons.security_outlined': 'Icons.security',
    'Icons.storage_outlined': 'Icons.storage',
    'Icons.palette_outlined': 'Icons.palette',
    'Icons.language_outlined': 'Icons.language',
    'Icons.article_outlined': 'Icons.article',
    'Icons.privacy_tip_outlined': 'Icons.privacy_tip',
}

def fix_icons(content):
    """Fix all icon name issues"""
    for wrong, correct in ICON_FIXES.items():
        content = content.replace(wrong, correct)
    return content

def fix_file(filepath):
    """Fix specific file issues"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Fix icons
        content = fix_icons(content)
        
        # Specific file fixes
        if 'error_boundary.dart' in filepath:
            # Line 109 - remove const from Container
            content = content.replace('return const Container();', 'return Container();')
        
        if 'error_handler.dart' in filepath:
            # Line 222 - fix Duration with variable
            content = re.sub(r'duration: const Duration\([^)]*delay[^)]*\)', 
                           'duration: Duration(milliseconds: delay)', content)
        
        if 'image_optimization.dart' in filepath:
            # Line 119 - fix SizedBox with calculation
            content = re.sub(r'const SizedBox\(\s*height:\s*widget\.height\s*\*[^)]*\)',
                           lambda m: m.group(0).replace('const ', ''), content)
        
        if 'base_repository.dart' in filepath:
            # Fix default parameters - remove them
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if 'RetryPolicy? retryPolicy = ' in line:
                    lines[i] = '    RetryPolicy? retryPolicy,'
                if 'Duration? cacheTimeout = ' in line:
                    lines[i] = '    Duration? cacheTimeout,'
                if 'CircuitBreakerConfig? circuitBreaker = ' in line:
                    lines[i] = '    CircuitBreakerConfig? circuitBreaker,'
            content = '\n'.join(lines)
        
        if 'responsive_builder.dart' in filepath:
            # Fix default parameter
            content = re.sub(r'Duration transitionDuration = Duration\([^)]*\)',
                           'Duration transitionDuration = const Duration(milliseconds: 300)', content)
        
        if 'dummy_data_provider.dart' in filepath:
            # Fix const Text with interpolation
            content = re.sub(r"const Text\('([^']*\$[^']*)'", r"Text('\1'", content)
        
        if 'call_log_model.dart' in filepath:
            # Fix Duration(seconds: durationSeconds!)
            content = content.replace('Duration(seconds: durationSeconds!)', 
                                    'Duration(seconds: durationSeconds)')
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all final errors"""
    files_to_fix = [
        'lib/core/errors/error_boundary.dart',
        'lib/core/errors/error_handler.dart',
        'lib/core/performance/image_optimization.dart',
        'lib/core/repositories/base_repository.dart',
        'lib/core/responsive/responsive_builder.dart',
        'lib/features/analytics/presentation/providers/dummy_data_provider.dart',
        'lib/features/analytics/presentation/widgets/top_segments_card.dart',
        'lib/features/auth/presentation/widgets/social_login_buttons.dart',
        'lib/features/leads/data/models/call_log_model.dart',
        'lib/features/leads/presentation/pages/account_page.dart',
    ]
    
    fixed_count = 0
    for filepath in files_to_fix:
        if os.path.exists(filepath):
            if fix_file(filepath):
                print(f"Fixed: {filepath}")
                fixed_count += 1
    
    # Also process all dart files for icon fixes
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if filepath not in files_to_fix:  # Don't double-process
                    try:
                        with open(filepath, 'r', encoding='utf-8') as f:
                            content = f.read()
                        original = content
                        content = fix_icons(content)
                        if content != original:
                            with open(filepath, 'w', encoding='utf-8') as f:
                                f.write(content)
                            print(f"Fixed icons in: {filepath}")
                            fixed_count += 1
                    except Exception as e:
                        print(f"Error: {e}")
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()