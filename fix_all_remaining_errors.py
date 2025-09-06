#!/usr/bin/env python3
import os
import re

def fix_file(filepath):
    """Fix all errors in a file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Fix performance_monitor.dart
        if 'performance_monitor.dart' in filepath:
            content = content.replace("const Text('FPS: ${_metrics!.frameMetrics.fps.toStringAsFixed(1)}')", 
                                    "Text('FPS: ${_metrics!.frameMetrics.fps.toStringAsFixed(1)}')")
            content = content.replace("const Text('Dropped: ${_metrics!.frameMetrics.droppedFramePercentage.toStringAsFixed(1)}%')",
                                    "Text('Dropped: ${_metrics!.frameMetrics.droppedFramePercentage.toStringAsFixed(1)}%')")
            content = content.replace("const Text('Memory: ${_metrics!.memoryMetrics.currentUsage ~/ 1024 ~/ 1024}MB')",
                                    "Text('Memory: ${_metrics!.memoryMetrics.currentUsage ~/ 1024 ~/ 1024}MB')")
            content = content.replace("const Text('${e.key}: ${e.value.averageTime.inMilliseconds}ms')",
                                    "Text('${e.key}: ${e.value.averageTime.inMilliseconds}ms')")
        
        # Fix event_replay.dart
        if 'event_replay.dart' in filepath:
            content = content.replace('Duration maxAge = Duration(hours: 24)',
                                    'Duration maxAge = const Duration(hours: 24)')
            content = content.replace('Duration delay = Duration(milliseconds: 100)',
                                    'Duration delay = const Duration(milliseconds: 100)')
            content = content.replace('Duration timeout = Duration(seconds: 30)',
                                    'Duration timeout = const Duration(seconds: 30)')
        
        # Fix health_check.dart
        if 'health_check.dart' in filepath:
            content = content.replace('Duration defaultTimeout = Duration(seconds: 5)',
                                    'Duration defaultTimeout = const Duration(seconds: 5)')
        
        # Fix metrics_collector.dart
        if 'metrics_collector.dart' in filepath:
            content = content.replace('Duration aggregationWindow = Duration(minutes: 1)',
                                    'Duration aggregationWindow = const Duration(minutes: 1)')
        
        # Fix base_repository.dart
        if 'base_repository.dart' in filepath:
            content = content.replace('RetryPolicy? retryPolicy = RetryPolicy.defaultPolicy',
                                    'RetryPolicy? retryPolicy = const RetryPolicy()')
            content = content.replace('Duration? cacheTimeout = Duration(minutes: 5)',
                                    'Duration? cacheTimeout = const Duration(minutes: 5)')
            content = content.replace('CircuitBreakerConfig? circuitBreaker = CircuitBreakerConfig.defaultConfig',
                                    'CircuitBreakerConfig? circuitBreaker = const CircuitBreakerConfig()')
        
        # Fix circuit_breaker_decorator.dart
        if 'circuit_breaker_decorator.dart' in filepath:
            content = content.replace('Duration timeout = Duration(seconds: 30)',
                                    'Duration timeout = const Duration(seconds: 30)')
        
        # Fix retry_decorator.dart
        if 'retry_decorator.dart' in filepath:
            content = content.replace('RetryPolicy defaultRetryPolicy = RetryPolicy.defaultPolicy',
                                    'RetryPolicy defaultRetryPolicy = const RetryPolicy()')
            content = content.replace('Duration defaultTimeout = Duration(seconds: 30)',
                                    'Duration defaultTimeout = const Duration(seconds: 30)')
        
        # Fix error_boundary.dart
        if 'error_boundary.dart' in filepath:
            # Find the line with const ErrorDisplay and remove const
            content = re.sub(r'return const ErrorDisplay\(', 'return ErrorDisplay(', content)
        
        # Fix error_handler.dart
        if 'error_handler.dart' in filepath:
            # Fix Duration with variable
            content = content.replace('duration: const Duration(\n            milliseconds: delay',
                                    'duration: Duration(\n            milliseconds: delay')
        
        # Fix image_optimization.dart
        if 'image_optimization.dart' in filepath:
            # Fix SizedBox with calculations
            content = re.sub(r'const SizedBox\(\s*height:\s*widget\.height\s*\*\s*0\.7\s*\)',
                           'SizedBox(height: widget.height * 0.7)', content)
        
        # Fix lazy_list.dart
        if 'lazy_list.dart' in filepath:
            # Fix SizedBox with calculations
            content = content.replace('const SizedBox.shrink()', 'SizedBox.shrink()')
            content = re.sub(r'const SizedBox\(\s*height:\s*totalHeight\)',
                           'SizedBox(height: totalHeight)', content)
        
        # Fix adaptive_scaffold.dart
        if 'adaptive_scaffold.dart' in filepath:
            # Fix Icon constructor issue
            content = content.replace('icon: item,', 'icon: item.icon,')
        
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
    files_to_fix = [
        'lib/core/performance/performance_monitor.dart',
        'lib/core/events/event_replay.dart',
        'lib/core/monitoring/health_check.dart',
        'lib/core/monitoring/metrics_collector.dart',
        'lib/core/repositories/base_repository.dart',
        'lib/core/repositories/circuit_breaker_decorator.dart',
        'lib/core/repositories/retry_decorator.dart',
        'lib/core/errors/error_boundary.dart',
        'lib/core/errors/error_handler.dart',
        'lib/core/performance/image_optimization.dart',
        'lib/core/performance/lazy_list.dart',
        'lib/core/responsive/adaptive_scaffold.dart',
    ]
    
    fixed_count = 0
    for filepath in files_to_fix:
        if os.path.exists(filepath):
            if fix_file(filepath):
                print(f"Fixed: {filepath}")
                fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()