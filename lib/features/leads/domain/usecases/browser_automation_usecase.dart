import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../entities/automation_source.dart';
import '../repositories/leads_repository.dart';

class BrowserAutomationParams extends Equatable {
  final String industry;  // For backward compatibility and custom industry
  final List<String> industries;  // Multiple industries for concurrent jobs
  final String location;
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

  const BrowserAutomationParams({
    required this.industry,
    this.industries = const [],
    required this.location,
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
  });

  @override
  List<Object?> get props => [
        industry,
        industries,
        location,
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
      ];
}

class BrowserAutomationUseCase {
  final LeadsRepository repository;

  BrowserAutomationUseCase(this.repository);

  Future<Either<Failure, String>> call(BrowserAutomationParams params) async {
    return await repository.startAutomation(params);
  }
}