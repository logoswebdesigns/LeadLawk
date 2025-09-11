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
    super.key,
    required this.lead,
    required this.callStartTime,
    required this.callDuration,
    this.salesPitchId,
  });

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
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGold.withValues(alpha: 0.1),
                    AppTheme.primaryBlue.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.call),
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
                          color: Colors.white.withValues(alpha: 0.7),
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
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always show sales pitch section (will use default if none selected)
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
                      visible: widget.lead.phone.isEmpty || widget.lead.phone == 'No phone',
                      child: _buildSection(
                        'Phone Number (Optional)',
                        TextField(
                          controller: _phoneController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Add Phone Number',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            hintText: 'Enter phone number if available',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold.withValues(alpha: 0.7)),
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
                          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          hintText: 'Key points from the conversation...',
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
                                trailing: Icon(Icons.calendar_today),
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
              padding: EdgeInsets.all(16),
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
    return Padding(padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
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
  
  // Helper method following Single Responsibility Principle
  // Encapsulates default pitch selection logic
  dynamic _getDefaultPitch(List<dynamic> pitches) {
    // First try to find one marked as default
    try {
      return pitches.firstWhere((p) => p.isDefault == true);
    } catch (_) {
      // Fallback to first pitch if no default is marked
      return pitches.first;
    }
  }

  Widget _buildSalesPitchSection() {
    // Strategy Pattern: Determine pitch selection strategy
    // Following Null Object Pattern - always show a pitch (default if none selected)
    final pitches = ref.watch(salesPitchesProvider);
    
    // Show loading indicator while pitches are being loaded
    if (pitches.isEmpty) {
      return Card(
        color: AppTheme.primaryGold.withValues(alpha: 0.08),
        elevation: 0,
        margin: EdgeInsets.only(bottom: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppTheme.primaryGold.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(
                  color: AppTheme.primaryGold,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading sales pitches...',
                  style: TextStyle(
                    color: AppTheme.primaryGold.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Pitch Resolution Strategy (in order of preference):
    // 1. Explicitly passed pitch ID (from sales pitch modal)
    // 2. Lead's saved pitch ID
    // 3. Default pitch (marked as default)
    // 4. First available pitch (fallback)
    final pitchId = widget.salesPitchId ?? widget.lead.salesPitchId;
    
    final selectedPitch = pitchId != null
        ? pitches.firstWhere(
            (p) => p.id == pitchId,
            orElse: () => _getDefaultPitch(pitches), // Fallback to default
          )
        : _getDefaultPitch(pitches); // No pitch selected, use default
    
    // Following Material Design's emphasis guidelines for important content during calls
    // Using a Card with elevated surface as recommended in Material Design 3
    return Card(
      color: AppTheme.primaryGold.withValues(alpha: 0.08),
      elevation: 0,
      margin: EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.primaryGold.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with clear visual hierarchy (Material Design principle)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.campaign,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pitchId == null ? 'DEFAULT SALES PITCH' : 'ACTIVE SALES PITCH',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppTheme.primaryGold.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedPitch.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.copy_all,
                    color: AppTheme.primaryGold,
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
                        backgroundColor: AppTheme.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Pitch content - Always visible for easy reading during calls
          // Using good contrast and readability as per WCAG guidelines
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Script content with enhanced readability
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SelectableText(
                    selectedPitch.content
                        .replaceAll('[Business Name]', widget.lead.businessName)
                        .replaceAll('[Location]', widget.lead.location),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,  // Larger for easier reading during calls
                      height: 1.6,    // Better line height for readability
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Pitch tracking with clear touch targets (48dp minimum as per Material Design)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _pitchDeliveredSuccessfully = !_pitchDeliveredSuccessfully),
                        child: Padding(padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _pitchDeliveredSuccessfully,
                                  onChanged: (val) => setState(() => _pitchDeliveredSuccessfully = val ?? false),
                                  activeColor: AppTheme.successGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Pitch delivered successfully',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_pitchDeliveredSuccessfully)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _pitchResonated = !_pitchResonated),
                          child: Padding(padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _pitchResonated,
                                    onChanged: (val) => setState(() => _pitchResonated = val ?? false),
                                    activeColor: AppTheme.successGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Prospect showed interest',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}