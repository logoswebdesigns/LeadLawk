import 'package:flutter/material.dart';
import '../../../domain/entities/lead_timeline_entry.dart';

class TimelineIconMapper {
  static IconData getEntryIcon(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.leadCreated:
        return Icons.person_add;
      case TimelineEntryType.statusChange:
        return Icons.swap_horiz;
      case TimelineEntryType.note:
        return Icons.note;
      case TimelineEntryType.followUp:
        return Icons.schedule;
      case TimelineEntryType.reminder:
        return Icons.alarm;
      case TimelineEntryType.phoneCall:
        return Icons.phone;
      case TimelineEntryType.email:
        return Icons.email;
      case TimelineEntryType.meeting:
        return Icons.calendar_today;
      case TimelineEntryType.objectionHandled:
        return Icons.block;
      case TimelineEntryType.decisionMakerReached:
        return Icons.person;
      case TimelineEntryType.painPointDiscovered:
        return Icons.lightbulb;
      case TimelineEntryType.nextStepsAgreed:
        return Icons.check_circle;
      case TimelineEntryType.competitorMentioned:
        return Icons.business;
      case TimelineEntryType.budgetDiscussed:
        return Icons.attach_money;
      case TimelineEntryType.viewedDetails:
        return Icons.visibility;
      case TimelineEntryType.exportedData:
        return Icons.download;
    }
  }

  static String getEntryLabel(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.leadCreated:
        return 'Lead Created';
      case TimelineEntryType.statusChange:
        return 'Status Change';
      case TimelineEntryType.note:
        return 'Note';
      case TimelineEntryType.followUp:
        return 'Follow Up';
      case TimelineEntryType.reminder:
        return 'Reminder';
      case TimelineEntryType.phoneCall:
        return 'Phone Call';
      case TimelineEntryType.email:
        return 'Email';
      case TimelineEntryType.meeting:
        return 'Meeting';
      case TimelineEntryType.objectionHandled:
        return 'Objection Handled';
      case TimelineEntryType.decisionMakerReached:
        return 'Decision Maker Reached';
      case TimelineEntryType.painPointDiscovered:
        return 'Pain Point';
      case TimelineEntryType.nextStepsAgreed:
        return 'Next Steps';
      case TimelineEntryType.competitorMentioned:
        return 'Competitor';
      case TimelineEntryType.budgetDiscussed:
        return 'Budget';
      case TimelineEntryType.viewedDetails:
        return 'Viewed';
      case TimelineEntryType.exportedData:
        return 'Exported';
    }
  }
}