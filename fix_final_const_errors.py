#!/usr/bin/env python3
import os
import re

def fix_file_issues(filepath):
    """Fix specific issues in files"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Fix Duration default parameters - needs const
        if 'retry_decorator.dart' in filepath:
            content = content.replace('Duration timeout = Duration(seconds: 30)', 
                                    'Duration timeout = const Duration(seconds: 30)')
        
        if 'event_replay.dart' in filepath:
            content = content.replace('Duration maxAge = Duration(hours: 24)',
                                    'Duration maxAge = const Duration(hours: 24)')
            content = content.replace('Duration delay = Duration(milliseconds: 100)',
                                    'Duration delay = const Duration(milliseconds: 100)')
            content = content.replace('Duration timeout = Duration(seconds: 30)',
                                    'Duration timeout = const Duration(seconds: 30)')
        
        if 'health_check.dart' in filepath:
            content = content.replace('Duration defaultTimeout = Duration(seconds: 5)',
                                    'Duration defaultTimeout = const Duration(seconds: 5)')
        
        if 'metrics_collector.dart' in filepath:
            content = content.replace('Duration aggregationWindow = Duration(minutes: 1)',
                                    'Duration aggregationWindow = const Duration(minutes: 1)')
        
        # Fix error_boundary.dart ErrorDisplay constructor
        if 'error_boundary.dart' in filepath:
            # Remove const from ErrorDisplay constructor call
            content = content.replace('} catch (e) {\n      return const ErrorDisplay(',
                                    '} catch (e) {\n      return ErrorDisplay(')
            # Fix Icons.refresh -> Icons.close for dismiss button
            content = content.replace('icon: const Icon(Icons.refresh),\n              onPressed: onDismiss,',
                                    'icon: const Icon(Icons.close),\n              onPressed: onDismiss,')
        
        # Fix error_handler.dart Duration issue
        if 'error_handler.dart' in filepath:
            content = content.replace('const Duration(milliseconds: delay)',
                                    'Duration(milliseconds: delay)')
        
        # Fix code_splitting.dart
        if 'code_splitting.dart' in filepath:
            content = content.replace('child: const Text(\'Error loading module: ${snapshot.error}\')',
                                    'child: Text(\'Error loading module: ${snapshot.error}\')')
        
        # Fix image_optimization.dart
        if 'image_optimization.dart' in filepath:
            # Remove const from methods with calculations
            content = re.sub(r'const SizedBox\(\s*height:\s*(\w+\.height\s*\*\s*[\d.]+)\)',
                           r'SizedBox(height: \1)', content)
        
        # Fix lazy_list.dart
        if 'lazy_list.dart' in filepath:
            # Fix SizedBox with dynamic height calculations
            content = content.replace('const SizedBox(\n        height: totalHeight)',
                                    'SizedBox(\n        height: totalHeight)')
            content = content.replace('const SizedBox(\n        height: startIndex * widget.itemHeight)',
                                    'SizedBox(\n        height: startIndex * widget.itemHeight)')
            content = content.replace('const SizedBox(\n                      height: (widget.itemCount - endIndex) * widget.itemHeight,',
                                    'SizedBox(\n                      height: (widget.itemCount - endIndex) * widget.itemHeight,')
            content = content.replace('const SizedBox(\n        height: widget.itemHeight,',
                                    'SizedBox(\n        height: widget.itemHeight,')
        
        # Fix performance_monitor.dart
        if 'performance_monitor.dart' in filepath:
            # Remove const from expressions with calculations
            content = content.replace('const Text(\'FPS: ${_metrics!.frameMetrics.averageFps.toStringAsFixed(1)}\')',
                                    'Text(\'FPS: ${_metrics!.frameMetrics.averageFps.toStringAsFixed(1)}\')')
            content = content.replace('const Text(\'Dropped: ${_metrics!.frameMetrics.droppedFrames}\')',
                                    'Text(\'Dropped: ${_metrics!.frameMetrics.droppedFrames}\')')
            content = content.replace('const Text(\'Memory: ${(_metrics!.memoryUsage / (1024 * 1024)).toStringAsFixed(1)} MB\')',
                                    'Text(\'Memory: ${(_metrics!.memoryUsage / (1024 * 1024)).toStringAsFixed(1)} MB\')')
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix final const errors"""
    fixed_count = 0
    
    # Specific files with errors
    files_to_fix = [
        'lib/core/data/retry_decorator.dart',
        'lib/core/errors/error_boundary.dart',
        'lib/core/errors/error_handler.dart',
        'lib/core/events/event_replay.dart',
        'lib/core/monitoring/health_check.dart',
        'lib/core/monitoring/metrics_collector.dart',
        'lib/core/performance/code_splitting.dart',
        'lib/core/performance/image_optimization.dart',
        'lib/core/performance/lazy_list.dart',
        'lib/core/performance/performance_monitor.dart',
    ]
    
    for filepath in files_to_fix:
        if os.path.exists(filepath):
            if fix_file_issues(filepath):
                print(f"Fixed: {filepath}")
                fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()