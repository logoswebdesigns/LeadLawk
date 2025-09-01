import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/sales_pitch_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;
import '../widgets/call_tracking_dialog.dart';

class UnifiedCallService {
  static Future<void> handleCall({
    required BuildContext context,
    required WidgetRef ref,
    required Lead lead,
    VoidCallback? onComplete,
  }) async {
    // Step 1: Check if sales pitch selection is needed
    String? selectedPitchId = lead.salesPitchId;
    
    if ((lead.status == LeadStatus.new_ || lead.status == LeadStatus.viewed) 
        && selectedPitchId == null) {
      // Need to select a sales pitch first
      selectedPitchId = await _showPitchSelectionDialog(context, ref, lead);
      
      if (selectedPitchId == null) {
        // User cancelled pitch selection
        return;
      }
      
      // Save the pitch selection to the lead
      final dataSource = ref.read(salesPitchDataSourceProvider);
      try {
        await dataSource.assignPitchToLead(lead.id, selectedPitchId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save pitch selection: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return;
      }
    }
    
    // Step 2: Initiate the phone call
    final phoneUrl = Uri.parse('tel:${lead.phone}');
    final callStartTime = DateTime.now();
    
    try {
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
        
        // Step 3: Show call tracking dialog after a brief delay
        // This gives time for the phone app to open
        await Future.delayed(const Duration(seconds: 2));
        
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CallTrackingDialog(
              lead: lead,
              callStartTime: callStartTime,
              callDuration: Duration.zero, // Will be calculated in the dialog
              salesPitchId: selectedPitchId,
            ),
          );
          
          // Step 4: Update lead status if needed
          if (lead.status == LeadStatus.new_ || lead.status == LeadStatus.viewed) {
            final repository = ref.read(leadsRepositoryProvider);
            final updatedLead = lead.copyWith(
              status: LeadStatus.called,
              salesPitchId: selectedPitchId,
            );
            await repository.updateLead(updatedLead);
            
            // Add timeline entry
            await repository.addTimelineEntry(lead.id, {
              'type': 'STATUS_CHANGE',
              'title': 'Status changed to Called',
              'description': 'Call initiated with sales pitch selected',
              'metadata': {
                'sales_pitch_id': selectedPitchId,
              },
            });
          }
          
          onComplete?.call();
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to make call to ${lead.phone}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
  
  static Future<String?> _showPitchSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    Lead lead,
  ) async {
    final pitches = await ref.read(salesPitchesProvider.future);
    
    if (pitches.length < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please add at least 2 sales pitches in account settings'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return null;
    }
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.campaign,
                          color: AppTheme.primaryGold,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Sales Pitch',
                                style: TextStyle(
                                  color: AppTheme.primaryGold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choose your approach for ${lead.businessName}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.warningOrange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.warningOrange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pitch selection is required before making the call',
                              style: TextStyle(
                                color: AppTheme.warningOrange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Pitch List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: pitches.length,
                  itemBuilder: (context, index) {
                    final pitch = pitches[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, pitch.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryGold.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pitch header with stats
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pitch.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (pitch.attempts > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successGreen.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.trending_up,
                                              size: 14,
                                              color: AppTheme.successGreen,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${pitch.conversionRate.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                color: AppTheme.successGreen,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${pitch.attempts} calls',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Pitch content preview
                                Text(
                                  pitch.content.length > 200
                                    ? '${pitch.content.substring(0, 200)}...'
                                    : pitch.content,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Select button hint
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Tap to select',
                                      style: TextStyle(
                                        color: AppTheme.primaryGold.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: AppTheme.primaryGold.withOpacity(0.7),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Footer with cancel button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}