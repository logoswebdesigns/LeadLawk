import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/call_log.dart';

part 'call_log_model.g.dart';

@JsonSerializable()
class CallLogModel {
  final String id;
  @JsonKey(name: 'lead_id')
  final String leadId;
  @JsonKey(name: 'start_time')
  final DateTime startTime;
  @JsonKey(name: 'end_time')
  final DateTime? endTime;
  @JsonKey(name: 'duration_seconds')
  final int? durationSeconds;
  final String outcome;
  final String? notes;
  @JsonKey(name: 'caller_name')
  final String? callerName;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  @JsonKey(name: 'is_inbound')
  final bool isInbound;
  @JsonKey(name: 'recording_url')
  final String? recordingUrl;
  final Map<String, dynamic>? metadata;

  CallLogModel({
    required this.id,
    required this.leadId,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    required this.outcome,
    this.notes,
    this.callerName,
    this.phoneNumber,
    this.isInbound = false,
    this.recordingUrl,
    this.metadata,
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) => 
      _$CallLogModelFromJson(json);
  Map<String, dynamic> toJson() => _$CallLogModelToJson(this);

  CallLog toEntity() {
    return CallLog(
      id: id,
      leadId: leadId,
      startTime: startTime,
      endTime: endTime,
      duration: durationSeconds != null 
          ? Duration(seconds: durationSeconds!) 
          : null,
      outcome: _parseCallOutcome(outcome),
      notes: notes,
      callerName: callerName,
      phoneNumber: phoneNumber,
      isInbound: isInbound,
      recordingUrl: recordingUrl,
      metadata: metadata,
    );
  }

  factory CallLogModel.fromEntity(CallLog callLog) {
    return CallLogModel(
      id: callLog.id,
      leadId: callLog.leadId,
      startTime: callLog.startTime,
      endTime: callLog.endTime,
      durationSeconds: callLog.duration?.inSeconds,
      outcome: callLog.outcome.toString().split('.').last,
      notes: callLog.notes,
      callerName: callLog.callerName,
      phoneNumber: callLog.phoneNumber,
      isInbound: callLog.isInbound,
      recordingUrl: callLog.recordingUrl,
      metadata: callLog.metadata,
    );
  }

  CallOutcome _parseCallOutcome(String outcome) {
    switch (outcome.toLowerCase()) {
      case 'answered':
        return CallOutcome.answered;
      case 'voicemail':
        return CallOutcome.voicemail;
      case 'busy':
        return CallOutcome.busy;
      case 'noanswer':
      case 'no_answer':
        return CallOutcome.noAnswer;
      case 'disconnected':
        return CallOutcome.disconnected;
      case 'interested':
        return CallOutcome.interested;
      case 'notinterested':
      case 'not_interested':
        return CallOutcome.notInterested;
      case 'callback':
        return CallOutcome.callback;
      case 'converted':
        return CallOutcome.converted;
      default:
        return CallOutcome.answered;
    }
  }
}