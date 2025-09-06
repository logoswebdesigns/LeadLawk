#!/usr/bin/env python3
import os
import re

def fix_all_icons_refresh(content):
    """Fix all Icons.refresh. patterns"""
    icons_to_fix = [
        'business', 'location_on', 'people', 'star', 'close', 'error', 
        'warning', 'info', 'check_circle', 'phone', 'email', 'web',
        'attach_money', 'trending_up', 'schedule', 'done', 'cancel',
        'delete', 'edit', 'save', 'add', 'remove', 'search', 'filter_list',
        'sort', 'visibility', 'visibility_off', 'lock', 'lock_open',
        'settings', 'help', 'feedback', 'share', 'download', 'upload',
        'copy', 'paste', 'undo', 'redo', 'home', 'dashboard', 'analytics',
        'assessment', 'assignment', 'folder', 'description', 'note',
        'bookmark', 'label', 'category', 'tag', 'flag', 'priority_high',
        'notifications', 'notifications_off', 'alarm', 'timer', 'event',
        'today', 'date_range', 'access_time', 'history', 'restore',
        'backup', 'cloud', 'cloud_upload', 'cloud_download', 'sync',
        'refresh', 'cached', 'autorenew', 'update', 'upgrade'
    ]
    
    for icon in icons_to_fix:
        content = content.replace(f'Icons.refresh.{icon}', f'Icons.{icon}')
    
    return content

def fix_default_parameters(content):
    """Fix default parameter values that need const"""
    patterns = [
        # Duration parameters
        (r'Duration (\w+) = Duration\(', r'Duration \1 = const Duration('),
        # RetryPolicy parameters
        (r'RetryPolicy\? (\w+) = RetryPolicy\.', r'RetryPolicy? \1 = const RetryPolicy().'),
        # CircuitBreakerConfig parameters
        (r'CircuitBreakerConfig\? (\w+) = CircuitBreakerConfig\.', r'CircuitBreakerConfig? \1 = const CircuitBreakerConfig().'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_const_issues(content):
    """Fix const issues with interpolation and calculations"""
    # Remove const from Text widgets with interpolation
    content = re.sub(r"const Text\('([^']*\$[^']*)'", r"Text('\1'", content)
    content = re.sub(r'const Text\("([^"]*\$[^"]*)"', r'Text("\1"', content)
    
    # Remove const from SizedBox with calculations
    content = re.sub(r'const SizedBox\(\s*height:\s*[^,\)]*[\*\/\+\-][^,\)]*\)', 
                     lambda m: m.group(0).replace('const ', ''), content)
    content = re.sub(r'const SizedBox\(\s*width:\s*[^,\)]*[\*\/\+\-][^,\)]*\)', 
                     lambda m: m.group(0).replace('const ', ''), content)
    
    # Fix SizedBox.shrink()
    content = content.replace('const SizedBox.shrink()', 'SizedBox.shrink()')
    
    return content

def fix_specific_files(filepath, content):
    """Fix specific file issues"""
    if 'error_boundary.dart' in filepath:
        # Remove const from ErrorDisplay constructor calls
        content = re.sub(r'return const ErrorDisplay\(', 'return ErrorDisplay(', content)
    
    if 'error_handler.dart' in filepath:
        # Fix Duration with variable
        content = content.replace('duration: const Duration(\n            milliseconds: delay',
                                'duration: Duration(\n            milliseconds: delay')
    
    if 'lazy_list.dart' in filepath:
        # Fix SizedBox with dynamic values
        content = re.sub(r'const SizedBox\(\s*height:\s*totalHeight', 
                        'SizedBox(\n        height: totalHeight', content)
        content = re.sub(r'const SizedBox\(\s*height:\s*startIndex', 
                        'SizedBox(\n        height: startIndex', content)
        content = re.sub(r'const SizedBox\(\s*height:\s*\(widget', 
                        'SizedBox(\n                      height: (widget', content)
    
    if 'image_optimization.dart' in filepath:
        # Fix SizedBox with calculations
        content = re.sub(r'const SizedBox\(\s*height:\s*widget\.height\s*\*\s*0\.7',
                        'SizedBox(height: widget.height * 0.7', content)
    
    if 'base_repository.dart' in filepath:
        # Fix default parameters
        content = content.replace('RetryPolicy? retryPolicy = RetryPolicy.defaultPolicy',
                                'RetryPolicy? retryPolicy')
        content = content.replace('Duration? cacheTimeout = Duration(minutes: 5)',
                                'Duration? cacheTimeout = const Duration(minutes: 5)')
        content = content.replace('CircuitBreakerConfig? circuitBreaker = CircuitBreakerConfig.defaultConfig',
                                'CircuitBreakerConfig? circuitBreaker')
    
    if 'retry_decorator.dart' in filepath:
        content = content.replace('RetryPolicy defaultRetryPolicy = RetryPolicy.defaultPolicy',
                                'RetryPolicy defaultRetryPolicy = const RetryPolicy()')
        content = content.replace('Duration defaultTimeout = Duration(seconds: 30)',
                                'Duration defaultTimeout = const Duration(seconds: 30)')
    
    if 'simple_cached_repository.dart' in filepath:
        # Fix Duration default parameter
        content = content.replace('Duration cacheTtl = Duration(minutes: 5)',
                                'Duration cacheTtl = const Duration(minutes: 5)')
    
    return content

def process_file(filepath):
    """Process a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Apply fixes
        content = fix_all_icons_refresh(content)
        content = fix_default_parameters(content)
        content = fix_const_issues(content)
        content = fix_specific_files(filepath, content)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all remaining errors"""
    fixed_count = 0
    
    # Process all Dart files
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    for root, dirs, files in os.walk('test'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    print(f"Fixed: {filepath}")
                    fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()