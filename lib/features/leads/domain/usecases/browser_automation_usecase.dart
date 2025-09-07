import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../entities/automation_source.dart';
import '../repositories/leads_repository.dart';

class BrowserAutomationParams extends Equatable {
  final String industry;  // For backward compatibility and custom industry
  final List<String> industries;  // Multiple industries for concurrent jobs
  final String location;  // Primary location for backward compatibility
  final List<String> locations;  // Multiple cities for broader searches
  final int limit;
  final double minRating;
  final int minReviews;
  final int recentDays;
  final bool mock;
  final bool useBrowserAutomation;
  final bool useProfile;
  final bool headless;
  final AutomationSourceType sourceType;  // Which automation source to use
  final bool? requiresWebsite;  // Website filter: null = any, false = no website, true = has website
  final int? recentReviewMonths;  // Recent review filter: null = any, int = within X months
  final int? minPhotos;  // Photo count filter: null = any, int = minimum photo count
  final int? minDescriptionLength;  // Description quality filter: null = any, int = minimum chars
  final bool enablePagespeed;  // Enable automatic PageSpeed testing for leads with websites
  final int maxPagespeedScore;  // Maximum acceptable PageSpeed score (leads above this are filtered out)
  final int maxRuntimeMinutes;  // Maximum runtime in minutes before job auto-stops

  const BrowserAutomationParams({
    required this.industry,
    this.industries = const [],
    required this.location,
    this.locations = const [],
    required this.limit,
    required this.minRating,
    required this.minReviews,
    required this.recentDays,
    this.mock = false,
    this.useBrowserAutomation = true,
    this.useProfile = false,
    this.headless = true,  // Default to headless as user requested
    this.sourceType = AutomationSourceType.googleMaps,  // Default source
    this.requiresWebsite,
    this.recentReviewMonths,
    this.minPhotos,
    this.minDescriptionLength,
    this.enablePagespeed = true,  // Default to enabled for better lead qualification
    this.maxPagespeedScore = 75,  // Default threshold
    this.maxRuntimeMinutes = 15,  // Default to 15 minutes
  });

  @override
  List<Object?> get props => [
        industry,
        industries,
        location,
        locations,
        limit,
        minRating,
        minReviews,
        recentDays,
        mock,
        useBrowserAutomation,
        useProfile,
        headless,
        sourceType,
        requiresWebsite,
        recentReviewMonths,
        minPhotos,
        minDescriptionLength,
        enablePagespeed,
        maxPagespeedScore,
        maxRuntimeMinutes,
      ];
}

class BrowserAutomationUseCase {
  final LeadsRepository repository;

  BrowserAutomationUseCase(this.repository);

  Future<Either<Failure, String>> call(BrowserAutomationParams params) async {
    return await repository.startAutomation(params);
  }
}