// Domain events for the application.
// Pattern: Domain Event Pattern - captures business events.
// Single Responsibility: Domain event definitions.

import 'package:flutter/foundation.dart';
import 'event_bus.dart';
import '../../features/leads/domain/entities/lead.dart';

// Lead Events
@immutable
class LeadCreatedEvent extends AppEvent {
  final String leadId;
  final String businessName;
  final String industry;
  final String location;
  
  LeadCreatedEvent({
    required this.leadId,
    required this.businessName,
    required this.industry,
    required this.location,
    String? userId,
  }) : super(userId: userId);
  
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'leadId': leadId,
    'businessName': businessName,
    'industry': industry,
    'location': location,
  };
}

@immutable
class LeadStatusChangedEvent extends AppEvent {
  final String leadId;
  final LeadStatus oldStatus;
  final LeadStatus newStatus;
  final String? reason;
  
  LeadStatusChangedEvent({
    required this.leadId,
    required this.oldStatus,
    required this.newStatus,
    this.reason,
    String? userId,
  }) : super(userId: userId);
  
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'leadId': leadId,
    'oldStatus': oldStatus.toString(),
    'newStatus': newStatus.toString(),
    'reason': reason,
  };
}

@immutable
class LeadUpdatedEvent extends AppEvent {
  final String leadId;
  final Map<String, dynamic> changes;
  
  LeadUpdatedEvent({
    required this.leadId,
    required this.changes,
    String? userId,
  }) : super(userId: userId);
  
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'leadId': leadId,
    'changes': changes,
  };
}

@immutable
class LeadDeletedEvent extends AppEvent {
  final String leadId;
  
  LeadDeletedEvent({
    required this.leadId,
    String? userId,
  }) : super(userId: userId);
  
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'leadId': leadId,
  };
}

// Call Events
@immutable
class CallStartedEvent extends AppEvent {
  final String leadId;
  final String phoneNumber;
  
  CallStartedEvent({
    required this.leadId,
    required this.phoneNumber,
    String? userId,
  }) : super(userId: userId);
}

@immutable
class CallEndedEvent extends AppEvent {
  final String leadId;
  final Duration duration;
  final String outcome;
  
  CallEndedEvent({
    required this.leadId,
    required this.duration,
    required this.outcome,
    String? userId,
  }) : super(userId: userId);
}

// Email Events
@immutable
class EmailSentEvent extends AppEvent {
  final String leadId;
  final String templateId;
  final String subject;
  
  EmailSentEvent({
    required this.leadId,
    required this.templateId,
    required this.subject,
    String? userId,
  }) : super(userId: userId);
}

// Timeline Events
@immutable
class TimelineEntryAddedEvent extends AppEvent {
  final String leadId;
  final String entryId;
  final String entryType;
  final String title;
  
  TimelineEntryAddedEvent({
    required this.leadId,
    required this.entryId,
    required this.entryType,
    required this.title,
    String? userId,
  }) : super(userId: userId);
}

// Job Events
@immutable
class JobStartedEvent extends AppEvent {
  final String jobId;
  final String industry;
  final String location;
  
  JobStartedEvent({
    required this.jobId,
    required this.industry,
    required this.location,
    String? userId,
  }) : super(userId: userId);
}

@immutable
class JobCompletedEvent extends AppEvent {
  final String jobId;
  final int leadsFound;
  final Duration duration;
  
  JobCompletedEvent({
    required this.jobId,
    required this.leadsFound,
    required this.duration,
    String? userId,
  }) : super(userId: userId);
}

@immutable
class JobFailedEvent extends AppEvent {
  final String jobId;
  final String error;
  
  JobFailedEvent({
    required this.jobId,
    required this.error,
    String? userId,
  }) : super(userId: userId);
}

// Navigation Events
@immutable
class PageViewedEvent extends AppEvent {
  final String pageName;
  final Map<String, dynamic>? parameters;
  
  PageViewedEvent({
    required this.pageName,
    this.parameters,
    String? userId,
  }) : super(userId: userId);
}

// Error Events
@immutable
class ErrorOccurredEvent extends AppEvent {
  final String error;
  final String? stackTrace;
  final String context;
  
  ErrorOccurredEvent({
    required this.error,
    this.stackTrace,
    required this.context,
    String? userId,
  }) : super(userId: userId);
}