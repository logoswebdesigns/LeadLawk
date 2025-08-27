// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lead_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeadModel _$LeadModelFromJson(Map<String, dynamic> json) => LeadModel(
      id: json['id'] as String,
      businessName: json['business_name'] as String,
      phone: json['phone'] as String,
      websiteUrl: json['website_url'] as String?,
      profileUrl: json['profile_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt(),
      lastReviewDate: json['last_review_date'] == null
          ? null
          : DateTime.parse(json['last_review_date'] as String),
      platformHint: json['platform_hint'] as String?,
      industry: json['industry'] as String,
      location: json['location'] as String,
      source: json['source'] as String,
      hasWebsite: json['has_website'] as bool,
      meetsRatingThreshold: json['meets_rating_threshold'] as bool,
      hasRecentReviews: json['has_recent_reviews'] as bool,
      isCandidate: json['is_candidate'] as bool,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      screenshotPath: json['screenshot_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      followUpDate: json['follow_up_date'] == null
          ? null
          : DateTime.parse(json['follow_up_date'] as String),
      timeline: (json['timeline'] as List<dynamic>?)
          ?.map(
              (e) => LeadTimelineEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LeadModelToJson(LeadModel instance) => <String, dynamic>{
      'id': instance.id,
      'business_name': instance.businessName,
      'phone': instance.phone,
      'website_url': instance.websiteUrl,
      'profile_url': instance.profileUrl,
      'rating': instance.rating,
      'review_count': instance.reviewCount,
      'last_review_date': instance.lastReviewDate?.toIso8601String(),
      'platform_hint': instance.platformHint,
      'industry': instance.industry,
      'location': instance.location,
      'source': instance.source,
      'has_website': instance.hasWebsite,
      'meets_rating_threshold': instance.meetsRatingThreshold,
      'has_recent_reviews': instance.hasRecentReviews,
      'is_candidate': instance.isCandidate,
      'status': instance.status,
      'notes': instance.notes,
      'screenshot_path': instance.screenshotPath,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'follow_up_date': instance.followUpDate?.toIso8601String(),
      'timeline': instance.timeline,
    };
