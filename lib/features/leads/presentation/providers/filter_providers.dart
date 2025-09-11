// Filter Providers for Lead Management
// Pattern: Provider Pattern
// SOLID: Single Responsibility - each provider manages one filter
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/filter_state.dart';

// Search filter
final searchFilterProvider = StateProvider<String>((ref) => '');

// Status filter
final statusFilterProvider = StateProvider<LeadStatus?>((ref) => null);

// Candidates only filter
final candidatesOnlyProvider = StateProvider<bool>((ref) => false);

// Has website filter
final hasWebsiteFilterProvider = StateProvider<bool?>((ref) => null);

// PageSpeed filter
final pageSpeedFilterProvider = StateProvider<int?>((ref) => null);

// Meets rating filter
final meetsRatingFilterProvider = StateProvider<bool?>((ref) => null);

// Has recent reviews filter
final hasRecentReviewsFilterProvider = StateProvider<bool?>((ref) => null);

// Follow up filter
final followUpFilterProvider = StateProvider<bool>((ref) => false);

// Called today filter
final calledTodayProvider = StateProvider<bool>((ref) => false);

// Selection mode
final isSelectionModeProvider = StateProvider<bool>((ref) => false);

// Selected leads
final selectedLeadsProvider = StateProvider<Set<String>>((ref) => {});

// Group by option
enum GroupByOption {
  none,
  status,
  industry,
  hasWebsite,
  rating,
}

final groupByProvider = StateProvider<GroupByOption>((ref) => GroupByOption.none);