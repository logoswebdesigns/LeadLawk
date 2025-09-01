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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actionsService = LeadActionsService(ref: ref, context: context);
    _pageSpeedDataSource = PageSpeedDataSource();
  }

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadDetailProvider(widget.leadId));
    final navigationAsync = ref.watch(leadNavigationProvider(widget.leadId));

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildNavigationSection(navigationAsync),
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

  Widget _buildNavigationSection(AsyncValue<LeadNavigationContext> navigationAsync) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return navigationAsync.when(
      data: (navigation) => isMobile 
        ? _buildMobileNavigation(navigation)
        : LeadNavigationBar(navigation: navigation),
      loading: () => _buildNavigationSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
  
  Widget _buildMobileNavigation(LeadNavigationContext navigation) {
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
                  '${navigation.currentIndex + 1} / ${navigation.totalCount}',
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
              color: navigation.nextLead != null 
                ? AppTheme.accentPurple 
                : Theme.of(context).disabledColor,
            ),
            onPressed: navigation.nextLead != null
              ? () => context.go('/leads/${navigation.nextLead!.id}')
              : null,
            tooltip: navigation.nextLead?.businessName ?? 'No next lead',
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
          // Header with business name and basic info
          _buildHeaderSection(lead),
          const SizedBox(height: 16),
          
          // Quick Actions Bar - Most common actions at the top
          QuickActionsBar(
            lead: lead,
            onRefresh: () {
              ref.invalidate(leadDetailProvider(widget.leadId));
            },
          ),
          const SizedBox(height: 16),
          
          // HIGH PRIORITY - Visual content above the fold
          // Screenshots section - responsive layout
          _buildScreenshotsSection(lead, isDesktop, isMobile),
          const SizedBox(height: 16),
          
          // PageSpeed Score - Critical for website evaluation
          if (lead.hasWebsite)
            PageSpeedScoreCard(
              lead: lead,
              onTestPressed: () => _runPageSpeedTest(lead),
            ),
          const SizedBox(height: 16),
          
          // Dynamic Pipeline - Visual status tracking with multiple routes
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
          
          // Business Information Section
          _buildInfoSection(lead),
          const SizedBox(height: 16),
          _buildFlagsSection(lead),
          const SizedBox(height: 24),
          
          // Sales and Follow-up Section
          LeadSalesPitchSection(lead: lead),
          const SizedBox(height: 24),
          
          // Notes and Communication
          const LeadNotesSection(),
          const SizedBox(height: 24),
          
          // Status Actions for terminal states
          LeadStatusActions(lead: lead),
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

  Widget _buildScreenshotsSection(Lead lead, bool isDesktop, bool isMobile) {
    // For mobile: Stack screenshots vertically with consistent aspect ratio
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Maps Screenshot Card
          AspectRatio(
            aspectRatio: 16 / 9,
            child: UnifiedScreenshotCard(
              screenshotPath: lead.screenshotPath,
              type: ScreenshotType.googleMaps,
              lead: lead,
              showInCard: true,
            ),
          ),
          if (lead.hasWebsite && lead.websiteScreenshotPath != null) ...[
            const SizedBox(height: 12),
            // Website Screenshot Card
            AspectRatio(
              aspectRatio: 16 / 9,
              child: UnifiedScreenshotCard(
                screenshotPath: lead.websiteScreenshotPath,
                type: ScreenshotType.website,
                lead: lead,
                showInCard: true,
              ),
            ),
          ],
        ],
      );
    }
    
    // For desktop/tablet: Side by side with consistent height
    final hasWebsiteScreenshot = lead.hasWebsite && lead.websiteScreenshotPath != null;
    
    return SizedBox(
      height: isDesktop ? 400 : 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Maps Screenshot
          Expanded(
            flex: hasWebsiteScreenshot ? 1 : 2,
            child: UnifiedScreenshotCard(
              screenshotPath: lead.screenshotPath,
              type: ScreenshotType.googleMaps,
              lead: lead,
              showInCard: true,
            ),
          ),
          // Website Screenshot if available
          if (hasWebsiteScreenshot) ...[
            const SizedBox(width: 16),
            Expanded(
              child: UnifiedScreenshotCard(
                screenshotPath: lead.websiteScreenshotPath,
                type: ScreenshotType.website,
                lead: lead,
                showInCard: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          Text('Error: $error', style: TextStyle(color: AppTheme.errorRed)),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(Lead lead) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lead.businessName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (lead.rating != null && lead.rating! > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, color: AppTheme.warningOrange, size: 16),
              const SizedBox(width: 4),
              Text(
                '${lead.rating!} (${lead.reviewCount ?? 0} reviews)',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoSection(Lead lead) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lead.phone.isNotEmpty)
          LeadInfoRow(
            icon: Icons.phone,
            text: lead.phone,
            onTap: () => _handlePhoneCall(lead),
          ),
        if (lead.websiteUrl != null && lead.websiteUrl!.isNotEmpty)
          LeadInfoRow(
            icon: Icons.language,
            text: lead.websiteUrl!,
            onTap: () => LeadDetailUtils.openWebsite(lead.websiteUrl!),
          ),
        if (lead.profileUrl != null && lead.profileUrl!.isNotEmpty)
          LeadInfoRow(
            icon: Icons.map,
            text: 'View on Google Maps',
            onTap: () => LeadDetailUtils.openGoogleMapsProfile(lead.profileUrl!),
          ),
        LeadInfoRow(
          icon: Icons.search,
          text: 'Search Google',
          onTap: () => LeadDetailUtils.searchOnGoogle(lead.businessName),
        ),
        LeadInfoRow(
          icon: Icons.location_on,
          text: lead.location,
        ),
        LeadInfoRow(
          icon: Icons.business,
          text: lead.industry,
        ),
      ],
    );
  }

  Widget _buildFlagsSection(Lead lead) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeadFlagRow(
          label: 'Has Website',
          value: lead.hasWebsite,
        ),
        LeadFlagRow(
          label: 'Candidate',
          value: lead.isCandidate,
          description: lead.isCandidate ? 'No website - potential client' : null,
        ),
        LeadFlagRow(
          label: 'Meets Rating Threshold',
          value: lead.meetsRatingThreshold,
        ),
      ],
    );
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
}