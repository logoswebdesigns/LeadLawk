import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/lead.dart';
import 'lead_timeline_entry_model.dart';

part 'lead_model.g.dart';

@JsonSerializable()
class LeadModel {
  final String id;
  @JsonKey(name: 'business_name')
  final String businessName;
  final String phone;
  @JsonKey(name: 'website_url')
  final String? websiteUrl;
  @JsonKey(name: 'profile_url')
  final String? profileUrl;
  final double? rating;
  @JsonKey(name: 'review_count')
  final int? reviewCount;
  @JsonKey(name: 'last_review_date')
  final DateTime? lastReviewDate;
  @JsonKey(name: 'platform_hint')
  final String? platformHint;
  final String industry;
  final String location;
  final String source;
  @JsonKey(name: 'has_website')
  final bool hasWebsite;
  @JsonKey(name: 'meets_rating_threshold')
  final bool meetsRatingThreshold;
  @JsonKey(name: 'has_recent_reviews')
  final bool hasRecentReviews;
  @JsonKey(name: 'is_candidate')
  final bool isCandidate;
  final String status;
  final String? notes;
  @JsonKey(name: 'screenshot_path')
  final String? screenshotPath;
  @JsonKey(name: 'website_screenshot_path')
  final String? websiteScreenshotPath;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'follow_up_date')
  final DateTime? followUpDate;
  final List<LeadTimelineEntryModel>? timeline;
  
  // PageSpeed fields
  @JsonKey(name: 'pagespeed_mobile_score')
  final int? pagespeedMobileScore;
  @JsonKey(name: 'pagespeed_desktop_score')
  final int? pagespeedDesktopScore;
  @JsonKey(name: 'pagespeed_mobile_performance')
  final double? pagespeedMobilePerformance;
  @JsonKey(name: 'pagespeed_desktop_performance')
  final double? pagespeedDesktopPerformance;
  @JsonKey(name: 'pagespeed_first_contentful_paint')
  final double? pagespeedFirstContentfulPaint;
  @JsonKey(name: 'pagespeed_largest_contentful_paint')
  final double? pagespeedLargestContentfulPaint;
  @JsonKey(name: 'pagespeed_cumulative_layout_shift')
  final double? pagespeedCumulativeLayoutShift;
  @JsonKey(name: 'pagespeed_total_blocking_time')
  final double? pagespeedTotalBlockingTime;
  @JsonKey(name: 'pagespeed_time_to_interactive')
  final double? pagespeedTimeToInteractive;
  @JsonKey(name: 'pagespeed_speed_index')
  final double? pagespeedSpeedIndex;
  @JsonKey(name: 'pagespeed_accessibility_score')
  final int? pagespeedAccessibilityScore;
  @JsonKey(name: 'pagespeed_best_practices_score')
  final int? pagespeedBestPracticesScore;
  @JsonKey(name: 'pagespeed_seo_score')
  final int? pagespeedSeoScore;
  @JsonKey(name: 'pagespeed_tested_at')
  final DateTime? pagespeedTestedAt;
  @JsonKey(name: 'pagespeed_test_error')
  final String? pagespeedTestError;
  
  // Conversion scoring fields
  @JsonKey(name: 'conversion_score')
  final double? conversionScore;
  @JsonKey(name: 'conversion_score_calculated_at')
  final DateTime? conversionScoreCalculatedAt;
  @JsonKey(name: 'conversion_score_factors')
  final String? conversionScoreFactors;
  
  // Sales pitch tracking
  @JsonKey(name: 'sales_pitch_id')
  final String? salesPitchId;
  @JsonKey(name: 'sales_pitch_name')
  final String? salesPitchName;

  LeadModel({
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
    this.timeline,
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
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) =>
      _$LeadModelFromJson(json);

  Map<String, dynamic> toJson() => _$LeadModelToJson(this);

  Lead toEntity() {
    return Lead(
      id: id,
      businessName: businessName,
      phone: phone,
      websiteUrl: websiteUrl,
      profileUrl: profileUrl,
      rating: rating,
      reviewCount: reviewCount,
      lastReviewDate: lastReviewDate,
      platformHint: platformHint,
      industry: industry,
      location: location,
      source: source,
      hasWebsite: hasWebsite,
      meetsRatingThreshold: meetsRatingThreshold,
      hasRecentReviews: hasRecentReviews,
      isCandidate: isCandidate,
      status: _statusFromString(status),
      notes: notes,
      screenshotPath: screenshotPath,
      websiteScreenshotPath: websiteScreenshotPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      followUpDate: followUpDate,
      timeline: timeline?.map((entry) => entry.toEntity()).toList() ?? [],
      pagespeedMobileScore: pagespeedMobileScore,
      pagespeedDesktopScore: pagespeedDesktopScore,
      pagespeedMobilePerformance: pagespeedMobilePerformance,
      pagespeedDesktopPerformance: pagespeedDesktopPerformance,
      pagespeedFirstContentfulPaint: pagespeedFirstContentfulPaint,
      pagespeedLargestContentfulPaint: pagespeedLargestContentfulPaint,
      pagespeedCumulativeLayoutShift: pagespeedCumulativeLayoutShift,
      pagespeedTotalBlockingTime: pagespeedTotalBlockingTime,
      pagespeedTimeToInteractive: pagespeedTimeToInteractive,
      pagespeedSpeedIndex: pagespeedSpeedIndex,
      pagespeedAccessibilityScore: pagespeedAccessibilityScore,
      pagespeedBestPracticesScore: pagespeedBestPracticesScore,
      pagespeedSeoScore: pagespeedSeoScore,
      pagespeedTestedAt: pagespeedTestedAt,
      pagespeedTestError: pagespeedTestError,
      conversionScore: conversionScore,
      conversionScoreCalculatedAt: conversionScoreCalculatedAt,
      conversionScoreFactors: conversionScoreFactors,
      salesPitchId: salesPitchId,
      salesPitchName: salesPitchName,
    );
  }

  static LeadModel fromEntity(Lead lead) {
    return LeadModel(
      id: lead.id,
      businessName: lead.businessName,
      phone: lead.phone,
      websiteUrl: lead.websiteUrl,
      profileUrl: lead.profileUrl,
      rating: lead.rating,
      reviewCount: lead.reviewCount,
      lastReviewDate: lead.lastReviewDate,
      platformHint: lead.platformHint,
      industry: lead.industry,
      location: lead.location,
      source: lead.source,
      hasWebsite: lead.hasWebsite,
      meetsRatingThreshold: lead.meetsRatingThreshold,
      hasRecentReviews: lead.hasRecentReviews,
      isCandidate: lead.isCandidate,
      status: _statusToString(lead.status),
      notes: lead.notes,
      screenshotPath: lead.screenshotPath,
      websiteScreenshotPath: lead.websiteScreenshotPath,
      createdAt: lead.createdAt,
      updatedAt: lead.updatedAt,
      followUpDate: lead.followUpDate,
      timeline: lead.timeline.map((entry) => LeadTimelineEntryModel.fromEntity(entry)).toList(),
      pagespeedMobileScore: lead.pagespeedMobileScore,
      pagespeedDesktopScore: lead.pagespeedDesktopScore,
      pagespeedMobilePerformance: lead.pagespeedMobilePerformance,
      pagespeedDesktopPerformance: lead.pagespeedDesktopPerformance,
      pagespeedFirstContentfulPaint: lead.pagespeedFirstContentfulPaint,
      pagespeedLargestContentfulPaint: lead.pagespeedLargestContentfulPaint,
      pagespeedCumulativeLayoutShift: lead.pagespeedCumulativeLayoutShift,
      pagespeedTotalBlockingTime: lead.pagespeedTotalBlockingTime,
      pagespeedTimeToInteractive: lead.pagespeedTimeToInteractive,
      pagespeedSpeedIndex: lead.pagespeedSpeedIndex,
      pagespeedAccessibilityScore: lead.pagespeedAccessibilityScore,
      pagespeedBestPracticesScore: lead.pagespeedBestPracticesScore,
      pagespeedSeoScore: lead.pagespeedSeoScore,
      pagespeedTestedAt: lead.pagespeedTestedAt,
      pagespeedTestError: lead.pagespeedTestError,
      conversionScore: lead.conversionScore,
      conversionScoreCalculatedAt: lead.conversionScoreCalculatedAt,
      conversionScoreFactors: lead.conversionScoreFactors,
    );
  }

  static LeadStatus _statusFromString(String status) {
    switch (status) {
      case 'new':
        return LeadStatus.new_;
      case 'viewed':
        return LeadStatus.viewed;
      case 'called':
        return LeadStatus.called;
      case 'callbackScheduled':
      case 'callback_scheduled':
        return LeadStatus.callbackScheduled;
      case 'interested':
        return LeadStatus.interested;
      case 'converted':
        return LeadStatus.converted;
      case 'doNotCall':
      case 'dnc':
      case 'do_not_call':
        return LeadStatus.doNotCall;
      case 'didNotConvert':
      case 'did_not_convert':
        return LeadStatus.didNotConvert;
      default:
        return LeadStatus.new_;
    }
  }

  static String _statusToString(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'new';
      case LeadStatus.viewed:
        return 'viewed';
      case LeadStatus.called:
        return 'called';
      case LeadStatus.callbackScheduled:
        return 'callbackScheduled';
      case LeadStatus.interested:
        return 'interested';
      case LeadStatus.converted:
        return 'converted';
      case LeadStatus.doNotCall:
        return 'doNotCall';
      case LeadStatus.didNotConvert:
        return 'didNotConvert';
    }
  }
}