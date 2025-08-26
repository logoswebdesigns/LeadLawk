import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/usecases/browser_automation_usecase.dart';

class AutomationFormState {
  final String industry;
  final String location;
  final int limit;
  final double minRating;
  final int minReviews;
  final int recentDays;
  final bool isAdvancedExpanded;
  final bool isCustomIndustry;
  final bool useMockData;
  final bool? useBrowserAutomation;
  final bool? useProfile;
  final bool? headless;
  final bool? requiresWebsite;
  final int? recentReviewMonths;
  final int? minPhotos;
  final int? minDescriptionLength;

  AutomationFormState({
    this.industry = '',
    this.location = '',
    this.limit = 50,
    this.minRating = 4.0,
    this.minReviews = 3,
    this.recentDays = 365,
    this.isAdvancedExpanded = false,
    this.isCustomIndustry = false,
    this.useMockData = false,
    this.useBrowserAutomation = true,  // Default to browser automation
    this.useProfile = false,
    this.headless = true,  // Default to headless for better performance
    this.requiresWebsite,  // null = any, true = required, false = not required
    this.recentReviewMonths,  // null = any, int = within X months
    this.minPhotos,  // null = any, int = minimum photo count
    this.minDescriptionLength,  // null = any, int = minimum description chars
  });

  AutomationFormState copyWith({
    String? industry,
    String? location,
    int? limit,
    double? minRating,
    int? minReviews,
    int? recentDays,
    bool? isAdvancedExpanded,
    bool? isCustomIndustry,
    bool? useMockData,
    bool? useBrowserAutomation,
    bool? useProfile,
    bool? headless,
    bool? requiresWebsite,
    int? recentReviewMonths,
    int? minPhotos,
    int? minDescriptionLength,
  }) {
    return AutomationFormState(
      industry: industry ?? this.industry,
      location: location ?? this.location,
      limit: limit ?? this.limit,
      minRating: minRating ?? this.minRating,
      minReviews: minReviews ?? this.minReviews,
      recentDays: recentDays ?? this.recentDays,
      isAdvancedExpanded: isAdvancedExpanded ?? this.isAdvancedExpanded,
      isCustomIndustry: isCustomIndustry ?? this.isCustomIndustry,
      useMockData: useMockData ?? this.useMockData,
      useBrowserAutomation: useBrowserAutomation ?? this.useBrowserAutomation,
      useProfile: useProfile ?? this.useProfile,
      headless: headless ?? this.headless,
      requiresWebsite: requiresWebsite ?? this.requiresWebsite,
      recentReviewMonths: recentReviewMonths ?? this.recentReviewMonths,
      minPhotos: minPhotos ?? this.minPhotos,
      minDescriptionLength: minDescriptionLength ?? this.minDescriptionLength,
    );
  }

  BrowserAutomationParams toParams() {
    return BrowserAutomationParams(
      industry: industry.toLowerCase(),
      location: location,
      limit: limit,
      minRating: minRating,
      minReviews: minReviews,
      recentDays: recentDays,
      mock: useMockData,
      useBrowserAutomation: useBrowserAutomation ?? true,
      useProfile: useProfile ?? false,
      headless: headless ?? false,
      requiresWebsite: requiresWebsite,
      recentReviewMonths: recentReviewMonths,
      minPhotos: minPhotos,
      minDescriptionLength: minDescriptionLength,
    );
  }
}

class AutomationFormNotifier extends StateNotifier<AutomationFormState> {
  final SharedPreferences prefs;

  AutomationFormNotifier(this.prefs) : super(AutomationFormState()) {
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
    // When setting to 'custom', mark as custom but don't update the industry value yet
    if (industry == 'custom') {
      state = state.copyWith(
        isCustomIndustry: true,
        // Keep the existing industry value if it's already a custom value
        industry: state.isCustomIndustry ? state.industry : '',
      );
    } else {
      // For preset industries or custom values being typed
      state = state.copyWith(
        industry: industry,
        isCustomIndustry: state.isCustomIndustry && industry != 'custom',
      );
    }
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

  void toggleMockData() {
    state = state.copyWith(useMockData: !state.useMockData);
  }

  void setUseBrowserAutomation(bool value) {
    state = state.copyWith(useBrowserAutomation: value);
  }

  void setUseProfile(bool value) {
    state = state.copyWith(useProfile: value);
  }

  void setHeadless(bool value) {
    state = state.copyWith(headless: value);
  }

  void setRequiresWebsite(bool? value) {
    state = state.copyWith(requiresWebsite: value);
  }

  void setRecentReviewMonths(int? value) {
    state = state.copyWith(recentReviewMonths: value);
  }

  void setMinPhotos(int? value) {
    state = state.copyWith(minPhotos: value);
  }

  void setMinDescriptionLength(int? value) {
    state = state.copyWith(minDescriptionLength: value);
  }
}

final automationFormProvider =
    StateNotifierProvider<AutomationFormNotifier, AutomationFormState>((ref) {
  throw UnimplementedError('Must override with SharedPreferences');
});