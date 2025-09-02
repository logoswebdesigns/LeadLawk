import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;

class CallbackSchedulingDialog extends ConsumerStatefulWidget {
  final Lead lead;
  
  const CallbackSchedulingDialog({
    Key? key,
    required this.lead,
  }) : super(key: key);
  
  @override
  ConsumerState<CallbackSchedulingDialog> createState() => _CallbackSchedulingDialogState();
}

class _CallbackSchedulingDialogState extends ConsumerState<CallbackSchedulingDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Default to tomorrow at 10 AM
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryGold,
              onPrimary: Colors.black,
              surface: AppTheme.elevatedSurface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryGold,
              onPrimary: Colors.black,
              surface: AppTheme.elevatedSurface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  Future<void> _scheduleCallback() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final repository = ref.read(leadsRepositoryProvider);
      
      // Combine date and time
      final callbackDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      print('📅 Scheduling callback for: ${callbackDateTime.toIso8601String()}');
      
      // Update lead status and follow-up date
      final updatedLead = widget.lead.copyWith(
        status: LeadStatus.callbackScheduled,
        followUpDate: callbackDateTime,
      );
      
      print('🔄 Updating lead ${widget.lead.id} with status: ${updatedLead.status.name}');
      print('📝 Follow-up date: ${updatedLead.followUpDate?.toIso8601String()}');
      
      final updateResult = await repository.updateLead(updatedLead);
      
      bool updateSuccess = false;
      updateResult.fold(
        (failure) {
          print('❌ Failed to update lead: $failure');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update lead status: $failure'),
                backgroundColor: AppTheme.errorRed,
              ),
            );
          }
        },
        (lead) {
          print('✅ Lead updated successfully: ${lead.status.name}');
          updateSuccess = true;
        },
      );
      
      // Only continue if update was successful
      if (!updateSuccess) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Add timeline entry
      print('📝 Adding timeline entry for callback');
      final timelineData = {
        'type': 'follow_up',
        'title': 'Callback scheduled',
        'description': _notesController.text.isNotEmpty 
            ? _notesController.text 
            : 'Callback scheduled for ${_formatDateTime(callbackDateTime)}',
        'follow_up_date': callbackDateTime.toIso8601String(),
      };
      print('📝 Timeline data: $timelineData');
      
      final timelineResult = await repository.addTimelineEntry(widget.lead.id, timelineData);
      timelineResult.fold(
        (failure) => print('❌ Failed to add timeline entry: $failure'),
        (_) => print('✅ Timeline entry added successfully'),
      );
      
      // Refresh the lead details
      print('🔄 Refreshing lead details');
      ref.invalidate(leadDetailProvider(widget.lead.id));
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Callback scheduled for ${_formatDateTime(callbackDateTime)}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _scheduleCallback: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule callback: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour:$minute $period';
  }
  
  @override
  Widget build(BuildContext context) {
    final callbackDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    
    return AlertDialog(
      backgroundColor: AppTheme.elevatedSurface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event,
              color: Colors.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Schedule Callback',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selector
            Text(
              'Date',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Time selector
            Text(
              'Time',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime.format(context),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Notes
            Text(
              'Notes (Optional)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add any notes about this callback...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.purple,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Callback: ${_formatDateTime(callbackDateTime)}',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _scheduleCallback,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Schedule Callback'),
        ),
      ],
    );
  }
}