import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;
import '../providers/sales_pitch_provider.dart';

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
  
  // Follow-up tracking
  bool _scheduledFollowUp = false;
  DateTime? _followUpDate;
  
  // Sales pitch tracking (only if pitch was used)
  bool _pitchDeliveredSuccessfully = false;
  bool _pitchResonated = false;
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCallData() async {
    final repository = ref.read(leadsRepositoryProvider);
    
    try {
      // Add timeline entry for the call
      final timelineData = {
        'type': 'PHONE_CALL',
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
      
      await repository.addTimelineEntry(widget.lead.id, timelineData);
      
      // Update lead status based on outcome
      if (_selectedOutcome == 'INTERESTED' || _selectedOutcome == 'SCHEDULED_MEETING') {
        final updatedLead = widget.lead.copyWith(status: LeadStatus.interested);
        await repository.updateLead(updatedLead);
      } else if (_selectedOutcome == 'NOT_INTERESTED' || _selectedOutcome == 'DO_NOT_CALL') {
        final updatedLead = widget.lead.copyWith(status: LeadStatus.doNotCall);
        await repository.updateLead(updatedLead);
      }
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call data saved successfully'),
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
                    
                    // Call Notes
                    _buildSection(
                      'Call Notes',
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Key points from the conversation...',
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
                    onPressed: () => Navigator.of(context).pop(false),
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
    
    final pitchesAsync = ref.watch(salesPitchesProvider);
    
    return pitchesAsync.when(
      data: (pitches) {
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}