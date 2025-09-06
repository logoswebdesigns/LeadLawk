// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobModel _$JobModelFromJson(Map<String, dynamic> json) => JobModel(
      id: json['id'] as String,
      status: json['status'] as String,
      processed: (json['processed'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      message: json['message'] as String?,
      industry: json['industry'] as String?,
      location: json['location'] as String?,
      query: json['query'] as String?,
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String?,
      totalCombinations: (json['total_combinations'] as num?)?.toInt(),
      completedCombinations: (json['completed_combinations'] as num?)?.toInt(),
      childJobs: (json['child_jobs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      parentId: json['parent_id'] as String?,
      leadsFound: (json['leads_found'] as num?)?.toInt(),
    );

Map<String, dynamic> _$JobModelToJson(JobModel instance) => <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'processed': instance.processed,
      'total': instance.total,
      'message': instance.message,
      'industry': instance.industry,
      'location': instance.location,
      'query': instance.query,
      'timestamp': instance.timestamp?.toIso8601String(),
      'type': instance.type,
      'total_combinations': instance.totalCombinations,
      'completed_combinations': instance.completedCombinations,
      'child_jobs': instance.childJobs,
      'parent_id': instance.parentId,
      'leads_found': instance.leadsFound,
    };
