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
    // GitHub Actions style: More muted, professional colors
    switch (type) {
      case TimelineEntryType.leadCreated:
        return const Color(0xFF6E7781); // GitHub gray
      case TimelineEntryType.statusChange:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.note:
        return const Color(0xFF8B949E); // Muted gray
      case TimelineEntryType.followUp:
        return const Color(0xFFFB8500); // GitHub orange
      case TimelineEntryType.reminder:
        return const Color(0xFF8250DF); // GitHub purple
      case TimelineEntryType.phoneCall:
        return const Color(0xFF1F883D); // GitHub green
      case TimelineEntryType.email:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.meeting:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.objectionHandled:
        return const Color(0xFFDA3633); // GitHub red
      case TimelineEntryType.decisionMakerReached:
        return const Color(0xFF1F883D); // GitHub green
      case TimelineEntryType.painPointDiscovered:
        return const Color(0xFFFB8500); // GitHub orange
      case TimelineEntryType.nextStepsAgreed:
        return const Color(0xFF1F883D); // GitHub green
      case TimelineEntryType.competitorMentioned:
        return const Color(0xFF8250DF); // GitHub purple
      case TimelineEntryType.budgetDiscussed:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.viewedDetails:
        return const Color(0xFF6E7781); // GitHub gray
      case TimelineEntryType.exportedData:
        return const Color(0xFF6E7781); // GitHub gray
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
      case TimelineEntryType.objectionHandled:
        return Icons.report_problem;
      case TimelineEntryType.decisionMakerReached:
        return Icons.account_circle;
      case TimelineEntryType.painPointDiscovered:
        return Icons.lightbulb;
      case TimelineEntryType.nextStepsAgreed:
        return Icons.check_circle;
      case TimelineEntryType.competitorMentioned:
        return Icons.compare_arrows;
      case TimelineEntryType.budgetDiscussed:
        return Icons.attach_money;
      case TimelineEntryType.viewedDetails:
        return Icons.visibility;
      case TimelineEntryType.exportedData:
        return Icons.download;
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
      case TimelineEntryType.objectionHandled:
        return 'Objection';
      case TimelineEntryType.decisionMakerReached:
        return 'Decision Maker';
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


  // ignore: unused_element
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
          if (!mounted) return;
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update timeline entry: ${failure.toString()}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        },
        (updatedLead) {
          if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
    // Ensure we always have a complete status history
    final timeline = _ensureCompleteStatusHistory(
      List<LeadTimelineEntry>.from(widget.lead.timeline),
      widget.lead,
    );
    
    final sortedTimeline = timeline
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFF30363D), width: 1),
          right: BorderSide(color: Color(0xFF30363D), width: 1),
          bottom: BorderSide(color: Color(0xFF30363D), width: 1),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: ListView.builder(
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
              // GitHub Actions style timestamp
              Container(
                width: 140,
                padding: EdgeInsets.only(right: 16, top: 2),
                child: Text(
                  _formatGitHubStyleTime(entry.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF8B949E), // GitHub muted
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              // GitHub Actions style icon and line
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getGitHubIconBackground(entry.type),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getEntryIcon(entry.type),
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        margin: EdgeInsets.symmetric(vertical: 2),
                        color: const Color(0xFF30363D),
                      ),
                  ],
                ),
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
      ),
    );
  }

  Widget _buildTimelineEntryCard(LeadTimelineEntry entry) {
    final isOverdue = entry.followUpDate != null && 
                      entry.followUpDate!.isBefore(DateTime.now()) && 
                      !entry.isCompleted;
    final isEditing = _editingEntryId == entry.id;
    final isSynthetic = entry.metadata?['synthetic'] == true;

    if (isEditing) {
      return _buildEditForm(entry);
    }

    // GitHub Actions style entry card
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSynthetic 
            ? const Color(0xFF0D1117).withValues(alpha: 0.5) // Dimmer for synthetic
            : const Color(0xFF0D1117), // GitHub dark background
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOverdue 
              ? const Color(0xFFDA3633) // GitHub red
              : isSynthetic 
                  ? const Color(0xFF30363D).withValues(alpha: 0.5) // Subtle border for synthetic
                  : Colors.transparent,
          width: isOverdue || isSynthetic ? 1 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GitHub Actions style: Simple title with muted metadata
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: Color(0xFFF0F6FC), // GitHub white
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (entry.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.description!,
                        style: const TextStyle(
                          color: Color(0xFF8B949E), // GitHub muted
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSynthetic)
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30363D).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Auto',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8B949E),
                        ),
                      ),
                    ),
                  if (entry.followUpDate != null && !entry.isCompleted)
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOverdue 
                            ? const Color(0xFFDA3633).withValues(alpha: 0.15)
                            : const Color(0xFFFB8500).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue' : 'Scheduled',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isOverdue 
                              ? const Color(0xFFDA3633) 
                              : const Color(0xFFFB8500),
                        ),
                      ),
                    ),
                  if (!isSynthetic) // Only show edit button for non-synthetic entries
                    IconButton(
                      onPressed: () => _startEditingEntry(entry),
                      icon: Icon(Icons.edit),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF8B949E),
                        padding: EdgeInsets.all(4),
                        minimumSize: Size.zero,
                      ),
                      tooltip: 'Edit entry',
                    ),
                ],
              ),
            ],
          ),
          if (entry.followUpDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warningOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
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
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
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
              Icon(Icons.edit),
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
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              hintText: 'Enter a brief title...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
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
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              hintText: 'Add additional details...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
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
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Text(
                          _editingFollowUpDate == null
                              ? 'Set follow-up date (optional)'
                              : DateFormat('MMM d, yyyy • h:mm a').format(_editingFollowUpDate!),
                          style: TextStyle(
                            color: _editingFollowUpDate == null 
                                ? Colors.white.withValues(alpha: 0.6)
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
                  icon: Icon(Icons.clear),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.7),
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
                    foregroundColor: Colors.white.withValues(alpha: 0.7),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
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
    // Ensure we always have a complete status history
    final timeline = _ensureCompleteStatusHistory(
      List<LeadTimelineEntry>.from(widget.lead.timeline),
      widget.lead,
    );
    
    final sortedTimeline = timeline
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GitHub Actions style header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22), // GitHub dark header
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            border: Border.all(
              color: const Color(0xFF30363D), // GitHub border
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: Color(0xFF8B949E), // GitHub muted
              ),
              const SizedBox(width: 8),
              const Text(
                'Activity Log',
                style: TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${sortedTimeline.length}',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (!_showAddForm)
                IconButton(
                  onPressed: _showAddEntryForm,
                  icon: Icon(Icons.add),
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.primaryGold,
                    backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.1),
                  ),
                  tooltip: 'Add Timeline Entry',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Add Entry Form
        if (_showAddForm) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.note_add),
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
                      icon: Icon(Icons.close),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.7),
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
                            : _getEntryColor(type).withValues(alpha: 0.3),
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
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    hintText: 'Enter a brief title...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
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
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    hintText: 'Add additional details...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
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
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text(
                                _selectedFollowUpDate == null
                                    ? 'Set follow-up date (optional)'
                                    : DateFormat('MMM d, yyyy • h:mm a').format(_selectedFollowUpDate!),
                                style: TextStyle(
                                  color: _selectedFollowUpDate == null 
                                      ? Colors.white.withValues(alpha: 0.6)
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
                        icon: Icon(Icons.clear),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.7),
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
                          foregroundColor: Colors.white.withValues(alpha: 0.7),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
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
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No timeline entries yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start tracking your interactions with this lead',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
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
  
  // Ensure complete status history in timeline
  List<LeadTimelineEntry> _ensureCompleteStatusHistory(
    List<LeadTimelineEntry> timeline, 
    Lead lead,
  ) {
    // Define the status progression order
    final statusProgression = [
      LeadStatus.new_,
      LeadStatus.viewed,
      LeadStatus.called,
      // Terminal statuses that can come after called
      LeadStatus.callbackScheduled,
      LeadStatus.interested,
      LeadStatus.converted,
      LeadStatus.doNotCall,
      LeadStatus.didNotConvert,
    ];
    
    // Check existing status change entries
    final existingStatuses = <LeadStatus>{};
    for (final entry in timeline) {
      if (entry.type == TimelineEntryType.statusChange) {
        // Try to extract the status from metadata or title
        final newStatusStr = entry.metadata?['new_status'];
        if (newStatusStr != null) {
          try {
            final status = LeadStatus.values.firstWhere(
              (s) => s.name == newStatusStr,
            );
            existingStatuses.add(status);
          } catch (_) {}
        }
      }
    }
    
    // NOTE: We do NOT auto-generate Lead Created events
    // The server should create this entry when the lead is created
    // If it's missing, that's a data integrity issue that should be fixed server-side
    
    // Find the current status index
    final currentStatusIndex = statusProgression.indexOf(lead.status);
    
    // If the lead has progressed beyond NEW, add missing status transitions
    if (currentStatusIndex > 0) {
      // We need to add status transitions up to the current status
      DateTime syntheticTime = lead.createdAt;
      
      for (int i = 1; i <= currentStatusIndex; i++) {
        final status = statusProgression[i];
        
        // Skip if we already have this status change
        if (existingStatuses.contains(status)) continue;
        
        // Skip terminal statuses unless it's the current status
        if (i > 2 && status != lead.status) continue;
        
        // Add a small time increment for synthetic entries
        syntheticTime = syntheticTime.add(Duration(seconds: i));
        
        // Create synthetic status change entry
        timeline.add(LeadTimelineEntry(
          id: 'synthetic-${status.name}-${widget.lead.id}',
          leadId: widget.lead.id,
          type: TimelineEntryType.statusChange,
          title: 'Status changed to ${_getStatusLabel(status)}',
          description: 'Status progression (auto-generated)',
          createdAt: syntheticTime,
          metadata: {
            'synthetic': true,
            'previous_status': i > 0 ? statusProgression[i - 1].name : LeadStatus.new_.name,
            'new_status': status.name,
          },
        ));
      }
    }
    
    return timeline;
  }
  
  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
      case LeadStatus.viewed:
        return 'VIEWED';
      case LeadStatus.called:
        return 'CALLED';
      case LeadStatus.callbackScheduled:
        return 'CALLBACK SCHEDULED';
      case LeadStatus.interested:
        return 'INTERESTED';
      case LeadStatus.converted:
        return 'CONVERTED';
      case LeadStatus.doNotCall:
        return 'DO NOT CALL';
      case LeadStatus.didNotConvert:
        return 'DID NOT CONVERT';
    }
  }
  
  // GitHub Actions style formatting helpers
  String _formatGitHubStyleTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    // Format as "Oct 23, 2024"
    return DateFormat('MMM d, yyyy').format(date);
  }
  
  Color _getGitHubIconBackground(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.leadCreated:
        return const Color(0xFF1F883D); // GitHub green
      case TimelineEntryType.statusChange:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.note:
        return const Color(0xFF6E7781); // GitHub gray
      case TimelineEntryType.followUp:
        return const Color(0xFFFB8500); // GitHub orange
      case TimelineEntryType.reminder:
        return const Color(0xFF8250DF); // GitHub purple
      case TimelineEntryType.phoneCall:
        return const Color(0xFF1F883D); // GitHub green
      case TimelineEntryType.email:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.meeting:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.objectionHandled:
        return const Color(0xFFDA3633); // GitHub red
      case TimelineEntryType.decisionMakerReached:
        return const Color(0xFF1F883D); // GitHub green
      case TimelineEntryType.painPointDiscovered:
        return const Color(0xFFFB8500); // GitHub orange
      case TimelineEntryType.nextStepsAgreed:
        return const Color(0xFF1F883D); // GitHub green
      case TimelineEntryType.competitorMentioned:
        return const Color(0xFF8250DF); // GitHub purple
      case TimelineEntryType.budgetDiscussed:
        return const Color(0xFF0969DA); // GitHub blue
      case TimelineEntryType.viewedDetails:
        return const Color(0xFF6E7781); // GitHub gray
      case TimelineEntryType.exportedData:
        return const Color(0xFF6E7781); // GitHub gray
    }
  }
}