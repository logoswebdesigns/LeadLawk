import 'package:equatable/equatable.dart';

enum AutomationSourceType {
  googleMaps,
  nebraskaLLC,
  linkedIn,
  yelp,
  custom,
}

class AutomationSource extends Equatable {
  final AutomationSourceType type;
  final String name;
  final String description;
  final bool requiresAuth;
  final bool supportsHeadless;
  final Map<String, dynamic> defaultSettings;

  const AutomationSource({
    required this.type,
    required this.name,
    required this.description,
    this.requiresAuth = false,
    this.supportsHeadless = true,
    this.defaultSettings = const {},
  });

  @override
  List<Object?> get props => [type, name, description, requiresAuth, supportsHeadless, defaultSettings];

  // Predefined sources
  static const googleMaps = AutomationSource(
    type: AutomationSourceType.googleMaps,
    name: 'Google Maps',
    description: 'Find businesses on Google Maps without websites',
    requiresAuth: false,
    supportsHeadless: true,
    defaultSettings: {
      'minRating': 4.0,
      'minReviews': 3,
      'findNoWebsite': true,
    },
  );

  static const nebraskaLLC = AutomationSource(
    type: AutomationSourceType.nebraskaLLC,
    name: 'Nebraska LLC Registry',
    description: 'Search Nebraska business registrations',
    requiresAuth: false,
    supportsHeadless: true,
    defaultSettings: {
      'searchNewBusinesses': true,
      'daysBack': 30,
    },
  );

  static const linkedIn = AutomationSource(
    type: AutomationSourceType.linkedIn,
    name: 'LinkedIn',
    description: 'Find business contacts on LinkedIn',
    requiresAuth: true,
    supportsHeadless: false,
    defaultSettings: {
      'searchByTitle': true,
      'searchByCompany': true,
    },
  );

  static const List<AutomationSource> availableSources = [
    googleMaps,
    nebraskaLLC,
    linkedIn,
  ];
}