// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lead_timeline_entry_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeadTimelineEntryModel _$LeadTimelineEntryModelFromJson(
        Map<String, dynamic> json) =>
    LeadTimelineEntryModel(
      id: json['id'] as String,
      leadId: json['lead_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      followUpDate: json['follow_up_date'] == null
          ? null
          : DateTime.parse(json['follow_up_date'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
      completedBy: json['completed_by'] as String?,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );

Map<String, dynamic> _$LeadTimelineEntryModelToJson(
        LeadTimelineEntryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lead_id': instance.leadId,
      'type': instance.type,
      'title': instance.title,
      'description': instance.description,
      'previous_status': instance.previousStatus,
      'new_status': instance.newStatus,
      'created_at': instance.createdAt.toIso8601String(),
      'follow_up_date': instance.followUpDate?.toIso8601String(),
      'is_completed': instance.isCompleted,
      'completed_by': instance.completedBy,
      'completed_at': instance.completedAt?.toIso8601String(),
    };
