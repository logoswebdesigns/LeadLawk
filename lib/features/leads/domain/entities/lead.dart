import 'package:equatable/equatable.dart';
import 'lead_timeline_entry.dart';

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
  final String? screenshotPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? followUpDate;
  final List<LeadTimelineEntry> timeline;

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
    this.screenshotPath,
    required this.createdAt,
    required this.updatedAt,
    this.followUpDate,
    this.timeline = const [],
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
    String? screenshotPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? followUpDate,
    List<LeadTimelineEntry>? timeline,
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
      screenshotPath: screenshotPath ?? this.screenshotPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      followUpDate: followUpDate ?? this.followUpDate,
      timeline: timeline ?? this.timeline,
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
        screenshotPath,
        createdAt,
        updatedAt,
        followUpDate,
        timeline,
      ];

  // Helper methods
  bool get hasUpcomingFollowUp => 
      followUpDate != null && followUpDate!.isAfter(DateTime.now());
  
  bool get hasOverdueFollowUp => 
      followUpDate != null && followUpDate!.isBefore(DateTime.now());
  
  List<LeadTimelineEntry> get upcomingFollowUps => 
      timeline.where((entry) => 
          entry.followUpDate != null && 
          entry.followUpDate!.isAfter(DateTime.now()) && 
          !entry.isCompleted
      ).toList()..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));
  
  List<LeadTimelineEntry> get overdueFollowUps => 
      timeline.where((entry) => 
          entry.followUpDate != null && 
          entry.followUpDate!.isBefore(DateTime.now()) && 
          !entry.isCompleted
      ).toList()..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

  Lead addTimelineEntry(LeadTimelineEntry entry) {
    final newTimeline = List<LeadTimelineEntry>.from(timeline)..add(entry);
    return copyWith(
      timeline: newTimeline,
      updatedAt: DateTime.now(),
    );
  }

  Lead updateTimelineEntry(LeadTimelineEntry updatedEntry) {
    final newTimeline = timeline.map((entry) => 
        entry.id == updatedEntry.id ? updatedEntry : entry
    ).toList();
    return copyWith(
      timeline: newTimeline,
      updatedAt: DateTime.now(),
    );
  }
}