import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../../domain/entities/lead.dart';

part 'lead_timeline_entry_model.g.dart';

@JsonSerializable()
class LeadTimelineEntryModel {
  final String id;
  @JsonKey(name: 'lead_id')
  final String leadId;
  final String type;
  final String title;
  final String? description;
  @JsonKey(name: 'previous_status')
  final String? previousStatus;
  @JsonKey(name: 'new_status')
  final String? newStatus;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'follow_up_date')
  final DateTime? followUpDate;
  @JsonKey(name: 'is_completed')
  final bool isCompleted;
  @JsonKey(name: 'completed_by')
  final String? completedBy;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;

  LeadTimelineEntryModel({
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

  factory LeadTimelineEntryModel.fromJson(Map<String, dynamic> json) =>
      _$LeadTimelineEntryModelFromJson(json);

  Map<String, dynamic> toJson() => _$LeadTimelineEntryModelToJson(this);

  LeadTimelineEntry toEntity() {
    return LeadTimelineEntry(
      id: id,
      leadId: leadId,
      type: _typeFromString(type),
      title: title,
      description: description,
      previousStatus: previousStatus != null ? _statusFromString(previousStatus!) : null,
      newStatus: newStatus != null ? _statusFromString(newStatus!) : null,
      createdAt: createdAt,
      followUpDate: followUpDate,
      isCompleted: isCompleted,
      completedBy: completedBy,
      completedAt: completedAt,
    );
  }

  static LeadTimelineEntryModel fromEntity(LeadTimelineEntry entry) {
    return LeadTimelineEntryModel(
      id: entry.id,
      leadId: entry.leadId,
      type: _typeToString(entry.type),
      title: entry.title,
      description: entry.description,
      previousStatus: entry.previousStatus != null ? _statusToString(entry.previousStatus!) : null,
      newStatus: entry.newStatus != null ? _statusToString(entry.newStatus!) : null,
      createdAt: entry.createdAt,
      followUpDate: entry.followUpDate,
      isCompleted: entry.isCompleted,
      completedBy: entry.completedBy,
      completedAt: entry.completedAt,
    );
  }

  static TimelineEntryType _typeFromString(String type) {
    switch (type) {
      case 'lead_created':
        return TimelineEntryType.leadCreated;
      case 'status_change':
        return TimelineEntryType.statusChange;
      case 'note':
        return TimelineEntryType.note;
      case 'follow_up':
        return TimelineEntryType.followUp;
      case 'reminder':
        return TimelineEntryType.reminder;
      case 'phone_call':
        return TimelineEntryType.phoneCall;
      case 'email':
        return TimelineEntryType.email;
      case 'meeting':
        return TimelineEntryType.meeting;
      case 'objection_handled':
        return TimelineEntryType.objectionHandled;
      case 'decision_maker_reached':
        return TimelineEntryType.decisionMakerReached;
      case 'pain_point_discovered':
        return TimelineEntryType.painPointDiscovered;
      case 'next_steps_agreed':
        return TimelineEntryType.nextStepsAgreed;
      case 'competitor_mentioned':
        return TimelineEntryType.competitorMentioned;
      case 'budget_discussed':
        return TimelineEntryType.budgetDiscussed;
      case 'viewed_details':
        return TimelineEntryType.viewedDetails;
      case 'exported_data':
        return TimelineEntryType.exportedData;
      default:
        return TimelineEntryType.note;
    }
  }

  static String _typeToString(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.leadCreated:
        return 'lead_created';
      case TimelineEntryType.statusChange:
        return 'status_change';
      case TimelineEntryType.note:
        return 'note';
      case TimelineEntryType.followUp:
        return 'follow_up';
      case TimelineEntryType.reminder:
        return 'reminder';
      case TimelineEntryType.phoneCall:
        return 'phone_call';
      case TimelineEntryType.email:
        return 'email';
      case TimelineEntryType.meeting:
        return 'meeting';
      case TimelineEntryType.objectionHandled:
        return 'objection_handled';
      case TimelineEntryType.decisionMakerReached:
        return 'decision_maker_reached';
      case TimelineEntryType.painPointDiscovered:
        return 'pain_point_discovered';
      case TimelineEntryType.nextStepsAgreed:
        return 'next_steps_agreed';
      case TimelineEntryType.competitorMentioned:
        return 'competitor_mentioned';
      case TimelineEntryType.budgetDiscussed:
        return 'budget_discussed';
      case TimelineEntryType.viewedDetails:
        return 'viewed_details';
      case TimelineEntryType.exportedData:
        return 'exported_data';
    }
  }

  static LeadStatus _statusFromString(String status) {
    switch (status) {
      case 'new':
        return LeadStatus.new_;
      case 'viewed':
        return LeadStatus.viewed;
      case 'called':
        return LeadStatus.called;
      case 'callbackScheduled':
      case 'callback_scheduled':
        return LeadStatus.callbackScheduled;
      case 'interested':
        return LeadStatus.interested;
      case 'converted':
        return LeadStatus.converted;
      case 'doNotCall':
      case 'dnc':
      case 'do_not_call':
        return LeadStatus.doNotCall;
      case 'didNotConvert':
      case 'did_not_convert':
        return LeadStatus.didNotConvert;
      default:
        return LeadStatus.new_;
    }
  }

  static String _statusToString(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'new';
      case LeadStatus.viewed:
        return 'viewed';
      case LeadStatus.called:
        return 'called';
      case LeadStatus.callbackScheduled:
        return 'callbackScheduled';
      case LeadStatus.interested:
        return 'interested';
      case LeadStatus.converted:
        return 'converted';
      case LeadStatus.doNotCall:
        return 'doNotCall';
      case LeadStatus.didNotConvert:
        return 'didNotConvert';
    }
  }
}