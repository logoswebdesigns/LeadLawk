import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/analytics_models.dart';

// Toggle for using dummy data
final useDummyDataProvider = StateProvider<bool>((ref) => false);

// Dummy data generators
class DummyDataGenerator {
  static ConversionOverview getDummyOverview() {
    return ConversionOverview(
      totalLeads: 247,
      converted: 42,
      interested: 68,
      called: 156,
      dnc: 12,
      newLeads: 25,
      conversionRate: 17.0,
      interestRate: 27.5,
      contactRate: 63.2,
    );
  }

  static TopSegments getDummySegments() {
    final topIndustries = [
      SegmentPerformance(
        industry: 'Plumbing',
        totalLeads: 45,
        converted: 12,
        interested: 15,
        conversionRate: 26.7,
        interestRate: 33.3,
        successScore: 43.4,
      ),
      SegmentPerformance(
        industry: 'Painting',
        totalLeads: 38,
        converted: 8,
        interested: 11,
        conversionRate: 21.1,
        interestRate: 28.9,
        successScore: 35.6,
      ),
      SegmentPerformance(
        industry: 'Electrical',
        totalLeads: 52,
        converted: 9,
        interested: 14,
        conversionRate: 17.3,
        interestRate: 26.9,
        successScore: 30.8,
      ),
      SegmentPerformance(
        industry: 'Landscaping',
        totalLeads: 29,
        converted: 5,
        interested: 8,
        conversionRate: 17.2,
        interestRate: 27.6,
        successScore: 31.0,
      ),
      SegmentPerformance(
        industry: 'HVAC',
        totalLeads: 41,
        converted: 6,
        interested: 10,
        conversionRate: 14.6,
        interestRate: 24.4,
        successScore: 26.8,
      ),
    ];

    final topLocations = [
      SegmentPerformance(
        location: 'Omaha',
        totalLeads: 87,
        converted: 18,
        interested: 26,
        conversionRate: 20.7,
        interestRate: 29.9,
        successScore: 35.7,
      ),
      SegmentPerformance(
        location: 'Papillion',
        totalLeads: 43,
        converted: 9,
        interested: 12,
        conversionRate: 20.9,
        interestRate: 27.9,
        successScore: 34.9,
      ),
      SegmentPerformance(
        location: 'La Vista',
        totalLeads: 35,
        converted: 7,
        interested: 10,
        conversionRate: 20.0,
        interestRate: 28.6,
        successScore: 34.3,
      ),
      SegmentPerformance(
        location: 'Bellevue',
        totalLeads: 48,
        converted: 8,
        interested: 13,
        conversionRate: 16.7,
        interestRate: 27.1,
        successScore: 30.3,
      ),
    ];

    final ratingPerformance = [
      SegmentPerformance(
        ratingBand: '4.5-5.0 ⭐',
        totalLeads: 78,
        converted: 18,
        interested: 25,
        conversionRate: 23.1,
        interestRate: 32.1,
        successScore: 39.2,
      ),
      SegmentPerformance(
        ratingBand: '4.0-4.5 ⭐',
        totalLeads: 92,
        converted: 19,
        interested: 27,
        conversionRate: 20.7,
        interestRate: 29.3,
        successScore: 35.4,
      ),
      SegmentPerformance(
        ratingBand: '3.5-4.0 ⭐',
        totalLeads: 54,
        converted: 5,
        interested: 11,
        conversionRate: 9.3,
        interestRate: 20.4,
        successScore: 19.5,
      ),
      SegmentPerformance(
        ratingBand: 'Below 3.5 ⭐',
        totalLeads: 23,
        converted: 0,
        interested: 5,
        conversionRate: 0.0,
        interestRate: 21.7,
        successScore: 10.9,
      ),
    ];

    final reviewPerformance = [
      SegmentPerformance(
        reviewBand: '50-99 reviews',
        totalLeads: 52,
        converted: 14,
        interested: 18,
        conversionRate: 26.9,
        interestRate: 34.6,
        successScore: 44.2,
      ),
      SegmentPerformance(
        reviewBand: '20-49 reviews',
        totalLeads: 68,
        converted: 15,
        interested: 22,
        conversionRate: 22.1,
        interestRate: 32.4,
        successScore: 38.3,
      ),
      SegmentPerformance(
        reviewBand: '100+ reviews',
        totalLeads: 34,
        converted: 7,
        interested: 10,
        conversionRate: 20.6,
        interestRate: 29.4,
        successScore: 35.3,
      ),
      SegmentPerformance(
        reviewBand: '10-19 reviews',
        totalLeads: 61,
        converted: 6,
        interested: 13,
        conversionRate: 9.8,
        interestRate: 21.3,
        successScore: 20.5,
      ),
      SegmentPerformance(
        reviewBand: 'Under 10 reviews',
        totalLeads: 32,
        converted: 0,
        interested: 5,
        conversionRate: 0.0,
        interestRate: 15.6,
        successScore: 7.8,
      ),
    ];

    return TopSegments(
      topIndustries: topIndustries,
      topLocations: topLocations,
      ratingPerformance: ratingPerformance,
      reviewPerformance: reviewPerformance,
    );
  }

  static List<ConversionTimeline> getDummyTimeline() {
    final now = DateTime.now();
    final timeline = <ConversionTimeline>[];
    
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final isWeekend = date.weekday == 6 || date.weekday == 7;
      
      // Generate realistic patterns - lower on weekends
      final baseConversions = isWeekend ? 0 : (2 + (i % 3));
      final baseNewLeads = isWeekend ? (3 + (i % 4)) : (5 + (i % 7));
      
      timeline.add(ConversionTimeline(
        date: date.toIso8601String().split('T')[0],
        conversions: baseConversions + (i % 2),
        newLeads: baseNewLeads + (i % 3),
      ));
    }
    
    return timeline;
  }

  static List<ActionableInsight> getDummyInsights() {
    return [
      ActionableInsight(
        type: 'opportunity',
        title: 'Focus on Plumbing',
        description: 'Plumbing shows 26.7% conversion rate with 45 leads',
        action: 'Prioritize Plumbing businesses in your outreach',
        impact: 'high',
      ),
      ActionableInsight(
        type: 'opportunity',
        title: 'Success in Omaha',
        description: 'Omaha area showing 20.7% conversion',
        action: 'Expand search for more businesses in Omaha',
        impact: 'high',
      ),
      ActionableInsight(
        type: 'action',
        title: '25 Untapped Leads',
        description: 'You have 25 leads that haven\'t been contacted yet',
        action: 'Start calling your newest leads',
        impact: 'high',
      ),
      ActionableInsight(
        type: 'action',
        title: '68 Warm Leads',
        description: '68 leads marked as interested need follow-up',
        action: 'Follow up with interested leads to close deals',
        impact: 'high',
      ),
      ActionableInsight(
        type: 'pattern',
        title: 'Rating Sweet Spot: 4.5-5.0 ⭐',
        description: 'Businesses with 4.5-5.0 ⭐ convert at 23.1%',
        action: 'Target businesses in this rating range',
        impact: 'medium',
      ),
      ActionableInsight(
        type: 'pattern',
        title: 'Optimal Review Count: 50-99 reviews',
        description: 'Businesses with 50-99 reviews show 44.2% success score',
        action: 'Filter searches for this review count range',
        impact: 'medium',
      ),
    ];
  }
}