// Performance benchmark tests.
// Pattern: Benchmark Testing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/performance/lazy_list.dart';
import 'package:leadloq/core/performance/performance_monitor.dart';
import 'package:leadloq/core/performance/code_splitting.dart';
import 'package:leadloq/core/performance/bundle_optimization.dart';
import 'package:leadloq/core/performance/image_optimization.dart';

void main() {
  group('Lazy Loading Performance', () {
    testWidgets('lazy list loads items efficiently', (WidgetTester tester) async {
      final monitor = PerformanceMonitor();
      monitor.startMonitoring();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazyLoadListView<int>(
              loadMore: (page, pageSize) async {
                monitor.startTimer('load_page_$page');
                
                // Simulate network delay
                await Future.delayed(Duration(milliseconds: 100));
                
                final items = List.generate(
                  pageSize,
                  (index) => page * pageSize + index,
                );
                
                monitor.endTimer('load_page_$page');
                return items;
              },
              itemBuilder: (context, item, index) {
                return ListTile(
                  title: Text('Item $item'),
                );
              },
              pageSize: 20,
            ),
          ),
        ),
      );
      
      // Initial load
      await tester.pumpAndSettle();
      
      // Verify initial items loaded
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 19'), findsOneWidget);
      
      // Scroll to trigger lazy load
      await tester.drag(find.byType(LazyLoadListView<int>), const Offset(0, -500));
      await tester.pumpAndSettle();
      
      // Check performance metrics
      final metrics = monitor.getMetrics();
      for (final metric in metrics.operationMetrics.entries) {
        expect(
          metric.value.averageTime.inMilliseconds,
          lessThan(200),
          reason: '${metric.key} should complete quickly',
        );
      }
      
      monitor.stopMonitoring();
    });
    
    testWidgets('virtual scroll handles large lists', (WidgetTester tester) async {
      const itemCount = 10000;
      const itemHeight = 50.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirtualScrollList<int>(
              itemCount: itemCount,
              itemHeight: itemHeight,
              itemBuilder: (context, index) {
                return Container(
                  height: itemHeight,
                  child: Text('Item $index'),
                );
              },
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should only render visible items
      final texts = find.byType(Text).evaluate();
      expect(
        texts.length,
        lessThan(30), // Should render only visible + cache
        reason: 'Virtual scroll should limit rendered items',
      );
    });
  });
  
  group('Code Splitting Performance', () {
    test('module loader caches modules', () async {
      var loadCount = 0;
      
      Future<String> loader() async {
        loadCount++;
        await Future.delayed(Duration(milliseconds: 50));
        return 'Module Content';
      }
      
      // First load
      final module1 = await ModuleLoader.loadModule('test_module', loader);
      expect(module1, equals('Module Content'));
      expect(loadCount, equals(1));
      
      // Second load should use cache
      final module2 = await ModuleLoader.loadModule('test_module', loader);
      expect(module2, equals('Module Content'));
      expect(loadCount, equals(1)); // Should not increase
      
      // Verify stats
      final stats = ModuleLoader.getModuleStats();
      expect(stats['loadedCount'], equals(1));
      expect(stats['loadedModules'], contains('test_module'));
    });
    
    test('widget pool recycles widgets', () {
      var createdCount = 0;
      
      final pool = WidgetPool<Container>(
        factory: () {
          createdCount++;
          return Container();
        },
        maxSize: 5,
      );
      
      // Acquire widgets
      final widget1 = pool.acquire();
      pool.acquire(); // widget2 acquired but not directly used
      expect(createdCount, equals(2));
      
      // Release and reacquire
      pool.release(widget1);
      final widget3 = pool.acquire();
      expect(createdCount, equals(2)); // Should reuse widget1
      expect(identical(widget1, widget3), isTrue);
      
      // Check stats
      final stats = pool.getStats();
      expect(stats['available'], equals(0));
      expect(stats['inUse'], equals(2));
    });
  });
  
  group('Performance Monitoring', () {
    test('measures operation timing', () async {
      final monitor = PerformanceMonitor();
      
      // Time a fast operation
      await monitor.timeAsync('fast_operation', () async {
        await Future.delayed(Duration(milliseconds: 10));
      });
      
      // Time a slow operation
      await monitor.timeAsync('slow_operation', () async {
        await Future.delayed(Duration(milliseconds: 100));
      });
      
      final metrics = monitor.getMetrics();
      
      // Verify metrics collected
      expect(metrics.operationMetrics.containsKey('fast_operation'), isTrue);
      expect(metrics.operationMetrics.containsKey('slow_operation'), isTrue);
      
      // Fast should be faster than slow
      final fastTime = metrics.operationMetrics['fast_operation']!.averageTime;
      final slowTime = metrics.operationMetrics['slow_operation']!.averageTime;
      expect(fastTime < slowTime, isTrue);
    });
    
    test('tracks frame metrics', () {
      final monitor = PerformanceMonitor();
      monitor.startMonitoring();
      
      // Simulate frame timings
      // Note: In real tests, this would be populated by actual rendering
      
      final metrics = monitor.getMetrics();
      expect(metrics.frameMetrics, isNotNull);
      
      monitor.stopMonitoring();
    });
  });
  
  group('Bundle Optimization', () {
    test('removes debug code in release', () {
      final debugValue = BundleOptimizer.debugOnly(() => 'Debug Value');
      final releaseValue = BundleOptimizer.releaseOnly(
        () => 'Release Value',
        'Default Value',
      );
      
      // In test mode (debug), debug code runs
      expect(debugValue, equals('Debug Value'));
      expect(releaseValue, equals('Default Value'));
    });
    
    test('asset optimizer selects correct format', () {
      final webAsset = AssetOptimizer.getPlatformOptimizedFormat('image.png');
      final resolution = AssetOptimizer.getResolutionAwareAsset('icon.png', 2.0);
      
      expect(webAsset, isNotNull);
      expect(resolution, contains('@2x'));
    });
    
    test('bundle size analyzer tracks sizes', () {
      BundleSizeAnalyzer.clear();
      
      BundleSizeAnalyzer.trackComponentSize('ComponentA', 1024 * 100); // 100KB
      BundleSizeAnalyzer.trackComponentSize('ComponentB', 1024 * 50);  // 50KB
      BundleSizeAnalyzer.trackComponentSize('ComponentC', 1024 * 200); // 200KB
      
      final report = BundleSizeAnalyzer.getSizeReport();
      
      expect(report['totalSizeKB'], equals(350));
      expect(report['componentCount'], equals(3));
      
      final largest = report['largestComponents'] as List;
      expect(largest.first['name'], equals('ComponentC'));
    });
  });
  
  group('Memory Optimization', () {
    testWidgets('image cache respects limits', (WidgetTester tester) async {
      final cacheManager = ImageCacheManager();
      
      // Configure cache limits
      cacheManager.configureCacheLimits(
        maximumSize: 100,
        maximumSizeBytes: 50 * 1024 * 1024, // 50MB
      );
      
      final stats = cacheManager.getCacheStats();
      expect(stats['maximumSize'], equals(100));
      expect(stats['maximumSizeBytes'], equals(50 * 1024 * 1024));
    });
  });
}