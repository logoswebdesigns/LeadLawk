import 'package:intl/intl.dart';
import '../../../domain/entities/lead_timeline_entry.dart';

class GitHubFormatter {
  static final _fullFormat = DateFormat('MMM d, yyyy at h:mm a');

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  static String formatFullDate(DateTime date) {
    return _fullFormat.format(date);
  }

  static String formatContent(LeadTimelineEntry entry) {
    if (entry.title.isEmpty && entry.description == null) {
      return _getDefaultContent(entry.type);
    }
    return entry.description ?? entry.title;
  }

  static String _getDefaultContent(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.leadCreated:
        return 'Lead was created';
      case TimelineEntryType.statusChange:
        return 'Status was changed';
      case TimelineEntryType.phoneCall:
        return 'Phone call was made';
      case TimelineEntryType.email:
        return 'Email was sent';
      case TimelineEntryType.meeting:
        return 'Meeting was scheduled';
      case TimelineEntryType.viewedDetails:
        return 'Lead details were viewed';
      case TimelineEntryType.exportedData:
        return 'Lead data was exported';
      default:
        return '';
    }
  }

  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}