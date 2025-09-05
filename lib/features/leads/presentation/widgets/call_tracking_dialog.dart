import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../domain/constants/timeline_constants.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;
import '../providers/sales_pitch_provider.dart';
import '../providers/lead_detail_provider.dart';

class CallTrackingDialog extends ConsumerStatefulWidget {
  final Lead lead;
  final DateTime callStartTime;
  final Duration callDuration;
  final String? salesPitchId;

  const CallTrackingDialog({
    Key? key,
    required this.lead,
    required this.callStartTime,
    required this.callDuration,
    this.salesPitchId,
  }) : super(key: key);

  @override
  ConsumerState<CallTrackingDialog> createState() => _CallTrackingDialogState();
}

class _CallTrackingDialogState extends ConsumerState<CallTrackingDialog> {
  // Core call outcome
  String _selectedOutcome = 'NO_ANSWER';
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Follow-up tracking
  bool _scheduledFollowUp = false;
  DateTime? _followUpDate;
  
  // Sales pitch tracking (only if pitch was used)
  bool _pitchDeliveredSuccessfully = false;
  bool _pitchResonated = false;
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // Handle US phone numbers (10 or 11 digits)
    if (digits.length == 10) {
      // Format as (XXX) XXX-XXXX
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      // Remove country code and format
      final usDigits = digits.substring(1);
      return '(${usDigits.substring(0, 3)}) ${usDigits.substring(3, 6)}-${usDigits.substring(6)}';
    }
    
    // Return original if not a standard US format
    return phone;
  }

  Future<void> _saveCallData() async {
    final repository = ref.read(leadsRepositoryProvider);
    
    try {
      // Update phone number if provided
      Lead currentLead = widget.lead;
      bool phoneUpdated = false;
      
      if (_phoneController.text.trim().isNotEmpty && 
          (_phoneController.text.trim() != widget.lead.phone || widget.lead.phone == 'No phone')) {
        final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
        currentLead = widget.lead.copyWith(phone: formattedPhone);
        await repository.updateLead(currentLead);
        phoneUpdated = true;
      }
      
      // Add timeline entry for the call
      final timelineData = {
        'type': TimelineEntryTypes.phoneCall,
        'title': 'Call completed - $_selectedOutcome',
        'description': _notesController.text.trim(),
        'metadata': {
          'duration_seconds': widget.callDuration.inSeconds,
          'outcome': _selectedOutcome,
          'scheduled_follow_up': _scheduledFollowUp,
          'follow_up_date': _followUpDate?.toIso8601String(),
        },
      };
      
      // Only add pitch data if a pitch was actually used
      if (widget.salesPitchId != null || widget.lead.salesPitchId != null) {
        final metadata = timelineData['metadata'] as Map<String, dynamic>;
        metadata['sales_pitch_id'] = widget.salesPitchId ?? widget.lead.salesPitchId;
        metadata['pitch_delivered_successfully'] = _pitchDeliveredSuccessfully;
        metadata['pitch_resonated'] = _pitchResonated;
      }
      
      // Track if phone was added
      if (phoneUpdated) {
        (timelineData['metadata'] as Map<String, dynamic>)['phone_added'] = currentLead.phone;
      }
      
      await repository.addTimelineEntry(currentLead.id, timelineData);
      
      // Update lead status based on outcome
      if (_selectedOutcome == 'INTERESTED' || _selectedOutcome == 'SCHEDULED_MEETING') {
        final updatedLead = currentLead.copyWith(status: LeadStatus.interested);
        await repository.updateLead(updatedLead);
      } else if (_selectedOutcome == 'NOT_INTERESTED' || _selectedOutcome == 'DO_NOT_CALL') {
        final updatedLead = currentLead.copyWith(status: LeadStatus.doNotCall);
        await repository.updateLead(updatedLead);
      }
      
      // Invalidate the lead detail provider to refresh UI
      ref.invalidate(leadDetailProvider(currentLead.id));
      
      if (mounted) {
        // Pop with result indicating phone was updated
        Navigator.of(context).pop({'success': true, 'phoneUpdated': phoneUpdated});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(phoneUpdated 
              ? 'Call data saved and phone number updated'
              : 'Call data saved successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save call data: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: AppTheme.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGold.withOpacity(0.1),
                    AppTheme.primaryBlue.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_in_talk, color: AppTheme.primaryGold),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Track Call Outcome',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Duration: ${widget.callDuration.inMinutes}:${(widget.callDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sales Pitch Reference (if applicable)
                    if (widget.salesPitchId != null || widget.lead.salesPitchId != null)
                      _buildSalesPitchSection(),
                    
                    // Call Outcome
                    _buildSection(
                      'Call Outcome',
                      DropdownButtonFormField<String>(
                        value: _selectedOutcome,
                        decoration: const InputDecoration(
                          labelText: 'What was the outcome?',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'NO_ANSWER', child: Text('No Answer')),
                          DropdownMenuItem(value: 'LEFT_VOICEMAIL', child: Text('Left Voicemail')),
                          DropdownMenuItem(value: 'CALLBACK_REQUESTED', child: Text('Callback Requested')),
                          DropdownMenuItem(value: 'INTERESTED', child: Text('Interested')),
                          DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                          DropdownMenuItem(value: 'SCHEDULED_MEETING', child: Text('Meeting Scheduled')),
                          DropdownMenuItem(value: 'DO_NOT_CALL', child: Text('Do Not Call')),
                        ],
                        onChanged: (val) => setState(() => _selectedOutcome = val!),
                      ),
                    ),
                    
                    // Phone Number (optional)
                    Visibility(
                      visible: (widget.lead.phone?.isEmpty ?? true) || widget.lead.phone == 'No phone',
                      child: _buildSection(
                        'Phone Number (Optional)',
                        TextField(
                          controller: _phoneController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Add Phone Number',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            hintText: 'Enter phone number if available',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ),
                    
                    // Call Notes
                    _buildSection(
                      'Call Notes',
                      TextField(
                        controller: _notesController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          hintText: 'Key points from the conversation...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                          ),
                        ),
                        maxLines: 4,
                      ),
                    ),
                    
                    // Follow-up
                    if (_selectedOutcome == 'INTERESTED' || 
                        _selectedOutcome == 'CALLBACK_REQUESTED' ||
                        _selectedOutcome == 'SCHEDULED_MEETING')
                      _buildSection(
                        'Follow-up',
                        Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Schedule Follow-up'),
                              value: _scheduledFollowUp,
                              onChanged: (val) => setState(() => _scheduledFollowUp = val),
                            ),
                            if (_scheduledFollowUp)
                              ListTile(
                                title: Text(_followUpDate == null 
                                  ? 'Select Date' 
                                  : 'Follow-up: ${_followUpDate!.toLocal().toString().split(' ')[0]}'),
                                trailing: const Icon(Icons.calendar_today),
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now().add(const Duration(days: 1)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() => _followUpDate = date);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop({'success': false}),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveCallData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Save Call Data'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSalesPitchSection() {
    final pitchId = widget.salesPitchId ?? widget.lead.salesPitchId;
    if (pitchId == null) return const SizedBox.shrink();
    
    final pitches = ref.watch(salesPitchesProvider);
    
    if (pitches.isEmpty) return const SizedBox.shrink();
    
    final selectedPitch = pitches.firstWhere(
      (p) => p.id == pitchId,
      orElse: () => pitches.first,
    );
    
    return _buildSection(
      'Sales Pitch Used',
      Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryGold.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pitch header with copy button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedPitch.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        size: 18,
                        color: AppTheme.primaryGold.withOpacity(0.7),
                      ),
                      tooltip: 'Copy pitch to clipboard',
                      onPressed: () {
                        final personalizedPitch = selectedPitch.content
                            .replaceAll('[Business Name]', widget.lead.businessName)
                            .replaceAll('[Location]', widget.lead.location);
                        
                        Clipboard.setData(ClipboardData(text: personalizedPitch));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pitch copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Pitch content (collapsible)
                ExpansionTile(
                  title: Text(
                    'View Pitch Script',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  initiallyExpanded: true,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        selectedPitch.content
                            .replaceAll('[Business Name]', widget.lead.businessName)
                            .replaceAll('[Location]', widget.lead.location),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Simple pitch effectiveness tracking
                Column(
                  children: [
                    CheckboxListTile(
                      title: Text(
                        'Pitch delivered successfully',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                      value: _pitchDeliveredSuccessfully,
                      onChanged: (val) => setState(() => _pitchDeliveredSuccessfully = val ?? false),
                      activeColor: AppTheme.successGreen,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_pitchDeliveredSuccessfully)
                      CheckboxListTile(
                        title: Text(
                          'Prospect showed interest',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                        value: _pitchResonated,
                        onChanged: (val) => setState(() => _pitchResonated = val ?? false),
                        activeColor: AppTheme.successGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}