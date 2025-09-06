import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../../domain/repositories/leads_repository.dart';
import 'job_provider.dart';

final timelineServiceProvider = Provider<TimelineService>((ref) {
  final repository = ref.watch(leadsRepositoryProvider);
  return TimelineService(repository);
});

class TimelineService {
  final LeadsRepository _repository;

  TimelineService(this._repository);

  Future<void> addTimelineEntry({
    required String leadId,
    required TimelineEntryType entryType,
    required String content,
    DateTime? followUpDate,
  }) async {
    final entryData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'leadId': leadId,
      'entryType': entryType.toString().split('.').last,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
      'followUpDate': followUpDate?.toIso8601String(),
    };

    final result = await _repository.addTimelineEntry(leadId, entryData);
    result.fold(
      (failure) => throw Exception(failure.message),
      (_) => null,
    );
  }

  Future<Lead?> updateTimelineEntry({
    required String leadId,
    required String entryId,
    required String content,
    DateTime? followUpDate,
  }) async {
    final updatedEntry = LeadTimelineEntry(
      id: entryId,
      leadId: leadId,
      title: content,
      type: TimelineEntryType.note,
      createdAt: DateTime.now(),
      followUpDate: followUpDate,
    );

    final result = await _repository.updateTimelineEntry(leadId, updatedEntry);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (lead) => lead,
    );
  }

  Future<void> deleteTimelineEntry({
    required String leadId,
    required String entryId,
  }) async {
    // Repository doesn't have deleteTimelineEntry, would need to be added
    // For now, throw unimplemented
    throw UnimplementedError('deleteTimelineEntry not yet implemented in repository');
  }

  List<LeadTimelineEntry> getSortedTimelineEntries(Lead lead) {
    final entries = List<LeadTimelineEntry>.from(lead.timeline);
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  List<LeadTimelineEntry> filterEntriesByType(
    List<LeadTimelineEntry> entries,
    Set<TimelineEntryType> types,
  ) {
    if (types.isEmpty) return entries;
    return entries.where((entry) => types.contains(entry.type)).toList();
  }

  List<LeadTimelineEntry> filterEntriesByDateRange(
    List<LeadTimelineEntry> entries,
    DateTime start,
    DateTime end,
  ) {
    return entries.where((entry) {
      return entry.createdAt.isAfter(start) && entry.createdAt.isBefore(end);
    }).toList();
  }

  LeadTimelineEntry? getNextFollowUp(Lead lead) {
    final now = DateTime.now();
    final followUps = lead.timeline
        .where((entry) => 
          entry.followUpDate != null && 
          entry.followUpDate!.isAfter(now))
        .toList();
    
    if (followUps.isEmpty) return null;
    
    followUps.sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));
    return followUps.first;
  }

  Map<TimelineEntryType, int> getEntryTypeStatistics(Lead lead) {
    final stats = <TimelineEntryType, int>{};
    
    for (final entry in lead.timeline) {
      stats[entry.type] = (stats[entry.type] ?? 0) + 1;
    }
    
    return stats;
  }
}