import 'package:equatable/equatable.dart';

enum LeadStatus { new_, viewed, called, interested, converted, dnc }

class Lead extends Equatable {
  final String id;
  final String businessName;
  final String phone;
  final String? websiteUrl;
  final String? profileUrl;
  final double? rating;
  final int? reviewCount;
  final DateTime? lastReviewDate;
  final String? platformHint;
  final String industry;
  final String location;
  final String source;
  final bool hasWebsite;
  final bool meetsRatingThreshold;
  final bool hasRecentReviews;
  final bool isCandidate;
  final LeadStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lead({
    required this.id,
    required this.businessName,
    required this.phone,
    this.websiteUrl,
    this.profileUrl,
    this.rating,
    this.reviewCount,
    this.lastReviewDate,
    this.platformHint,
    required this.industry,
    required this.location,
    required this.source,
    required this.hasWebsite,
    required this.meetsRatingThreshold,
    required this.hasRecentReviews,
    required this.isCandidate,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Lead copyWith({
    String? id,
    String? businessName,
    String? phone,
    String? websiteUrl,
    String? profileUrl,
    double? rating,
    int? reviewCount,
    DateTime? lastReviewDate,
    String? platformHint,
    String? industry,
    String? location,
    String? source,
    bool? hasWebsite,
    bool? meetsRatingThreshold,
    bool? hasRecentReviews,
    bool? isCandidate,
    LeadStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      phone: phone ?? this.phone,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      profileUrl: profileUrl ?? this.profileUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      platformHint: platformHint ?? this.platformHint,
      industry: industry ?? this.industry,
      location: location ?? this.location,
      source: source ?? this.source,
      hasWebsite: hasWebsite ?? this.hasWebsite,
      meetsRatingThreshold: meetsRatingThreshold ?? this.meetsRatingThreshold,
      hasRecentReviews: hasRecentReviews ?? this.hasRecentReviews,
      isCandidate: isCandidate ?? this.isCandidate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        businessName,
        phone,
        websiteUrl,
        profileUrl,
        rating,
        reviewCount,
        lastReviewDate,
        platformHint,
        industry,
        location,
        source,
        hasWebsite,
        meetsRatingThreshold,
        hasRecentReviews,
        isCandidate,
        status,
        notes,
        createdAt,
        updatedAt,
      ];
}