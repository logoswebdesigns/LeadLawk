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
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'follow_up_date')
  final DateTime? followUpDate;
  final List<LeadTimelineEntryModel>? timeline;

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
    required this.createdAt,
    required this.updatedAt,
    this.followUpDate,
    this.timeline,
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
      createdAt: createdAt,
      updatedAt: updatedAt,
      followUpDate: followUpDate,
      timeline: timeline?.map((entry) => entry.toEntity()).toList() ?? [],
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
      createdAt: lead.createdAt,
      updatedAt: lead.updatedAt,
      followUpDate: lead.followUpDate,
      timeline: lead.timeline.map((entry) => LeadTimelineEntryModel.fromEntity(entry)).toList(),
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
      case 'interested':
        return LeadStatus.interested;
      case 'converted':
        return LeadStatus.converted;
      case 'dnc':
        return LeadStatus.dnc;
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
      case LeadStatus.interested:
        return 'interested';
      case LeadStatus.converted:
        return 'converted';
      case LeadStatus.dnc:
        return 'dnc';
    }
  }
}