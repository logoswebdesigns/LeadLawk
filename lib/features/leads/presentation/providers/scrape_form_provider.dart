import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/usecases/run_scrape_usecase.dart';

class ScrapeFormState {
  final String industry;
  final String location;
  final int limit;
  final double minRating;
  final int minReviews;
  final int recentDays;
  final bool isAdvancedExpanded;
  final bool isCustomIndustry;

  ScrapeFormState({
    this.industry = '',
    this.location = '',
    this.limit = 50,
    this.minRating = 4.0,
    this.minReviews = 3,
    this.recentDays = 365,
    this.isAdvancedExpanded = false,
    this.isCustomIndustry = false,
  });

  ScrapeFormState copyWith({
    String? industry,
    String? location,
    int? limit,
    double? minRating,
    int? minReviews,
    int? recentDays,
    bool? isAdvancedExpanded,
    bool? isCustomIndustry,
  }) {
    return ScrapeFormState(
      industry: industry ?? this.industry,
      location: location ?? this.location,
      limit: limit ?? this.limit,
      minRating: minRating ?? this.minRating,
      minReviews: minReviews ?? this.minReviews,
      recentDays: recentDays ?? this.recentDays,
      isAdvancedExpanded: isAdvancedExpanded ?? this.isAdvancedExpanded,
      isCustomIndustry: isCustomIndustry ?? this.isCustomIndustry,
    );
  }

  RunScrapeParams toParams() {
    return RunScrapeParams(
      industry: industry.toLowerCase(),
      location: location,
      limit: limit,
      minRating: minRating,
      minReviews: minReviews,
      recentDays: recentDays,
    );
  }
}

class ScrapeFormNotifier extends StateNotifier<ScrapeFormState> {
  final SharedPreferences prefs;

  ScrapeFormNotifier(this.prefs) : super(ScrapeFormState()) {
    _loadPreferences();
  }

  void _loadPreferences() {
    state = state.copyWith(
      industry: prefs.getString('last_industry') ?? '',
      location: prefs.getString('last_location') ?? '',
      limit: prefs.getInt('last_limit') ?? 50,
      minRating: prefs.getDouble('last_min_rating') ?? 4.0,
      minReviews: prefs.getInt('last_min_reviews') ?? 3,
      recentDays: prefs.getInt('last_recent_days') ?? 365,
    );
  }

  Future<void> _savePreferences() async {
    await prefs.setString('last_industry', state.industry);
    await prefs.setString('last_location', state.location);
    await prefs.setInt('last_limit', state.limit);
    await prefs.setDouble('last_min_rating', state.minRating);
    await prefs.setInt('last_min_reviews', state.minReviews);
    await prefs.setInt('last_recent_days', state.recentDays);
  }

  void setIndustry(String industry) {
    state = state.copyWith(
      industry: industry,
      isCustomIndustry: industry == 'custom',
    );
    _savePreferences();
  }

  void setLocation(String location) {
    state = state.copyWith(location: location);
    _savePreferences();
  }

  void setLimit(int limit) {
    state = state.copyWith(limit: limit.clamp(1, 200));
    _savePreferences();
  }

  void setMinRating(double rating) {
    state = state.copyWith(minRating: rating.clamp(0.0, 5.0));
    _savePreferences();
  }

  void setMinReviews(int reviews) {
    state = state.copyWith(minReviews: reviews);
    _savePreferences();
  }

  void setRecentDays(int days) {
    state = state.copyWith(recentDays: days);
    _savePreferences();
  }

  void toggleAdvanced() {
    state = state.copyWith(isAdvancedExpanded: !state.isAdvancedExpanded);
  }
}

final scrapeFormProvider =
    StateNotifierProvider<ScrapeFormNotifier, ScrapeFormState>((ref) {
  throw UnimplementedError('Must override with SharedPreferences');
});