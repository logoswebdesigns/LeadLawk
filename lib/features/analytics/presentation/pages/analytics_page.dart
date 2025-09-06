import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';
import '../providers/dummy_data_provider.dart';
import '../widgets/conversion_overview_card.dart';
import '../widgets/top_segments_card.dart';
import '../widgets/insights_card.dart';
import '../widgets/timeline_chart.dart';
import '../widgets/custom_comparison_card.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useDummyData = ref.watch(useDummyDataProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        title: const Text(
          'Analytics & Insights',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Dummy data toggle
          Row(
            children: [
              const Text(
                'Demo',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Switch(
                value: useDummyData,
                onChanged: (value) {
                  ref.read(useDummyDataProvider.notifier).state = value;
                },
                activeColor: Colors.amber,
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(conversionOverviewProvider);
              ref.invalidate(topSegmentsProvider);
              ref.invalidate(conversionTimelineProvider);
              ref.invalidate(actionableInsightsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversionOverviewProvider);
          ref.invalidate(topSegmentsProvider);
          ref.invalidate(conversionTimelineProvider);
          ref.invalidate(actionableInsightsProvider);
        },
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conversion Overview
              ConversionOverviewCard(),
              const SizedBox(height: 20),
              
              // Custom Comparison Analysis
              CustomComparisonCard(),
              const SizedBox(height: 20),
              
              // Actionable Insights
              InsightsCard(),
              const SizedBox(height: 20),
              
              // Conversion Timeline Chart
              TimelineChart(),
              const SizedBox(height: 20),
              
              // Top Converting Segments
              TopSegmentsCard(),
            ],
          ),
        ),
      ),
    );
  }
}