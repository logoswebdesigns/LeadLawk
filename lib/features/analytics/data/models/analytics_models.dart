import 'package:json_annotation/json_annotation.dart';

part 'analytics_models.g.dart';

@JsonSerializable()
class ConversionOverview {
  final int totalLeads;
  final int converted;
  final int interested;
  final int called;
  final int dnc;
  @JsonKey(name: 'new')
  final int newLeads;
  final double conversionRate;
  final double interestRate;
  final double contactRate;

  ConversionOverview({
    required this.totalLeads,
    required this.converted,
    required this.interested,
    required this.called,
    required this.dnc,
    required this.newLeads,
    required this.conversionRate,
    required this.interestRate,
    required this.contactRate,
  });

  factory ConversionOverview.fromJson(Map<String, dynamic> json) =>
      _$ConversionOverviewFromJson(json);

  Map<String, dynamic> toJson() => _$ConversionOverviewToJson(this);
}

@JsonSerializable()
class SegmentPerformance {
  final String? industry;
  final String? location;
  final String? ratingBand;
  final String? reviewBand;
  final int totalLeads;
  final int converted;
  final int interested;
  final double conversionRate;
  final double interestRate;
  final double successScore;

  SegmentPerformance({
    this.industry,
    this.location,
    this.ratingBand,
    this.reviewBand,
    required this.totalLeads,
    required this.converted,
    required this.interested,
    required this.conversionRate,
    required this.interestRate,
    required this.successScore,
  });

  factory SegmentPerformance.fromJson(Map<String, dynamic> json) =>
      _$SegmentPerformanceFromJson(json);

  Map<String, dynamic> toJson() => _$SegmentPerformanceToJson(this);
}

@JsonSerializable()
class TopSegments {
  final List<SegmentPerformance> topIndustries;
  final List<SegmentPerformance> topLocations;
  final List<SegmentPerformance> ratingPerformance;
  final List<SegmentPerformance> reviewPerformance;

  TopSegments({
    required this.topIndustries,
    required this.topLocations,
    required this.ratingPerformance,
    required this.reviewPerformance,
  });

  factory TopSegments.fromJson(Map<String, dynamic> json) =>
      _$TopSegmentsFromJson(json);

  Map<String, dynamic> toJson() => _$TopSegmentsToJson(this);
}

@JsonSerializable()
class ConversionTimeline {
  final String date;
  final int conversions;
  final int newLeads;

  ConversionTimeline({
    required this.date,
    required this.conversions,
    required this.newLeads,
  });

  factory ConversionTimeline.fromJson(Map<String, dynamic> json) =>
      _$ConversionTimelineFromJson(json);

  Map<String, dynamic> toJson() => _$ConversionTimelineToJson(this);
}

@JsonSerializable()
class ActionableInsight {
  final String type;
  final String title;
  final String description;
  final String action;
  final String impact;

  ActionableInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.action,
    required this.impact,
  });

  factory ActionableInsight.fromJson(Map<String, dynamic> json) =>
      _$ActionableInsightFromJson(json);

  Map<String, dynamic> toJson() => _$ActionableInsightToJson(this);
}