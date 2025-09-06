import 'package:flutter/material.dart';
import '../../../domain/entities/lead_timeline_entry.dart';

class TimelineColorScheme {
  static Color getEntryColor(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.leadCreated:
        return const Color(0xFF6E7781);
      case TimelineEntryType.statusChange:
        return const Color(0xFF0969DA);
      case TimelineEntryType.note:
        return const Color(0xFF8B949E);
      case TimelineEntryType.followUp:
        return const Color(0xFFFB8500);
      case TimelineEntryType.reminder:
        return const Color(0xFF8250DF);
      case TimelineEntryType.phoneCall:
        return const Color(0xFF1F883D);
      case TimelineEntryType.email:
        return const Color(0xFF0969DA);
      case TimelineEntryType.meeting:
        return const Color(0xFF0969DA);
      case TimelineEntryType.objectionHandled:
        return const Color(0xFFDA3633);
      case TimelineEntryType.decisionMakerReached:
        return const Color(0xFF1F883D);
      case TimelineEntryType.painPointDiscovered:
        return const Color(0xFFFB8500);
      case TimelineEntryType.nextStepsAgreed:
        return const Color(0xFF1F883D);
      case TimelineEntryType.competitorMentioned:
        return const Color(0xFF8250DF);
      case TimelineEntryType.budgetDiscussed:
        return const Color(0xFF0969DA);
      case TimelineEntryType.viewedDetails:
        return const Color(0xFF6E7781);
      case TimelineEntryType.exportedData:
        return const Color(0xFF6E7781);
    }
  }

  static Color getBackgroundColor(TimelineEntryType type) {
    final color = getEntryColor(type);
    return color.withValues(alpha: 0.1);
  }

  static Color getBorderColor(TimelineEntryType type) {
    final color = getEntryColor(type);
    return color.withValues(alpha: 0.3);
  }
}