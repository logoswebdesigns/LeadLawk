import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/analytics_models.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../../leads/presentation/providers/job_provider.dart';
import 'dummy_data_provider.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AnalyticsRepository(dio);
});

final conversionOverviewProvider = FutureProvider<ConversionOverview>((ref) async {
  final useDummy = ref.watch(useDummyDataProvider);
  if (useDummy) {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate loading
    return DummyDataGenerator.getDummyOverview();
  }
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getOverview();
});

final topSegmentsProvider = FutureProvider<TopSegments>((ref) async {
  final useDummy = ref.watch(useDummyDataProvider);
  if (useDummy) {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate loading
    return DummyDataGenerator.getDummySegments();
  }
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getTopSegments();
});

final conversionTimelineProvider = FutureProvider<List<ConversionTimeline>>((ref) async {
  final useDummy = ref.watch(useDummyDataProvider);
  if (useDummy) {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate loading
    return DummyDataGenerator.getDummyTimeline();
  }
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getTimeline(days: 30);
});

final actionableInsightsProvider = FutureProvider<List<ActionableInsight>>((ref) async {
  final useDummy = ref.watch(useDummyDataProvider);
  if (useDummy) {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate loading
    return DummyDataGenerator.getDummyInsights();
  }
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getInsights();
});

final customComparisonProvider = FutureProvider.family<Map<String, dynamic>, ({String primary, String secondary})>((ref, params) async {
  final useDummy = ref.watch(useDummyDataProvider);
  
  // Generate comparison data
  if (params.primary == 'Website Quality' && params.secondary == 'Conversion Rate') {
    return {
      'correlation': 0.72,
      'insights': [
        'Businesses with poor-quality websites show 125% higher conversion rates than those without websites',
        'Modern, professional websites correlate with 60% lower conversion rates',
        'Outdated website designs (5+ years old) are prime conversion targets',
      ],
      'dataPoints': List.generate(50, (i) => {
        'websiteQuality': i % 3 == 0 ? 'none' : i % 3 == 1 ? 'poor' : 'good',
        'conversionRate': i % 3 == 0 ? 0.12 : i % 3 == 1 ? 0.18 : 0.08,
      }),
    };
  }
  
  // Generic comparison
  return {
    'correlation': useDummy ? 0.45 : 0.0,
    'insights': useDummy ? [
      'Moderate correlation detected between ${params.primary} and ${params.secondary}',
      'Higher ${params.primary} values tend to correlate with increased ${params.secondary}',
    ] : [],
    'dataPoints': useDummy ? List.generate(20, (i) => {
      'primary': i * 1.5,
      'secondary': i * 0.8 + (i % 3),
    }) : [],
  };
});

// Selected time range for timeline
final timelineRangeProvider = StateProvider<int>((ref) => 30);