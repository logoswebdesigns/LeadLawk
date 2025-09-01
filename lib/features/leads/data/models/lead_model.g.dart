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
      websiteScreenshotPath: json['website_screenshot_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      followUpDate: json['follow_up_date'] == null
          ? null
          : DateTime.parse(json['follow_up_date'] as String),
      timeline: (json['timeline'] as List<dynamic>?)
          ?.map(
              (e) => LeadTimelineEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagespeedMobileScore: (json['pagespeed_mobile_score'] as num?)?.toInt(),
      pagespeedDesktopScore: (json['pagespeed_desktop_score'] as num?)?.toInt(),
      pagespeedMobilePerformance:
          (json['pagespeed_mobile_performance'] as num?)?.toDouble(),
      pagespeedDesktopPerformance:
          (json['pagespeed_desktop_performance'] as num?)?.toDouble(),
      pagespeedFirstContentfulPaint:
          (json['pagespeed_first_contentful_paint'] as num?)?.toDouble(),
      pagespeedLargestContentfulPaint:
          (json['pagespeed_largest_contentful_paint'] as num?)?.toDouble(),
      pagespeedCumulativeLayoutShift:
          (json['pagespeed_cumulative_layout_shift'] as num?)?.toDouble(),
      pagespeedTotalBlockingTime:
          (json['pagespeed_total_blocking_time'] as num?)?.toDouble(),
      pagespeedTimeToInteractive:
          (json['pagespeed_time_to_interactive'] as num?)?.toDouble(),
      pagespeedSpeedIndex: (json['pagespeed_speed_index'] as num?)?.toDouble(),
      pagespeedAccessibilityScore:
          (json['pagespeed_accessibility_score'] as num?)?.toInt(),
      pagespeedBestPracticesScore:
          (json['pagespeed_best_practices_score'] as num?)?.toInt(),
      pagespeedSeoScore: (json['pagespeed_seo_score'] as num?)?.toInt(),
      pagespeedTestedAt: json['pagespeed_tested_at'] == null
          ? null
          : DateTime.parse(json['pagespeed_tested_at'] as String),
      pagespeedTestError: json['pagespeed_test_error'] as String?,
      conversionScore: (json['conversion_score'] as num?)?.toDouble(),
      conversionScoreCalculatedAt: json['conversion_score_calculated_at'] ==
              null
          ? null
          : DateTime.parse(json['conversion_score_calculated_at'] as String),
      conversionScoreFactors: json['conversion_score_factors'] as String?,
      salesPitchId: json['sales_pitch_id'] as String?,
      salesPitchName: json['sales_pitch_name'] as String?,
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
      'website_screenshot_path': instance.websiteScreenshotPath,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'follow_up_date': instance.followUpDate?.toIso8601String(),
      'timeline': instance.timeline,
      'pagespeed_mobile_score': instance.pagespeedMobileScore,
      'pagespeed_desktop_score': instance.pagespeedDesktopScore,
      'pagespeed_mobile_performance': instance.pagespeedMobilePerformance,
      'pagespeed_desktop_performance': instance.pagespeedDesktopPerformance,
      'pagespeed_first_contentful_paint':
          instance.pagespeedFirstContentfulPaint,
      'pagespeed_largest_contentful_paint':
          instance.pagespeedLargestContentfulPaint,
      'pagespeed_cumulative_layout_shift':
          instance.pagespeedCumulativeLayoutShift,
      'pagespeed_total_blocking_time': instance.pagespeedTotalBlockingTime,
      'pagespeed_time_to_interactive': instance.pagespeedTimeToInteractive,
      'pagespeed_speed_index': instance.pagespeedSpeedIndex,
      'pagespeed_accessibility_score': instance.pagespeedAccessibilityScore,
      'pagespeed_best_practices_score': instance.pagespeedBestPracticesScore,
      'pagespeed_seo_score': instance.pagespeedSeoScore,
      'pagespeed_tested_at': instance.pagespeedTestedAt?.toIso8601String(),
      'pagespeed_test_error': instance.pagespeedTestError,
      'conversion_score': instance.conversionScore,
      'conversion_score_calculated_at':
          instance.conversionScoreCalculatedAt?.toIso8601String(),
      'conversion_score_factors': instance.conversionScoreFactors,
      'sales_pitch_id': instance.salesPitchId,
      'sales_pitch_name': instance.salesPitchName,
    };
