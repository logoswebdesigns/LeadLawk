import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/lead.dart';
import '../../../domain/entities/lead_timeline_entry.dart';
import '../../providers/timeline_service_provider.dart';
import 'timeline_entry_widget.dart';
import 'timeline_entry_form.dart';
import 'timeline_filter_bar.dart';
import 'timeline_statistics.dart';

class LeadTimelineRefactored extends ConsumerStatefulWidget {
  final Lead lead;
  final Function(Lead)? onLeadUpdated;

  const LeadTimelineRefactored({
    super.key,
    required this.lead,
    this.onLeadUpdated,
  });

  @override
  ConsumerState<LeadTimelineRefactored> createState() => _LeadTimelineRefactoredState();
}

class _LeadTimelineRefactoredState extends ConsumerState<LeadTimelineRefactored> {
  bool _showAddForm = false;
  bool _showStatistics = false;
  Set<TimelineEntryType> _selectedFilters = {};
  String? _editingEntryId;

  @override
  Widget build(BuildContext context) {
    final timelineService = ref.watch(timelineServiceProvider);
    final sortedEntries = timelineService.getSortedTimelineEntries(widget.lead);
    final filteredEntries = timelineService.filterEntriesByType(
      sortedEntries,
      _selectedFilters,
    );
    final statistics = timelineService.getEntryTypeStatistics(widget.lead);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        if (_showStatistics) ...[
          const SizedBox(height: 16),
          TimelineStatistics(
            lead: widget.lead,
            statistics: statistics,
          ),
        ],
        const SizedBox(height: 16),
        TimelineFilterBar(
          selectedTypes: _selectedFilters,
          onFilterChanged: (filters) {
            setState(() {
              _selectedFilters = filters;
            });
          },
        ),
        const SizedBox(height: 16),
        if (_showAddForm) ...[
          TimelineEntryForm(
            onSubmit: _handleAddEntry,
            onCancel: () {
              setState(() {
                _showAddForm = false;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: _buildTimelineList(filteredEntries),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Timeline',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                _showStatistics ? Icons.insights : Icons.insights_outlined,
                color: _showStatistics ? Theme.of(context).primaryColor : null,
              ),
              onPressed: () {
                setState(() {
                  _showStatistics = !_showStatistics;
                });
              },
              tooltip: 'Toggle Statistics',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showAddForm = !_showAddForm;
                });
              },
              icon: Icon(_showAddForm ? Icons.close : Icons.add),
              label: Text(_showAddForm ? 'Cancel' : 'Add Entry'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineList(List<LeadTimelineEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isEditing = _editingEntryId == entry.id;

        if (isEditing) {
          return TimelineEntryForm(
            initialType: entry.type,
            initialContent: entry.title,
            initialFollowUpDate: entry.followUpDate,
            onSubmit: (type, content, followUp) {
              _handleEditEntry(entry.id, content, followUp);
            },
            onCancel: () {
              setState(() {
                _editingEntryId = null;
              });
            },
          );
        }

        return TimelineEntryWidget(
          entry: entry,
          isFirst: index == 0,
          isLast: index == entries.length - 1,
          onEdit: () {
            setState(() {
              _editingEntryId = entry.id;
            });
          },
          onDelete: () => _handleDeleteEntry(entry.id),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilters.isEmpty
                ? 'No timeline entries yet'
                : 'No entries match the selected filters',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          if (_selectedFilters.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFilters = {};
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAddEntry(
    TimelineEntryType type,
    String content,
    DateTime? followUpDate,
  ) async {
    final timelineService = ref.read(timelineServiceProvider);
    
    try {
      await timelineService.addTimelineEntry(
        leadId: widget.lead.id,
        entryType: type,
        content: content,
        followUpDate: followUpDate,
      );
      
      // Need to refresh lead after adding entry
      // widget.onLeadUpdated?.call(updatedLead);
      
      setState(() {
        _showAddForm = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add entry: $e')),
        );
      }
    }
  }

  Future<void> _handleEditEntry(
    String entryId,
    String content,
    DateTime? followUpDate,
  ) async {
    final timelineService = ref.read(timelineServiceProvider);
    
    try {
      final updatedLead = await timelineService.updateTimelineEntry(
        leadId: widget.lead.id,
        entryId: entryId,
        content: content,
        followUpDate: followUpDate,
      );
      
      if (updatedLead != null) {
        widget.onLeadUpdated?.call(updatedLead);
      }
      
      setState(() {
        _editingEntryId = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update entry: $e')),
        );
      }
    }
  }

  Future<void> _handleDeleteEntry(String entryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this timeline entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final timelineService = ref.read(timelineServiceProvider);
    
    try {
      await timelineService.deleteTimelineEntry(
        leadId: widget.lead.id,
        entryId: entryId,
      );
      
      // Need to refresh lead after deleting entry
      // widget.onLeadUpdated?.call(updatedLead);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete entry: $e')),
        );
      }
    }
  }
}