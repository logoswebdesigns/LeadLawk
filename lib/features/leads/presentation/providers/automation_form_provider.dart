import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/usecases/browser_automation_usecase.dart';
import '../../../../core/utils/debug_logger.dart';

class AutomationFormState {
  final String industry;
  final List<String> selectedIndustries;
  final String location;
  final List<String> selectedLocations; // Support multiple cities
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
  final bool enablePagespeed;
  final int maxPagespeedScore; // Filter leads by max PageSpeed score
  final int maxRuntimeMinutes; // Maximum runtime in minutes before job auto-stops

  AutomationFormState({
    this.industry = '',
    this.selectedIndustries = const [],
    this.location = '',
    this.selectedLocations = const [],
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
    this.recentReviewMonths = 24,  // Default to 24 months
    this.minPhotos,  // null = any, int = minimum photo count
    this.minDescriptionLength,  // null = any, int = minimum description chars
    this.enablePagespeed = true,  // Default to enabled for better lead qualification
    this.maxPagespeedScore = 75,  // Default threshold for PageSpeed filtering
    this.maxRuntimeMinutes = 15,  // Default to 15 minutes max runtime for all jobs
  });

  AutomationFormState copyWith({
    String? industry,
    List<String>? selectedIndustries,
    String? location,
    List<String>? selectedLocations,
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
    bool? enablePagespeed,
    int? maxPagespeedScore,
    int? maxRuntimeMinutes,
  }) {
    return AutomationFormState(
      industry: industry ?? this.industry,
      selectedIndustries: selectedIndustries ?? this.selectedIndustries,
      location: location ?? this.location,
      selectedLocations: selectedLocations ?? this.selectedLocations,
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
      enablePagespeed: enablePagespeed ?? this.enablePagespeed,
      maxPagespeedScore: maxPagespeedScore ?? this.maxPagespeedScore,
      maxRuntimeMinutes: maxRuntimeMinutes ?? this.maxRuntimeMinutes,
    );
  }

  BrowserAutomationParams toParams() {
    DebugLogger.websocket('🔍 Creating BrowserAutomationParams with enablePagespeed: $enablePagespeed, maxScore: $maxPagespeedScore');
    
    // Use custom industry if set, otherwise use first selected industry as fallback
    final primaryIndustry = isCustomIndustry 
        ? industry.toLowerCase()
        : selectedIndustries.isNotEmpty
            ? selectedIndustries.first.toLowerCase()
            : '';
    
    // Always use the selected industries list if it has items
    // For custom industry, still include selectedIndustries if user has selected multiple
    final List<String> industriesList = selectedIndustries.isNotEmpty
        ? selectedIndustries.map((i) => i.toLowerCase()).toList()
        : (isCustomIndustry && primaryIndustry.isNotEmpty) 
            ? [primaryIndustry]
            : [];
    
    // Use selected locations if available, otherwise fall back to single location
    final List<String> locationsList = selectedLocations.isNotEmpty
        ? selectedLocations
        : (location.isNotEmpty ? [location] : []);
    
    return BrowserAutomationParams(
      industry: primaryIndustry.isNotEmpty ? primaryIndustry : (industriesList.isNotEmpty ? industriesList.first : ''),
      industries: industriesList,
      location: locationsList.isNotEmpty ? locationsList.first : '', // Primary location for backward compatibility
      locations: locationsList, // Pass all locations
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
      enablePagespeed: enablePagespeed,
      maxPagespeedScore: maxPagespeedScore,
      maxRuntimeMinutes: maxRuntimeMinutes,
    );
  }
}

class AutomationFormNotifier extends StateNotifier<AutomationFormState> {
  final SharedPreferences prefs;

  AutomationFormNotifier(this.prefs) : super(AutomationFormState()) {
    _loadPreferences();
  }

  void _loadPreferences() {
    final savedIndustries = prefs.getStringList('selected_industries') ?? [];
    state = state.copyWith(
      industry: prefs.getString('last_industry') ?? '',
      selectedIndustries: savedIndustries,
      location: prefs.getString('last_location') ?? '',
      limit: prefs.getInt('last_limit') ?? 50,
      minRating: prefs.getDouble('last_min_rating') ?? 4.0,
      minReviews: prefs.getInt('last_min_reviews') ?? 3,
      recentDays: prefs.getInt('last_recent_days') ?? 365,
      recentReviewMonths: prefs.getInt('last_recent_review_months') ?? 24,
      maxRuntimeMinutes: prefs.getInt('last_max_runtime_minutes') ?? 15,
    );
  }

  Future<void> _savePreferences() async {
    await prefs.setString('last_industry', state.industry);
    await prefs.setStringList('selected_industries', state.selectedIndustries);
    await prefs.setString('last_location', state.location);
    await prefs.setInt('last_limit', state.limit);
    await prefs.setDouble('last_min_rating', state.minRating);
    await prefs.setInt('last_min_reviews', state.minReviews);
    await prefs.setInt('last_recent_days', state.recentDays);
    await prefs.setInt('last_max_runtime_minutes', state.maxRuntimeMinutes);
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
    state = state.copyWith(limit: limit.clamp(1, 999999)); // No practical upper limit
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

  void setEnablePagespeed(bool value) {
    DebugLogger.log('🔍 Setting enablePagespeed to: $value');
    state = state.copyWith(enablePagespeed: value);
    DebugLogger.state('🔍 State enablePagespeed is now: ${state.enablePagespeed}');
  }

  void addIndustry(String industry) {
    final updatedIndustries = List<String>.from(state.selectedIndustries);
    if (!updatedIndustries.contains(industry)) {
      updatedIndustries.add(industry);
      state = state.copyWith(selectedIndustries: updatedIndustries);
      _savePreferences();
    }
  }

  void removeIndustry(String industry) {
    final updatedIndustries = List<String>.from(state.selectedIndustries);
    updatedIndustries.remove(industry);
    state = state.copyWith(selectedIndustries: updatedIndustries);
    _savePreferences();
  }

  void setSelectedIndustries(List<String> industries) {
    state = state.copyWith(selectedIndustries: industries);
    _savePreferences();
  }

  void clearSelectedIndustries() {
    state = state.copyWith(
      selectedIndustries: [],
      isCustomIndustry: false,
      industry: '',
    );
    _savePreferences();
  }

  void clearCustomIndustry() {
    state = state.copyWith(
      isCustomIndustry: false,
      industry: '',
    );
    _savePreferences();
  }

  void addLocation(String location) {
    final updatedLocations = List<String>.from(state.selectedLocations);
    if (!updatedLocations.contains(location) && location.isNotEmpty) {
      updatedLocations.add(location);
      state = state.copyWith(selectedLocations: updatedLocations);
      _savePreferences();
    }
  }

  void removeLocation(String location) {
    final updatedLocations = List<String>.from(state.selectedLocations);
    updatedLocations.remove(location);
    state = state.copyWith(selectedLocations: updatedLocations);
    _savePreferences();
  }

  void setSelectedLocations(List<String> locations) {
    state = state.copyWith(selectedLocations: locations);
    _savePreferences();
  }

  void clearSelectedLocations() {
    state = state.copyWith(selectedLocations: []);
    _savePreferences();
  }

  void setMaxPagespeedScore(int score) {
    state = state.copyWith(maxPagespeedScore: score.clamp(0, 100));
    _savePreferences();
  }
  
  void setMaxRuntimeMinutes(int minutes) {
    state = state.copyWith(maxRuntimeMinutes: minutes.clamp(5, 60));
    _savePreferences();
  }
}

final automationFormProvider =
    StateNotifierProvider<AutomationFormNotifier, AutomationFormState>((ref) {
  throw UnimplementedError('Must override with SharedPreferences');
});