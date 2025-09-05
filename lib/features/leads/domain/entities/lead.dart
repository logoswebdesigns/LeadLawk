import 'package:equatable/equatable.dart';
import 'lead_timeline_entry.dart';

enum LeadStatus { 
  new_, 
  viewed, 
  called,
  callbackScheduled,  // Scheduled for callback with date/time
  interested, 
  converted, 
  doNotCall,  // Do Not Call - no reason needed
  didNotConvert  // Did Not Convert - requires reason code
}

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
  final String? screenshotPath;  // Google Maps business screenshot
  final String? websiteScreenshotPath;  // Website homepage screenshot
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? followUpDate;
  final List<LeadTimelineEntry> timeline;
  
  // PageSpeed fields
  final int? pagespeedMobileScore;
  final int? pagespeedDesktopScore;
  final double? pagespeedMobilePerformance;
  final double? pagespeedDesktopPerformance;
  final double? pagespeedFirstContentfulPaint;
  final double? pagespeedLargestContentfulPaint;
  final double? pagespeedCumulativeLayoutShift;
  final double? pagespeedTotalBlockingTime;
  final double? pagespeedTimeToInteractive;
  final double? pagespeedSpeedIndex;
  final int? pagespeedAccessibilityScore;
  final int? pagespeedBestPracticesScore;
  final int? pagespeedSeoScore;
  final DateTime? pagespeedTestedAt;
  final String? pagespeedTestError;
  
  // Conversion scoring fields
  final double? conversionScore;
  final DateTime? conversionScoreCalculatedAt;
  final String? conversionScoreFactors;
  
  // Sales pitch tracking
  final String? salesPitchId;
  final String? salesPitchName;
  
  // Conversion failure tracking
  final String? conversionFailureReason;  // Reason code (e.g., 'NI', 'TE', 'COMP')
  final String? conversionFailureNotes;   // Additional notes about why they didn't convert
  final DateTime? conversionFailureDate;  // When they were marked as did not convert

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
    this.websiteScreenshotPath,
    required this.createdAt,
    required this.updatedAt,
    this.followUpDate,
    this.timeline = const [],
    this.pagespeedMobileScore,
    this.pagespeedDesktopScore,
    this.pagespeedMobilePerformance,
    this.pagespeedDesktopPerformance,
    this.pagespeedFirstContentfulPaint,
    this.pagespeedLargestContentfulPaint,
    this.pagespeedCumulativeLayoutShift,
    this.pagespeedTotalBlockingTime,
    this.pagespeedTimeToInteractive,
    this.pagespeedSpeedIndex,
    this.pagespeedAccessibilityScore,
    this.pagespeedBestPracticesScore,
    this.pagespeedSeoScore,
    this.pagespeedTestedAt,
    this.pagespeedTestError,
    this.conversionScore,
    this.conversionScoreCalculatedAt,
    this.conversionScoreFactors,
    this.salesPitchId,
    this.salesPitchName,
    this.conversionFailureReason,
    this.conversionFailureNotes,
    this.conversionFailureDate,
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
    String? websiteScreenshotPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? followUpDate,
    List<LeadTimelineEntry>? timeline,
    int? pagespeedMobileScore,
    int? pagespeedDesktopScore,
    double? pagespeedMobilePerformance,
    double? pagespeedDesktopPerformance,
    double? pagespeedFirstContentfulPaint,
    double? pagespeedLargestContentfulPaint,
    double? pagespeedCumulativeLayoutShift,
    double? pagespeedTotalBlockingTime,
    double? pagespeedTimeToInteractive,
    double? pagespeedSpeedIndex,
    int? pagespeedAccessibilityScore,
    int? pagespeedBestPracticesScore,
    int? pagespeedSeoScore,
    DateTime? pagespeedTestedAt,
    String? pagespeedTestError,
    double? conversionScore,
    DateTime? conversionScoreCalculatedAt,
    String? conversionScoreFactors,
    String? salesPitchId,
    String? salesPitchName,
    String? conversionFailureReason,
    String? conversionFailureNotes,
    DateTime? conversionFailureDate,
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
      websiteScreenshotPath: websiteScreenshotPath ?? this.websiteScreenshotPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      followUpDate: followUpDate ?? this.followUpDate,
      timeline: timeline ?? this.timeline,
      pagespeedMobileScore: pagespeedMobileScore ?? this.pagespeedMobileScore,
      pagespeedDesktopScore: pagespeedDesktopScore ?? this.pagespeedDesktopScore,
      pagespeedMobilePerformance: pagespeedMobilePerformance ?? this.pagespeedMobilePerformance,
      pagespeedDesktopPerformance: pagespeedDesktopPerformance ?? this.pagespeedDesktopPerformance,
      pagespeedFirstContentfulPaint: pagespeedFirstContentfulPaint ?? this.pagespeedFirstContentfulPaint,
      pagespeedLargestContentfulPaint: pagespeedLargestContentfulPaint ?? this.pagespeedLargestContentfulPaint,
      pagespeedCumulativeLayoutShift: pagespeedCumulativeLayoutShift ?? this.pagespeedCumulativeLayoutShift,
      pagespeedTotalBlockingTime: pagespeedTotalBlockingTime ?? this.pagespeedTotalBlockingTime,
      pagespeedTimeToInteractive: pagespeedTimeToInteractive ?? this.pagespeedTimeToInteractive,
      pagespeedSpeedIndex: pagespeedSpeedIndex ?? this.pagespeedSpeedIndex,
      pagespeedAccessibilityScore: pagespeedAccessibilityScore ?? this.pagespeedAccessibilityScore,
      pagespeedBestPracticesScore: pagespeedBestPracticesScore ?? this.pagespeedBestPracticesScore,
      pagespeedSeoScore: pagespeedSeoScore ?? this.pagespeedSeoScore,
      pagespeedTestedAt: pagespeedTestedAt ?? this.pagespeedTestedAt,
      pagespeedTestError: pagespeedTestError ?? this.pagespeedTestError,
      conversionScore: conversionScore ?? this.conversionScore,
      conversionScoreCalculatedAt: conversionScoreCalculatedAt ?? this.conversionScoreCalculatedAt,
      conversionScoreFactors: conversionScoreFactors ?? this.conversionScoreFactors,
      salesPitchId: salesPitchId ?? this.salesPitchId,
      salesPitchName: salesPitchName ?? this.salesPitchName,
      conversionFailureReason: conversionFailureReason ?? this.conversionFailureReason,
      conversionFailureNotes: conversionFailureNotes ?? this.conversionFailureNotes,
      conversionFailureDate: conversionFailureDate ?? this.conversionFailureDate,
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
        websiteScreenshotPath,
        createdAt,
        updatedAt,
        followUpDate,
        timeline,
        pagespeedMobileScore,
        pagespeedDesktopScore,
        pagespeedMobilePerformance,
        pagespeedDesktopPerformance,
        pagespeedFirstContentfulPaint,
        pagespeedLargestContentfulPaint,
        pagespeedCumulativeLayoutShift,
        pagespeedTotalBlockingTime,
        pagespeedTimeToInteractive,
        pagespeedSpeedIndex,
        pagespeedAccessibilityScore,
        pagespeedBestPracticesScore,
        pagespeedSeoScore,
        pagespeedTestedAt,
        pagespeedTestError,
        conversionScore,
        conversionScoreCalculatedAt,
        conversionScoreFactors,
        salesPitchId,
        salesPitchName,
        conversionFailureReason,
        conversionFailureNotes,
        conversionFailureDate,
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