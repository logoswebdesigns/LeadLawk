// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversionOverview _$ConversionOverviewFromJson(Map<String, dynamic> json) =>
    ConversionOverview(
      totalLeads: (json['totalLeads'] as num).toInt(),
      converted: (json['converted'] as num).toInt(),
      interested: (json['interested'] as num).toInt(),
      called: (json['called'] as num).toInt(),
      dnc: (json['dnc'] as num).toInt(),
      newLeads: (json['new'] as num).toInt(),
      conversionRate: (json['conversionRate'] as num).toDouble(),
      interestRate: (json['interestRate'] as num).toDouble(),
      contactRate: (json['contactRate'] as num).toDouble(),
    );

Map<String, dynamic> _$ConversionOverviewToJson(ConversionOverview instance) =>
    <String, dynamic>{
      'totalLeads': instance.totalLeads,
      'converted': instance.converted,
      'interested': instance.interested,
      'called': instance.called,
      'dnc': instance.dnc,
      'new': instance.newLeads,
      'conversionRate': instance.conversionRate,
      'interestRate': instance.interestRate,
      'contactRate': instance.contactRate,
    };

SegmentPerformance _$SegmentPerformanceFromJson(Map<String, dynamic> json) =>
    SegmentPerformance(
      industry: json['industry'] as String?,
      location: json['location'] as String?,
      ratingBand: json['ratingBand'] as String?,
      reviewBand: json['reviewBand'] as String?,
      totalLeads: (json['totalLeads'] as num).toInt(),
      converted: (json['converted'] as num).toInt(),
      interested: (json['interested'] as num).toInt(),
      conversionRate: (json['conversionRate'] as num).toDouble(),
      interestRate: (json['interestRate'] as num).toDouble(),
      successScore: (json['successScore'] as num).toDouble(),
    );

Map<String, dynamic> _$SegmentPerformanceToJson(SegmentPerformance instance) =>
    <String, dynamic>{
      'industry': instance.industry,
      'location': instance.location,
      'ratingBand': instance.ratingBand,
      'reviewBand': instance.reviewBand,
      'totalLeads': instance.totalLeads,
      'converted': instance.converted,
      'interested': instance.interested,
      'conversionRate': instance.conversionRate,
      'interestRate': instance.interestRate,
      'successScore': instance.successScore,
    };

TopSegments _$TopSegmentsFromJson(Map<String, dynamic> json) => TopSegments(
      topIndustries: (json['topIndustries'] as List<dynamic>)
          .map((e) => SegmentPerformance.fromJson(e as Map<String, dynamic>))
          .toList(),
      topLocations: (json['topLocations'] as List<dynamic>)
          .map((e) => SegmentPerformance.fromJson(e as Map<String, dynamic>))
          .toList(),
      ratingPerformance: (json['ratingPerformance'] as List<dynamic>)
          .map((e) => SegmentPerformance.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviewPerformance: (json['reviewPerformance'] as List<dynamic>)
          .map((e) => SegmentPerformance.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TopSegmentsToJson(TopSegments instance) =>
    <String, dynamic>{
      'topIndustries': instance.topIndustries,
      'topLocations': instance.topLocations,
      'ratingPerformance': instance.ratingPerformance,
      'reviewPerformance': instance.reviewPerformance,
    };

ConversionTimeline _$ConversionTimelineFromJson(Map<String, dynamic> json) =>
    ConversionTimeline(
      date: json['date'] as String,
      conversions: (json['conversions'] as num).toInt(),
      newLeads: (json['newLeads'] as num).toInt(),
    );

Map<String, dynamic> _$ConversionTimelineToJson(ConversionTimeline instance) =>
    <String, dynamic>{
      'date': instance.date,
      'conversions': instance.conversions,
      'newLeads': instance.newLeads,
    };

ActionableInsight _$ActionableInsightFromJson(Map<String, dynamic> json) =>
    ActionableInsight(
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      action: json['action'] as String,
      impact: json['impact'] as String,
    );

Map<String, dynamic> _$ActionableInsightToJson(ActionableInsight instance) =>
    <String, dynamic>{
      'type': instance.type,
      'title': instance.title,
      'description': instance.description,
      'action': instance.action,
      'impact': instance.impact,
    };
