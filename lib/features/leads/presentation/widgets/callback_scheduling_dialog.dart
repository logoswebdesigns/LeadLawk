import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../domain/services/calendar_service.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;
import '../providers/email_settings_provider.dart';
import '../../../../core/utils/debug_logger.dart';

class CallbackSchedulingDialog extends ConsumerStatefulWidget {
  final Lead lead;
  
  const CallbackSchedulingDialog({
    super.key,
    required this.lead,
  });
  
  @override
  ConsumerState<CallbackSchedulingDialog> createState() => _CallbackSchedulingDialogState();
}

class _CallbackSchedulingDialogState extends ConsumerState<CallbackSchedulingDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final _notesController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _addToCalendar = false;
  bool _sendEmailInvite = false;
  
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
    _emailController.dispose();
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
            colorScheme: const ColorScheme.dark(
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
            colorScheme: const ColorScheme.dark(
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
      
      DebugLogger.log('📅 Scheduling callback for: ${callbackDateTime.toIso8601String()}');
      
      // Update lead status and follow-up date
      final updatedLead = widget.lead.copyWith(
        status: LeadStatus.callbackScheduled,
        followUpDate: callbackDateTime,
      );
      
      DebugLogger.log('🔄 Updating lead ${widget.lead.id} with status: ${updatedLead.status.name}');
      DebugLogger.log('📝 Follow-up date: ${updatedLead.followUpDate?.toIso8601String()}');
      
      final updateResult = await repository.updateLead(updatedLead);
      
      bool updateSuccess = false;
      updateResult.fold(
        (failure) {
          DebugLogger.error('❌ Failed to update lead: $failure');
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
          DebugLogger.log('✅ Lead updated successfully: ${lead.status.name}');
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
      DebugLogger.log('📝 Adding timeline entry for callback');
      final timelineData = {
        'type': 'follow_up',
        'title': 'Callback scheduled',
        'description': _notesController.text.isNotEmpty 
            ? _notesController.text 
            : 'Callback scheduled for ${_formatDateTime(callbackDateTime)}',
        'follow_up_date': callbackDateTime.toIso8601String(),
      };
      DebugLogger.log('📝 Timeline data: $timelineData');
      
      final timelineResult = await repository.addTimelineEntry(widget.lead.id, timelineData);
      timelineResult.fold(
        (failure) => DebugLogger.error('❌ Failed to add timeline entry: $failure'),
        (_) => DebugLogger.log('✅ Timeline entry added successfully'),
      );
      
      // Handle calendar options
      bool calendarAdded = false;
      bool inviteSent = false;
      
      if (_addToCalendar) {
        DebugLogger.log('📅 Adding to native calendar...');
        calendarAdded = await CalendarService.addToNativeCalendar(
          lead: widget.lead,
          callbackDateTime: callbackDateTime,
          notes: _notesController.text,
        );
        if (calendarAdded) {
          DebugLogger.log('✅ Added to native calendar');
        } else {
          DebugLogger.log('⚠️ Could not add to native calendar');
        }
      }
      
      if (_sendEmailInvite && _emailController.text.isNotEmpty) {
        DebugLogger.log('📧 Sending calendar invite to ${_emailController.text}...');
        try {
          // Get email settings
          final emailSettings = ref.read(emailSettingsProvider);
          
          if (emailSettings.enabled && 
              emailSettings.smtpHost != null && 
              emailSettings.smtpUsername != null && 
              emailSettings.smtpPassword != null) {
            // Send actual email with configured SMTP
            inviteSent = await CalendarService.sendCalendarInvite(
              lead: widget.lead,
              callbackDateTime: callbackDateTime,
              recipientEmail: _emailController.text,
              notes: _notesController.text,
              smtpHost: emailSettings.smtpHost,
              smtpPort: emailSettings.smtpPort,
              smtpUsername: emailSettings.smtpUsername,
              smtpPassword: emailSettings.smtpPassword,
            );
            
            if (inviteSent) {
              DebugLogger.log('✅ Calendar invite sent to ${_emailController.text}');
            } else {
              DebugLogger.error('⚠️ Failed to send calendar invite');
            }
          } else {
            // Fallback: Just create the ICS file
            final icsFile = await CalendarService.createICSFile(
              lead: widget.lead,
              callbackDateTime: callbackDateTime,
              notes: _notesController.text,
              recipientEmail: _emailController.text,
            );
            
            DebugLogger.log('✅ ICS file created: ${icsFile.path}');
            DebugLogger.log('ℹ️ Configure email settings to send invites automatically');
            
            // Show a message to configure email settings
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ICS file created. Configure email settings to send invites.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        } catch (e) {
          DebugLogger.error('❌ Failed to send calendar invite: $e');
        }
      }
      
      // Refresh the lead details
      DebugLogger.log('🔄 Refreshing lead details');
      ref.invalidate(leadDetailProvider(widget.lead.id));
      
      if (mounted) {
        Navigator.of(context).pop();
        
        // Build success message based on what was done
        String message = 'Callback scheduled for ${_formatDateTime(callbackDateTime)}';
        if (calendarAdded) {
          if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
            message += '\n✅ Added to your calendar';
          } else {
            message += '\n✅ Calendar file opened - add to your calendar app';
          }
        }
        if (inviteSent) {
          message += '\n✅ Calendar invite prepared';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Exception in _scheduleCallback: $e');
      DebugLogger.log('Stack trace: $stackTrace');
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
  
  String _getCalendarSubtitle() {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      return 'Add this callback to your device calendar';
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'Download ICS file to add to your calendar';
    } else {
      return 'Create calendar file for this callback';
    }
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
              color: Colors.purple.withValues(alpha: 0.2),
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
                color: Colors.white.withValues(alpha: 0.7),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
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
                      color: Colors.white.withValues(alpha: 0.5),
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
                color: Colors.white.withValues(alpha: 0.7),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
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
                      color: Colors.white.withValues(alpha: 0.5),
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
                color: Colors.white.withValues(alpha: 0.7),
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
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Calendar Options Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryGold,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Calendar Options',
                        style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Add to my calendar option
                  CheckboxListTile(
                    value: _addToCalendar,
                    onChanged: (value) {
                      setState(() {
                        _addToCalendar = value ?? false;
                      });
                    },
                    title: Text(
                      'Add to my calendar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      _getCalendarSubtitle(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    activeColor: AppTheme.primaryGold,
                    checkColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  
                  const Divider(color: Colors.white12),
                  
                  // Send email invite option
                  CheckboxListTile(
                    value: _sendEmailInvite,
                    onChanged: (value) {
                      setState(() {
                        _sendEmailInvite = value ?? false;
                      });
                    },
                    title: Text(
                      'Send calendar invite to lead',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Email a calendar invite to the lead (requires email)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    activeColor: AppTheme.primaryGold,
                    checkColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  
                  // Email field (shown only when send invite is checked)
                  if (_sendEmailInvite) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Lead Email Address',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        hintText: 'Enter lead\'s email...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                        ),
                        prefixIcon: Icon(
                          Icons.email,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 18,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.purple,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Callback: ${_formatDateTime(callbackDateTime)}',
                      style: const TextStyle(
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