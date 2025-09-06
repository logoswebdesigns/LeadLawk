// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CallLogModel _$CallLogModelFromJson(Map<String, dynamic> json) => CallLogModel(
      id: json['id'] as String,
      leadId: json['lead_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      outcome: json['outcome'] as String,
      notes: json['notes'] as String?,
      callerName: json['caller_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      isInbound: json['is_inbound'] as bool? ?? false,
      recordingUrl: json['recording_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CallLogModelToJson(CallLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lead_id': instance.leadId,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime?.toIso8601String(),
      'duration_seconds': instance.durationSeconds,
      'outcome': instance.outcome,
      'notes': instance.notes,
      'caller_name': instance.callerName,
      'phone_number': instance.phoneNumber,
      'is_inbound': instance.isInbound,
      'recording_url': instance.recordingUrl,
      'metadata': instance.metadata,
    };
