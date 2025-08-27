import 'package:equatable/equatable.dart';
import 'lead.dart';

enum TimelineEntryType { 
  leadCreated,
  statusChange, 
  note, 
  followUp, 
  reminder,
  phoneCall,
  email,
  meeting
}

class LeadTimelineEntry extends Equatable {
  final String id;
  final String leadId;
  final TimelineEntryType type;
  final String title;
  final String? description;
  final LeadStatus? previousStatus;
  final LeadStatus? newStatus;
  final DateTime createdAt;
  final DateTime? followUpDate;
  final bool isCompleted;
  final String? completedBy;
  final DateTime? completedAt;

  const LeadTimelineEntry({
    required this.id,
    required this.leadId,
    required this.type,
    required this.title,
    this.description,
    this.previousStatus,
    this.newStatus,
    required this.createdAt,
    this.followUpDate,
    this.isCompleted = false,
    this.completedBy,
    this.completedAt,
  });

  LeadTimelineEntry copyWith({
    String? id,
    String? leadId,
    TimelineEntryType? type,
    String? title,
    String? description,
    LeadStatus? previousStatus,
    LeadStatus? newStatus,
    DateTime? createdAt,
    DateTime? followUpDate,
    bool? isCompleted,
    String? completedBy,
    DateTime? completedAt,
  }) {
    return LeadTimelineEntry(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      previousStatus: previousStatus ?? this.previousStatus,
      newStatus: newStatus ?? this.newStatus,
      createdAt: createdAt ?? this.createdAt,
      followUpDate: followUpDate ?? this.followUpDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        leadId,
        type,
        title,
        description,
        previousStatus,
        newStatus,
        createdAt,
        followUpDate,
        isCompleted,
        completedBy,
        completedAt,
      ];
}