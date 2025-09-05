import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/lead_navigation_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;
import '../providers/pagespeed_status_provider.dart';
import '../widgets/lead_navigation_bar.dart';
import '../widgets/lead_info_row.dart';
import '../widgets/lead_flag_row.dart';
import '../widgets/lead_notes_section.dart';
import '../widgets/lead_sales_pitch_section.dart';
import '../widgets/lead_timeline.dart';
import '../widgets/pagespeed_score_card.dart';
import '../widgets/lead_status_actions.dart';
import '../widgets/dynamic_pipeline_widget.dart';
import '../widgets/call_tracking_dialog.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/unified_screenshot_card.dart';
import '../widgets/collapsible_screenshots.dart';
import '../services/lead_actions_service.dart';
import '../utils/lead_detail_utils.dart';
import '../../data/datasources/pagespeed_datasource.dart';

class LeadDetailPage extends ConsumerStatefulWidget {
  final String leadId;

  const LeadDetailPage({Key? key, required this.leadId}) : super(key: key);

  @override
  ConsumerState<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends ConsumerState<LeadDetailPage> {
  late final LeadActionsService _actionsService;
  late final PageSpeedDataSource _pageSpeedDataSource;
  bool _isTestingPageSpeed = false;
  String? _lastUpdatedLeadId; // Track which lead we've already updated

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actionsService = LeadActionsService(ref: ref, context: context);
    _pageSpeedDataSource = PageSpeedDataSource();
    
    // Automatically transition NEW leads to VIEWED
    _updateStatusToViewed();
  }
  
  @override
  void didUpdateWidget(LeadDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When navigating to a different lead via prev/next buttons
    if (oldWidget.leadId != widget.leadId) {
      print('📱 NAVIGATION: Lead changed from ${oldWidget.leadId} to ${widget.leadId}');
      // Update the new lead's status from NEW to VIEWED if needed
      _updateStatusToViewed();
    }
  }
  
  Future<void> _updateStatusToViewed() async {
    // Prevent duplicate updates for the same lead
    if (_lastUpdatedLeadId == widget.leadId) {
      print('📱 STATUS: Already updated lead ${widget.leadId} to VIEWED, skipping');
      return;
    }
    
    try {
      final lead = await ref.read(leadDetailProvider(widget.leadId).future);
      
      // Only update if the lead is NEW
      if (lead.status == LeadStatus.new_) {
        _lastUpdatedLeadId = widget.leadId; // Mark as updated
        final repository = ref.read(leadsRepositoryProvider);
        
        // Update the lead status
        final updatedLead = lead.copyWith(status: LeadStatus.viewed);
        await repository.updateLead(updatedLead);
        
        // Add timeline entry
        await repository.addTimelineEntry(lead.id, {
          'type': 'STATUS_CHANGE',
          'title': 'Status changed to VIEWED',
          'description': 'Lead viewed for the first time',
          'metadata': {
            'auto_updated': true,
            'triggered_by': 'page_view',
            'previous_status': LeadStatus.new_.name,
            'new_status': LeadStatus.viewed.name,
          },
        });
        
        // Refresh the lead details
        ref.invalidate(leadDetailProvider(widget.leadId));
      }
    } catch (e) {
      print('Failed to update status to VIEWED: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadDetailProvider(widget.leadId));
    final navigation = ref.watch(leadNavigationProvider(widget.leadId));
    
    // Watch for lead data changes and update status when a NEW lead is loaded
    ref.listen(leadDetailProvider(widget.leadId), (previous, next) {
      next.whenData((lead) {
        if (lead.status == LeadStatus.new_) {
          print('📱 STATUS: NEW lead loaded (${lead.businessName}), triggering VIEWED update');
          _updateStatusToViewed();
        }
      });
    });
    
    // Note: We load leads on-demand now, not all at once

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildNavigationSection(navigation),
          Expanded(
            child: leadAsync.when(
              data: (lead) => _buildLeadContent(lead),
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _navigateBack(),
      ),
      title: const Text('Lead Details'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'delete', child: Text('Delete Lead')),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationSection(LeadNavigationContext? navigation) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    if (navigation == null) {
      return _buildNavigationSkeleton();
    }
    
    return isMobile 
      ? _buildMobileNavigation(navigation)
      : LeadNavigationBar(navigation: navigation);
  }
  
  Widget _buildMobileNavigation(LeadNavigationContext navigation) {
    final hasMoreToLoad = navigation.totalCount > navigation.currentIndex;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Previous button
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: navigation.previousLead != null 
                ? AppTheme.accentPurple 
                : Theme.of(context).disabledColor,
            ),
            onPressed: navigation.previousLead != null
              ? () => context.go('/leads/${navigation.previousLead!.id}')
              : null,
            tooltip: navigation.previousLead?.businessName ?? 'No previous lead',
          ),
          // Current lead info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  navigation.currentLead.businessName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${navigation.currentIndex} / ${navigation.totalCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Next button
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: (navigation.nextLead != null || hasMoreToLoad)
                ? AppTheme.accentPurple 
                : Theme.of(context).disabledColor,
            ),
            onPressed: (navigation.nextLead != null || hasMoreToLoad)
              ? () async {
                  final nextId = await ref.read(leadNavigationActionsProvider).navigateToNext(navigation.currentLead.id);
                  if (nextId != null && mounted) {
                    context.go('/leads/$nextId');
                  }
                }
              : null,
            tooltip: navigation.nextLead?.businessName ?? (hasMoreToLoad ? 'Load more leads' : 'No next lead'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationSkeleton() {
    return Container(
      height: 80,
      color: Theme.of(context).cardColor,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildLeadContent(Lead lead) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with business name, info, and status - all in one place
          _buildCompactHeaderSection(lead),
          const SizedBox(height: 16),
          
          // Quick Actions Bar - Call, Schedule Callback, Do Not Convert - PRIORITY
          QuickActionsBar(
            lead: lead,
            onRefresh: () {
              ref.invalidate(leadDetailProvider(widget.leadId));
            },
            onNavigateNext: () async {
              // Navigate to next lead after DID NOT CONVERT submission
              final navigation = ref.read(leadNavigationProvider(widget.leadId));
              if (navigation != null) {
                final nextId = await ref.read(leadNavigationActionsProvider).navigateToNext(widget.leadId);
                if (nextId != null && context.mounted) {
                  context.go('/leads/$nextId');
                }
              }
            },
          ),
          const SizedBox(height: 20),
          
          // Notes Section - MOVED UP for quick access during calls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: const LeadNotesSection(),
          ),
          const SizedBox(height: 20),
          
          // Status Actions - Quick status changes and terminal actions
          LeadStatusActions(lead: lead),
          const SizedBox(height: 20),
          
          // Sales Pitch Section - For quick reference during calls
          LeadSalesPitchSection(lead: lead),
          const SizedBox(height: 20),
          
          // Screenshots - Collapsible to save space
          CollapsibleScreenshots(
            lead: lead,
            defaultExpanded: true,
          ),
          const SizedBox(height: 20),
          
          // PageSpeed Score - Below screenshots
          if (lead.hasWebsite) ...[
            PageSpeedScoreCard(
              lead: lead,
              onTestPressed: () => _runPageSpeedTest(lead),
            ),
            const SizedBox(height: 20),
          ],
          
          // Dynamic Pipeline - Visual status tracking
          Container(
            height: 250,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 16),
            child: DynamicPipelineWidget(
              lead: lead,
              timeline: const [], // TODO: Pass actual timeline entries
              onStatusChanged: () {
                HapticFeedback.lightImpact();
                ref.invalidate(leadDetailProvider(widget.leadId));
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Timeline - Full history at the bottom
          LeadTimeline(
            lead: lead,
            onAddEntry: (entry) {}, // TODO: Implement
            onUpdateEntry: (entry) {}, // TODO: Implement
            onSetFollowUpDate: (date) {}, // TODO: Implement
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(String error) {
    // Check if it's a 404 error (lead not found)
    final is404 = error.contains('404') || error.contains('not found');
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            is404 ? Icons.search_off : Icons.error_outline, 
            size: 64, 
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            is404 ? 'Lead Not Found' : 'Error Loading Lead',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            is404 
              ? 'This lead may have been deleted or does not exist'
              : 'Unable to load lead details',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/leads'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Back to Leads',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderSection(Lead lead) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business name and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.businessName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (lead.rating != null && lead.rating! > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: AppTheme.warningOrange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${lead.rating!.toStringAsFixed(1)} (${lead.reviewCount ?? 0} reviews)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(lead.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(lead.status).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(lead.status),
                      size: 12,
                      color: _getStatusColor(lead.status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusLabel(lead.status),
                      style: TextStyle(
                        color: _getStatusColor(lead.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          
          // Contact info in a compact grid
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              // Phone
              if (lead.phone.isNotEmpty)
                _buildCompactInfoItem(
                  icon: Icons.phone,
                  text: lead.phone,
                  onTap: () => _handlePhoneCall(lead),
                  isClickable: true,
                ),
              
              // Location
              _buildCompactInfoItem(
                icon: Icons.location_on,
                text: lead.location,
              ),
              
              // Industry
              _buildCompactInfoItem(
                icon: Icons.business,
                text: lead.industry,
              ),
              
              // Website
              if (lead.websiteUrl != null && lead.websiteUrl!.isNotEmpty)
                _buildCompactInfoItem(
                  icon: Icons.language,
                  text: 'Website',
                  onTap: () => LeadDetailUtils.openWebsite(lead.websiteUrl!),
                  isClickable: true,
                ),
              
              // Google Maps
              if (lead.profileUrl != null && lead.profileUrl!.isNotEmpty)
                _buildCompactInfoItem(
                  icon: Icons.map,
                  text: 'Google Maps',
                  onTap: () => LeadDetailUtils.openGoogleMapsProfile(lead.profileUrl!),
                  isClickable: true,
                ),
            ],
          ),
          
          // Callback info if scheduled
          if (lead.status == LeadStatus.callbackScheduled && lead.followUpDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.purple.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 16,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Callback: ${_formatCallbackDate(lead.followUpDate!)}',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
  
  Widget _buildCompactInfoItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isClickable = false,
  }) {
    final widget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isClickable ? AppTheme.primaryGold : Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isClickable ? AppTheme.primaryGold : Colors.white.withOpacity(0.7),
            fontSize: 13,
            decoration: isClickable ? TextDecoration.underline : null,
          ),
        ),
      ],
    );
    
    if (isClickable && onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: widget,
      );
    }
    
    return widget;
  }
  
  String _formatCallbackDate(DateTime date) {
    final now = DateTime.now();
    
    // Compare just the date portions (year, month, day) ignoring time
    final nowDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final daysDifference = targetDate.difference(nowDate).inDays;
    
    if (daysDifference == 0) {
      // Today
      final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
      final period = date.hour < 12 ? 'AM' : 'PM';
      return 'Today at $hour:${date.minute.toString().padLeft(2, '0')} $period';
    } else if (daysDifference == 1) {
      // Tomorrow
      final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
      final period = date.hour < 12 ? 'AM' : 'PM';
      return 'Tomorrow at $hour:${date.minute.toString().padLeft(2, '0')} $period';
    } else if (daysDifference > 1 && daysDifference < 7) {
      // This week
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
      final period = date.hour < 12 ? 'AM' : 'PM';
      return '${weekdays[date.weekday - 1]} at $hour:${date.minute.toString().padLeft(2, '0')} $period';
    } else {
      // Future date
      return '${date.month}/${date.day} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
  
  Widget _buildHeaderSection(Lead lead) {
    // Keeping old method for compatibility, but redirecting to new one
    return _buildCompactHeaderSection(lead);
  }
  
  IconData _getStatusIcon(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_: return Icons.fiber_new;
      case LeadStatus.viewed: return Icons.visibility;
      case LeadStatus.called: return Icons.phone_in_talk;
      case LeadStatus.callbackScheduled: return Icons.event;
      case LeadStatus.interested: return Icons.star;
      case LeadStatus.converted: return Icons.check_circle;
      case LeadStatus.doNotCall: return Icons.phone_disabled;
      case LeadStatus.didNotConvert: return Icons.cancel;
    }
  }


  void _navigateBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/leads');
    }
  }

  void _handleMenuAction(String action) async {
    final lead = await ref.read(leadDetailProvider(widget.leadId).future);
    
    switch (action) {
      case 'delete':
        await _actionsService.deleteLead(lead);
        break;
    }
  }

  Future<void> _handlePhoneCall(Lead lead) async {
    // Track call start time
    final callStartTime = DateTime.now();
    
    // Make the phone call
    await LeadDetailUtils.makePhoneCall(lead.phone);
    
    // Calculate call duration (simulated for now - in production would track actual call)
    final callDuration = Duration(minutes: 4, seconds: 30); // Placeholder
    
    // Show call tracking dialog after call
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => CallTrackingDialog(
          lead: lead,
          callStartTime: callStartTime,
          callDuration: callDuration,
        ),
      );
    }
    
    // If lead is NEW or VIEWED, automatically update to CALLED
    if (lead.status == LeadStatus.new_ || lead.status == LeadStatus.viewed) {
      try {
        final repository = ref.read(leadsRepositoryProvider);
        
        // Update the lead status
        final updatedLead = lead.copyWith(status: LeadStatus.called);
        await repository.updateLead(updatedLead);
        
        // Add timeline entry
        await repository.addTimelineEntry(lead.id, {
          'type': 'STATUS_CHANGE',
          'title': 'Status changed to CALLED',
          'description': 'Lead called directly from phone number',
          'metadata': {
            'auto_updated': true,
            'triggered_by': 'phone_click',
            'previous_status': lead.status.name,
            'new_status': LeadStatus.called.name,
          },
        });
        
        // Refresh the lead details
        ref.invalidate(leadDetailProvider(widget.leadId));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status updated to CALLED'),
              backgroundColor: AppTheme.successGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Failed to update status after call: $e');
      }
    }
  }

  Future<void> _runPageSpeedTest(Lead lead) async {
    if (!lead.hasWebsite || lead.websiteUrl == null) return;
    
    // Start tracking the test status
    ref.read(pageSpeedStatusProvider.notifier).startTest(lead.id);
    
    try {
      await _pageSpeedDataSource.testSingleLead(lead.id);
      
      // The status provider will handle tracking progress
      // and will automatically poll for results
      
      // Periodically refresh lead data while test is running
      Timer.periodic(const Duration(seconds: 3), (timer) {
        final status = ref.read(pageSpeedStatusProvider)[lead.id];
        // Always refresh to get latest data
        ref.invalidate(leadDetailProvider(widget.leadId));
        
        // Stop refreshing after test completes and a delay
        if (status == null || 
            (status.status == PageSpeedTestStatus.completed && 
             status.elapsedTime != null && status.elapsedTime!.inSeconds > 5) ||
            status.status == PageSpeedTestStatus.error) {
          timer.cancel();
        }
      });
      
    } catch (e) {
      // Update status to show error
      ref.read(pageSpeedStatusProvider.notifier).cancelTest(lead.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start PageSpeed test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_: return const Color(0xFF007AFF);
      case LeadStatus.viewed: return const Color(0xFF5856D6);
      case LeadStatus.called: return const Color(0xFFFF9500);
      case LeadStatus.interested: return const Color(0xFF34C759);
      case LeadStatus.converted: return const Color(0xFF30D158);
      case LeadStatus.didNotConvert: return const Color(0xFFFF3B30);
      case LeadStatus.callbackScheduled: return const Color(0xFF5AC8FA);
      case LeadStatus.doNotCall: return const Color(0xFF8E8E93);
    }
  }
  
  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_: return 'NEW';
      case LeadStatus.viewed: return 'VIEWED';
      case LeadStatus.called: return 'CALLED';
      case LeadStatus.interested: return 'INTERESTED';
      case LeadStatus.converted: return 'WON';
      case LeadStatus.didNotConvert: return 'LOST';
      case LeadStatus.callbackScheduled: return 'CALLBACK';
      case LeadStatus.doNotCall: return 'DNC';
    }
  }
}