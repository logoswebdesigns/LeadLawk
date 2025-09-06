import 'package:equatable/equatable.dart';

enum CallOutcome { 
  answered, 
  voicemail, 
  busy, 
  noAnswer, 
  disconnected, 
  interested, 
  notInterested, 
  callback, 
  converted 
}

class CallLog extends Equatable {
  final String id;
  final String leadId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final CallOutcome outcome;
  final String? notes;
  final String? callerName;
  final String? phoneNumber;
  final bool isInbound;
  final String? recordingUrl;
  final Map<String, dynamic>? metadata;

  const CallLog({
    required this.id,
    required this.leadId,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.outcome,
    this.notes,
    this.callerName,
    this.phoneNumber,
    this.isInbound = false,
    this.recordingUrl,
    this.metadata,
  });

  @override
  List<Object?> get props => [
    id,
    leadId,
    startTime,
    endTime,
    duration,
    outcome,
    notes,
    callerName,
    phoneNumber,
    isInbound,
    recordingUrl,
    metadata,
  ];

  bool get isCompleted => endTime != null;

  Duration get actualDuration => 
      duration ?? (endTime?.difference(startTime) ?? Duration.zero);

  CallLog copyWith({
    String? id,
    String? leadId,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    CallOutcome? outcome,
    String? notes,
    String? callerName,
    String? phoneNumber,
    bool? isInbound,
    String? recordingUrl,
    Map<String, dynamic>? metadata,
  }) {
    return CallLog(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      outcome: outcome ?? this.outcome,
      notes: notes ?? this.notes,
      callerName: callerName ?? this.callerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isInbound: isInbound ?? this.isInbound,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      metadata: metadata ?? this.metadata,
    );
  }
}