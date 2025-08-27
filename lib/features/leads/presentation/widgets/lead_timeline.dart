import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../providers/job_provider.dart';

class LeadTimeline extends ConsumerStatefulWidget {
  final Lead lead;
  final Function(LeadTimelineEntry) onAddEntry;
  final Function(LeadTimelineEntry) onUpdateEntry;
  final Function(DateTime?) onSetFollowUpDate;
  final Function(Lead)? onLeadUpdated;

  const LeadTimeline({
    super.key,
    required this.lead,
    required this.onAddEntry,
    required this.onUpdateEntry,
    required this.onSetFollowUpDate,
    this.onLeadUpdated,
  });

  @override
  ConsumerState<LeadTimeline> createState() => _LeadTimelineState();
}

class _LeadTimelineState extends ConsumerState<LeadTimeline> {
  final _noteController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _editTitleController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  bool _showAddForm = false;
  TimelineEntryType _selectedType = TimelineEntryType.note;
  DateTime? _selectedFollowUpDate;
  String? _editingEntryId;
  DateTime? _editingFollowUpDate;

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _editTitleController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
  }

  Color _getEntryColor(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.leadCreated:
        return AppTheme.mediumGray;
      case TimelineEntryType.statusChange:
        return AppTheme.primaryBlue;
      case TimelineEntryType.note:
        return AppTheme.primaryGold;
      case TimelineEntryType.followUp:
        return AppTheme.warningOrange;
      case TimelineEntryType.reminder:
        return AppTheme.accentPurple;
      case TimelineEntryType.phoneCall:
        return AppTheme.successGreen;
      case TimelineEntryType.email:
        return AppTheme.primaryIndigo;
      case TimelineEntryType.meeting:
        return AppTheme.accentCyan;
    }
  }

  IconData _getEntryIcon(TimelineEntryType type) {
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
        return Icons.meeting_room;
    }
  }

  String _getEntryTypeLabel(TimelineEntryType type) {
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
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // Assume dateTime from server is UTC and convert to local
    final utc = dateTime.isUtc ? dateTime : DateTime.utc(
      dateTime.year, dateTime.month, dateTime.day,
      dateTime.hour, dateTime.minute, dateTime.second,
      dateTime.millisecond, dateTime.microsecond
    );
    final local = utc.toLocal();
    return DateFormat('MMM d, yyyy • h:mm a').format(local);
  }

  String _formatTimeOnly(DateTime dateTime) {
    // Assume dateTime from server is UTC and convert to local
    final utc = dateTime.isUtc ? dateTime : DateTime.utc(
      dateTime.year, dateTime.month, dateTime.day,
      dateTime.hour, dateTime.minute, dateTime.second,
      dateTime.millisecond, dateTime.microsecond
    );
    final local = utc.toLocal();
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDateOnly(DateTime dateTime) {
    // Assume dateTime from server is UTC and convert to local
    final utc = dateTime.isUtc ? dateTime : DateTime.utc(
      dateTime.year, dateTime.month, dateTime.day,
      dateTime.hour, dateTime.minute, dateTime.second,
      dateTime.millisecond, dateTime.microsecond
    );
    final local = utc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    
    if (date == today) {
      return 'Today';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (local.year == now.year) {
      return '${_getMonthName(local.month)} ${local.day}';
    } else {
      return '${_getMonthName(local.month)} ${local.day}, ${local.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  void _addTimelineEntry() {
    if (_titleController.text.trim().isEmpty) return;

    final entry = LeadTimelineEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      leadId: widget.lead.id,
      type: _selectedType,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      createdAt: DateTime.now(),
      followUpDate: _selectedFollowUpDate,
    );

    widget.onAddEntry(entry);
    
    // Reset form
    _titleController.clear();
    _descriptionController.clear();
    _selectedFollowUpDate = null;
    setState(() {
      _showAddForm = false;
    });
  }

  void _showAddEntryForm() {
    setState(() {
      _showAddForm = true;
    });
  }

  void _cancelAdd() {
    setState(() {
      _showAddForm = false;
      _titleController.clear();
      _descriptionController.clear();
      _selectedFollowUpDate = null;
    });
  }

  void _startEditingEntry(LeadTimelineEntry entry) {
    setState(() {
      _editingEntryId = entry.id;
      _editTitleController.text = entry.title;
      _editDescriptionController.text = entry.description ?? '';
      _editingFollowUpDate = entry.followUpDate;
      _showAddForm = false; // Hide add form if open
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingEntryId = null;
      _editTitleController.clear();
      _editDescriptionController.clear();
      _editingFollowUpDate = null;
    });
  }

  void _saveEditedEntry() async {
    final entry = widget.lead.timeline.firstWhere((e) => e.id == _editingEntryId);
    final updatedEntry = entry.copyWith(
      title: _editTitleController.text.trim().isEmpty ? entry.title : _editTitleController.text.trim(),
      description: _editDescriptionController.text.trim().isEmpty ? null : _editDescriptionController.text.trim(),
      followUpDate: _editingFollowUpDate,
    );
    
    try {
      // Update via repository which will call the new API endpoint
      final repository = ref.read(leadsRepositoryProvider);
      final result = await repository.updateTimelineEntry(widget.lead.id, updatedEntry);
      
      result.fold(
        (failure) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update timeline entry: ${failure.toString()}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        },
        (updatedLead) {
          // Update the lead state with the new data
          widget.onLeadUpdated?.call(updatedLead);
          _cancelEditing();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Timeline entry updated successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating timeline entry: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _showEditFollowUpDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _editingFollowUpDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryGold,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _editingFollowUpDate != null 
            ? TimeOfDay.fromDateTime(_editingFollowUpDate!)
            : const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primaryGold,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _editingFollowUpDate = DateTime(
            date.year, 
            date.month, 
            date.day, 
            time.hour, 
            time.minute
          );
        });
      }
    }
  }

  void _showFollowUpDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryGold,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primaryGold,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedFollowUpDate = DateTime(
            date.year, 
            date.month, 
            date.day, 
            time.hour, 
            time.minute
          );
        });
      }
    }
  }

  Widget _buildTimelineList() {
    final sortedTimeline = List<LeadTimelineEntry>.from(widget.lead.timeline)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedTimeline.length,
      itemBuilder: (context, index) {
        final entry = sortedTimeline[index];
        final isLast = index == sortedTimeline.length - 1;
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left rail with timestamp
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimeOnly(entry.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateOnly(entry.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Timeline rail with dot and connecting line
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getEntryColor(entry.type),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.backgroundDark,
                        width: 2,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 48,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.white.withOpacity(0.1),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Timeline content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: _buildTimelineEntryCard(entry),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineEntryCard(LeadTimelineEntry entry) {
    final color = _getEntryColor(entry.type);
    final isOverdue = entry.followUpDate != null && 
                      entry.followUpDate!.isBefore(DateTime.now()) && 
                      !entry.isCompleted;
    final isEditing = _editingEntryId == entry.id;

    if (isEditing) {
      return _buildEditForm(entry);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue 
              ? AppTheme.errorRed.withOpacity(0.5)
              : color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getEntryTypeLabel(entry.type),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // Edit button
              IconButton(
                onPressed: () => _startEditingEntry(entry),
                icon: const Icon(Icons.edit, size: 16),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.6),
                  padding: const EdgeInsets.all(4),
                  minimumSize: Size.zero,
                ),
                tooltip: 'Edit entry',
              ),
              if (entry.followUpDate != null && !entry.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOverdue 
                        ? AppTheme.errorRed.withOpacity(0.15)
                        : AppTheme.warningOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOverdue ? 'Overdue' : 'Scheduled',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? AppTheme.errorRed : AppTheme.warningOrange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (entry.description?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              entry.description!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (entry.followUpDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warningOrange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alarm,
                    color: AppTheme.warningOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Follow up: ${_formatDateTime(entry.followUpDate!)}',
                    style: const TextStyle(
                      color: AppTheme.warningOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (!entry.isCompleted)
                    TextButton(
                      onPressed: () {
                        final completedEntry = entry.copyWith(
                          isCompleted: true,
                          completedAt: DateTime.now(),
                        );
                        widget.onUpdateEntry(completedEntry);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.successGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Mark Done',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditForm(LeadTimelineEntry entry) {
    final color = _getEntryColor(entry.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getEntryTypeLabel(entry.type),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.edit, color: AppTheme.primaryGold, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Editing',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title Field
          TextField(
            controller: _editTitleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Title',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              hintText: 'Enter a brief title...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
            ),
            cursorColor: AppTheme.primaryGold,
          ),
          const SizedBox(height: 16),

          // Description Field
          TextField(
            controller: _editDescriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              hintText: 'Add additional details...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
            ),
            cursorColor: AppTheme.primaryGold,
          ),
          const SizedBox(height: 16),

          // Follow-up Date Selector
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showEditFollowUpDatePicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: AppTheme.warningOrange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _editingFollowUpDate == null
                              ? 'Set follow-up date (optional)'
                              : DateFormat('MMM d, yyyy • h:mm a').format(_editingFollowUpDate!),
                          style: TextStyle(
                            color: _editingFollowUpDate == null 
                                ? Colors.white.withOpacity(0.6)
                                : AppTheme.warningOrange,
                            fontWeight: _editingFollowUpDate == null 
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_editingFollowUpDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _editingFollowUpDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelEditing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.7),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveEditedEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.backgroundDark,
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedTimeline = List<LeadTimelineEntry>.from(widget.lead.timeline)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Activity Timeline',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${sortedTimeline.length}',
                style: const TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            if (!_showAddForm)
              IconButton(
                onPressed: _showAddEntryForm,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.primaryGold,
                  backgroundColor: AppTheme.primaryGold.withOpacity(0.1),
                ),
                tooltip: 'Add Timeline Entry',
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Add Entry Form
        if (_showAddForm) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryGold.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add, color: AppTheme.primaryGold, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Add Timeline Entry',
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _cancelAdd,
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Entry Type Selector
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TimelineEntryType.values.where((type) => 
                    type != TimelineEntryType.statusChange // Status changes are automatic
                  ).map((type) {
                    final isSelected = _selectedType == type;
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getEntryIcon(type),
                            size: 14,
                            color: isSelected 
                                ? AppTheme.backgroundDark 
                                : _getEntryColor(type),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getEntryTypeLabel(type),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? AppTheme.backgroundDark 
                                  : _getEntryColor(type),
                            ),
                          ),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = type;
                        });
                      },
                      backgroundColor: AppTheme.backgroundDark,
                      selectedColor: _getEntryColor(type),
                      side: BorderSide(
                        color: isSelected 
                            ? _getEntryColor(type) 
                            : _getEntryColor(type).withOpacity(0.3),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Title Field
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    hintText: 'Enter a brief title...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                  cursorColor: AppTheme.primaryGold,
                ),
                const SizedBox(height: 16),

                // Description Field
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    hintText: 'Add additional details...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                  cursorColor: AppTheme.primaryGold,
                ),
                const SizedBox(height: 16),

                // Follow-up Date Selector
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showFollowUpDatePicker,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, color: AppTheme.warningOrange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _selectedFollowUpDate == null
                                    ? 'Set follow-up date (optional)'
                                    : DateFormat('MMM d, yyyy • h:mm a').format(_selectedFollowUpDate!),
                                style: TextStyle(
                                  color: _selectedFollowUpDate == null 
                                      ? Colors.white.withOpacity(0.6)
                                      : AppTheme.warningOrange,
                                  fontWeight: _selectedFollowUpDate == null 
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedFollowUpDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedFollowUpDate = null;
                          });
                        },
                        icon: const Icon(Icons.clear, size: 20),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelAdd,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.7),
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _titleController.text.trim().isEmpty 
                            ? null 
                            : _addTimelineEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.backgroundDark,
                        ),
                        child: const Text('Add Entry'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Timeline Entries
        if (sortedTimeline.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline,
                  size: 48,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No timeline entries yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start tracking your interactions with this lead',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          _buildTimelineList(),
      ],
    );
  }
}