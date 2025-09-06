// Performance tests for identifying bottlenecks.
// Pattern: Performance Testing - bottleneck identification.

import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/performance/performance_monitor.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';

void main() {
  group('Data Processing Performance', () {
    test('large list parsing performance', () {
      final monitor = PerformanceMonitor();
      
      // Create large dataset
      final jsonList = List.generate(10000, (i) => {
        'id': 'lead_$i',
        'business_name': 'Business $i',
        'phone': '555-${i.toString().padLeft(4, '0')}',
        'status': 'NEW',
        'rating': 4.5,
        'review_count': i,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Measure parsing time
      monitor.startTimer('parse_10k_leads');
      
      final leads = jsonList.map((json) => LeadModel.fromJson(json)).toList();
      
      final duration = monitor.endTimer('parse_10k_leads');
      
      expect(leads.length, equals(10000));
      expect(
        duration!.inMilliseconds,
        lessThan(1000), // Should parse in under 1 second
        reason: 'Parsing 10k leads should be fast',
      );
    });
    
    test('filtering performance on large dataset', () {
      final monitor = PerformanceMonitor();
      
      // Create test data
      final leads = List.generate(10000, (i) => LeadModel(
        id: 'lead_$i',
        businessName: 'Business $i',
        phone: '555-${i.toString().padLeft(4, '0')}',
        status: i % 3 == 0 ? 'CALLED' : 'NEW',
        rating: (i % 5).toDouble(),
        reviewCount: i,
        industry: 'Tech',
        location: 'City $i',
        source: 'test',
        hasWebsite: i % 2 == 0,
        meetsRatingThreshold: i % 5 >= 4,
        hasRecentReviews: true,
        isCandidate: i % 3 == 0,
        createdAt: DateTime.now().subtract(Duration(days: i)),
        updatedAt: DateTime.now(),
      ));
      
      // Test multiple filter operations
      monitor.startTimer('filter_by_status');
      final contacted = leads.where((l) => l.status == 'CALLED').toList();
      final statusDuration = monitor.endTimer('filter_by_status');
      
      monitor.startTimer('filter_by_rating');
      final highRated = leads.where((l) => (l.rating ?? 0) >= 4).toList();
      final ratingDuration = monitor.endTimer('filter_by_rating');
      
      monitor.startTimer('complex_filter');
      final complex = leads.where((l) => 
        l.status == 'CALLED' &&
        (l.rating ?? 0) >= 4 &&
        l.reviewCount! > 100
      ).toList();
      final complexDuration = monitor.endTimer('complex_filter');
      
      // Verify performance
      expect(statusDuration!.inMilliseconds, lessThan(50));
      expect(ratingDuration!.inMilliseconds, lessThan(50));
      expect(complexDuration!.inMilliseconds, lessThan(100));
      
      // Verify correctness
      expect(contacted.length, greaterThan(0));
      expect(highRated.length, greaterThan(0));
      expect(complex.length, greaterThan(0));
    });
    
    test('sorting performance on large dataset', () {
      final monitor = PerformanceMonitor();
      
      // Create unsorted data
      final leads = List.generate(10000, (i) => LeadModel(
        id: 'lead_$i',
        businessName: 'Business ${10000 - i}',
        phone: '555-${i.toString().padLeft(4, '0')}',
        status: 'NEW',
        rating: (i % 100) / 20,
        reviewCount: (i * 7) % 1000,
        industry: 'Tech',
        location: 'City',
        source: 'test',
        hasWebsite: false,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        isCandidate: false,
        createdAt: DateTime.now().subtract(Duration(days: (i * 13) % 365)),
        updatedAt: DateTime.now(),
      ));
      
      // Test different sort operations
      monitor.startTimer('sort_by_name');
      final sortedByName = List.from(leads)
        ..sort((a, b) => a.businessName.compareTo(b.businessName));
      final nameDuration = monitor.endTimer('sort_by_name');
      
      monitor.startTimer('sort_by_rating');
      final sortedByRating = List<Lead>.from(leads)
        ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      final ratingDuration = monitor.endTimer('sort_by_rating');
      
      monitor.startTimer('sort_by_date');
      final sortedByDate = List<Lead>.from(leads)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final dateDuration = monitor.endTimer('sort_by_date');
      
      // Verify performance
      expect(nameDuration!.inMilliseconds, lessThan(200));
      expect(ratingDuration!.inMilliseconds, lessThan(200));
      expect(dateDuration!.inMilliseconds, lessThan(200));
      
      // Verify sorting worked
      expect(sortedByName.first.businessName, equals('Business 1'));
      expect(sortedByName.last.businessName, equals('Business 9999'));
      expect(sortedByRating.length, equals(10000));
      expect(sortedByDate.length, equals(10000));
    });
  });
  
  group('Memory Performance', () {
    test('memory efficient data structures', () {
      final beforeMemory = DateTime.now().microsecondsSinceEpoch;
      
      // Create large data structure
      final Map<String, List<LeadModel>> groupedLeads = {};
      
      for (int i = 0; i < 100; i++) {
        final category = 'category_${i % 10}';
        groupedLeads.putIfAbsent(category, () => []).addAll(
          List.generate(100, (j) => LeadModel(
            id: 'lead_${i}_$j',
            businessName: 'Business ${i}_$j',
            phone: '555-0000',
            status: 'NEW',
            industry: 'Tech',
            location: 'City',
            source: 'test',
            hasWebsite: false,
            meetsRatingThreshold: false,
            hasRecentReviews: false,
            isCandidate: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ))
        );
      }
      
      final afterMemory = DateTime.now().microsecondsSinceEpoch;
      final timeTaken = afterMemory - beforeMemory;
      
      // Verify structure created efficiently
      expect(groupedLeads.length, equals(10));
      expect(groupedLeads.values.every((list) => list.length == 1000), isTrue);
      expect(timeTaken, lessThan(1000000)); // Less than 1 second
    });
    
    test('collection operations performance', () {
      final monitor = PerformanceMonitor();
      final testData = List.generate(10000, (i) => i);
      
      // Map operation
      monitor.startTimer('map_operation');
      final mapped = testData.map((i) => i * 2).toList();
      final mapDuration = monitor.endTimer('map_operation');
      
      // Filter operation
      monitor.startTimer('filter_operation');
      final filtered = testData.where((i) => i % 2 == 0).toList();
      final filterDuration = monitor.endTimer('filter_operation');
      
      // Reduce operation
      monitor.startTimer('reduce_operation');
      final sum = testData.reduce((a, b) => a + b);
      final reduceDuration = monitor.endTimer('reduce_operation');
      
      // Combined operations
      monitor.startTimer('combined_operations');
      final result = testData
          .where((i) => i % 2 == 0)
          .map((i) => i * 2)
          .take(1000)
          .toList();
      final combinedDuration = monitor.endTimer('combined_operations');
      
      // Verify performance
      expect(mapDuration!.inMilliseconds, lessThan(50));
      expect(filterDuration!.inMilliseconds, lessThan(50));
      expect(reduceDuration!.inMilliseconds, lessThan(50));
      expect(combinedDuration!.inMilliseconds, lessThan(50));
      
      // Verify correctness
      expect(mapped.length, equals(10000));
      expect(filtered.length, equals(5000));
      expect(sum, equals(49995000));
      expect(result.length, equals(1000));
    });
  });
  
  group('Async Operations Performance', () {
    test('parallel vs sequential processing', () async {
      final monitor = PerformanceMonitor();
      
      // Simulate async operations
      Future<int> asyncOperation(int value) async {
        await Future.delayed(Duration(milliseconds: 10));
        return value * 2;
      }
      
      final inputs = List.generate(100, (i) => i);
      
      // Sequential processing
      monitor.startTimer('sequential_processing');
      final sequentialResults = <int>[];
      for (final input in inputs) {
        sequentialResults.add(await asyncOperation(input));
      }
      final sequentialDuration = monitor.endTimer('sequential_processing');
      
      // Parallel processing
      monitor.startTimer('parallel_processing');
      final parallelResults = await Future.wait(
        inputs.map((i) => asyncOperation(i))
      );
      final parallelDuration = monitor.endTimer('parallel_processing');
      
      // Verify parallel is faster
      expect(
        parallelDuration!.inMilliseconds,
        lessThan(sequentialDuration!.inMilliseconds / 2),
        reason: 'Parallel processing should be significantly faster',
      );
      
      // Verify same results
      expect(parallelResults, equals(sequentialResults));
    });
    
    test('batch processing performance', () async {
      final monitor = PerformanceMonitor();
      
      // Process in batches
      Future<List<int>> processBatch(List<int> batch) async {
        await Future.delayed(Duration(milliseconds: 50));
        return batch.map((i) => i * 2).toList();
      }
      
      final data = List.generate(1000, (i) => i);
      const batchSize = 100;
      
      monitor.startTimer('batch_processing');
      
      final results = <int>[];
      for (int i = 0; i < data.length; i += batchSize) {
        final end = (i + batchSize < data.length) ? i + batchSize : data.length;
        final batch = data.sublist(i, end);
        results.addAll(await processBatch(batch));
      }
      
      final duration = monitor.endTimer('batch_processing');
      
      expect(results.length, equals(1000));
      expect(
        duration!.inMilliseconds,
        lessThan(600), // Should complete in ~500ms (10 batches * 50ms)
        reason: 'Batch processing should be efficient',
      );
    });
  });
}