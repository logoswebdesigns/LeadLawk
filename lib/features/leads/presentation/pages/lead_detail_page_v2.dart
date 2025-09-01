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
import '../widgets/lead_timeline.dart';
import '../widgets/pagespeed_score_card.dart';
import '../widgets/quick_actions_bar.dart';
import '../services/lead_actions_service.dart';
import '../../data/datasources/pagespeed_datasource.dart';

class LeadDetailPageV2 extends ConsumerStatefulWidget {
  final String leadId;

  const LeadDetailPageV2({Key? key, required this.leadId}) : super(key: key);

  @override
  ConsumerState<LeadDetailPageV2> createState() => _LeadDetailPageV2State();
}

class _LeadDetailPageV2State extends ConsumerState<LeadDetailPageV2> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final LeadActionsService _actionsService;
  late final PageSpeedDataSource _pageSpeedDataSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actionsService = LeadActionsService(ref: ref, context: context);
    _pageSpeedDataSource = PageSpeedDataSource();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadDetailProvider(widget.leadId));
    final navigationAsync = ref.watch(leadNavigationProvider(widget.leadId));
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final isTablet = MediaQuery.of(context).size.width > 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: leadAsync.when(
        data: (lead) => isDesktop 
          ? _buildDesktopLayout(lead, navigationAsync)
          : _buildMobileLayout(lead, navigationAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  // Desktop: Split view with sidebar
  Widget _buildDesktopLayout(Lead lead, AsyncValue<LeadNavigationContext> navAsync) {
    return Row(
      children: [
        // Left sidebar - 400px fixed width
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: _buildSidebar(lead, navAsync),
        ),
        // Right content area - flexible
        Expanded(
          child: _buildMainContent(lead),
        ),
      ],
    );
  }

  // Mobile: Single column with collapsible sections
  Widget _buildMobileLayout(Lead lead, AsyncValue<LeadNavigationContext> navAsync) {
    return CustomScrollView(
      slivers: [
        // Sticky header with navigation
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.elevatedSurface,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              lead.businessName,
              style: const TextStyle(fontSize: 16),
            ),
            background: _buildHeroSection(lead),
          ),
          bottom: navAsync.maybeWhen(
            data: (nav) => PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildCompactNavigation(nav),
            ),
            orElse: () => null,
          ),
        ),
        // Quick actions
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: QuickActionsBar(
              lead: lead,
              onRefresh: () => ref.invalidate(leadDetailProvider(widget.leadId)),
            ),
          ),
        ),
        // Content cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildInfoCard(lead),
              const SizedBox(height: 16),
              _buildScreenshotsCard(lead),
              const SizedBox(height: 16),
              if (lead.hasWebsite) ...[
                PageSpeedScoreCard(
                  lead: lead,
                  onTestPressed: () => _runPageSpeedTest(lead),
                ),
                const SizedBox(height: 16),
              ],
              _buildTimelineCard(lead),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(Lead lead, AsyncValue<LeadNavigationContext> navAsync) {
    return Column(
      children: [
        // Sticky header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryGold.withOpacity(0.1),
                AppTheme.primaryBlue.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business name and status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.businessName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(lead.status),
                      ],
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.go('/leads'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Navigation controls
              navAsync.maybeWhen(
                data: (nav) => _buildNavigationControls(nav),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        // Scrollable sidebar content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick actions
                QuickActionsBar(
                  lead: lead,
                  onRefresh: () => ref.invalidate(leadDetailProvider(widget.leadId)),
                ),
                const SizedBox(height: 24),
                // Contact information
                _buildContactSection(lead),
                const SizedBox(height: 24),
                // Business metrics
                _buildMetricsSection(lead),
                const SizedBox(height: 24),
                // Notes section
                _buildNotesSection(lead),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(Lead lead) {
    return Column(
      children: [
        // Tabs
        Container(
          color: AppTheme.elevatedSurface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: Colors.white54,
            indicatorColor: AppTheme.primaryBlue,
            tabs: const [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
              Tab(text: 'Website Analysis', icon: Icon(Icons.web, size: 18)),
              Tab(text: 'Activity', icon: Icon(Icons.timeline, size: 18)),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(lead),
              _buildWebsiteTab(lead),
              _buildActivityTab(lead),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Lead lead) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screenshot grid
          _buildScreenshotGrid(lead),
          const SizedBox(height: 32),
          // Key information cards
          _buildKeyInfoGrid(lead),
        ],
      ),
    );
  }

  Widget _buildWebsiteTab(Lead lead) {
    if (!lead.hasWebsite) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.language_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'No website available',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'This business does not have a website listed',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // PageSpeed analysis
          PageSpeedScoreCard(
            lead: lead,
            onTestPressed: () => _runPageSpeedTest(lead),
          ),
          const SizedBox(height: 24),
          // Website screenshot
          _buildWebsitePreview(lead),
        ],
      ),
    );
  }

  Widget _buildActivityTab(Lead lead) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LeadTimeline(
        lead: lead,
        onAddEntry: (entry) {},
        onUpdateEntry: (entry) {},
        onSetFollowUpDate: (date) {},
      ),
    );
  }

  Widget _buildScreenshotGrid(Lead lead) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 16 / 9,
          children: [
            _buildScreenshotCard(
              title: 'Google Maps Listing',
              imagePath: lead.screenshotPath,
              icon: Icons.location_on,
            ),
            if (lead.hasWebsite)
              _buildScreenshotCard(
                title: 'Website',
                imagePath: lead.websiteScreenshotPath,
                icon: Icons.web,
              ),
          ],
        );
      },
    );
  }

  Widget _buildScreenshotCard({
    required String title,
    String? imagePath,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Image
          Expanded(
            child: imagePath != null
              ? ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    'http://localhost:8000/screenshots/${imagePath.split('/').last}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 48, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                        'No screenshot available',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // Helper methods remain the same but with updated styling...
  Widget _buildStatusChip(LeadStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.primaryGold;
      case LeadStatus.viewed:
        return AppTheme.primaryBlue;
      case LeadStatus.called:
        return AppTheme.primaryIndigo;
      case LeadStatus.interested:
        return AppTheme.successGreen;
      case LeadStatus.converted:
        return AppTheme.accentCyan;
      case LeadStatus.doNotCall:
        return AppTheme.errorRed;
      case LeadStatus.callbackScheduled:
        return AppTheme.warningOrange;
      case LeadStatus.didNotConvert:
        return Colors.grey;
    }
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
      case LeadStatus.viewed:
        return 'VIEWED';
      case LeadStatus.called:
        return 'CALLED';
      case LeadStatus.interested:
        return 'INTERESTED';
      case LeadStatus.converted:
        return 'CONVERTED';
      case LeadStatus.doNotCall:
        return 'DNC';
      case LeadStatus.callbackScheduled:
        return 'CALLBACK';
      case LeadStatus.didNotConvert:
        return 'NO CONVERT';
    }
  }

  // Additional helper methods...
  Widget _buildNavigationControls(LeadNavigationContext nav) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: nav.previousLead != null
            ? () => context.go('/leads/${nav.previousLead!.id}')
            : null,
        ),
        Expanded(
          child: Text(
            '${nav.currentIndex + 1} of ${nav.totalCount}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: nav.nextLead != null
            ? () => context.go('/leads/${nav.nextLead!.id}')
            : null,
        ),
      ],
    );
  }

  Widget _buildCompactNavigation(LeadNavigationContext nav) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(nav.previousLead?.businessName ?? 'Start'),
            onPressed: nav.previousLead != null
              ? () => context.go('/leads/${nav.previousLead!.id}')
              : null,
          ),
          Text(
            '${nav.currentIndex + 1} / ${nav.totalCount}',
            style: const TextStyle(fontSize: 12),
          ),
          TextButton.icon(
            label: Text(nav.nextLead?.businessName ?? 'End'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            onPressed: nav.nextLead != null
              ? () => context.go('/leads/${nav.nextLead!.id}')
              : null,
          ),
        ],
      ),
    );
  }

  // Stub methods for missing functionality
  Widget _buildHeroSection(Lead lead) => Container();
  Widget _buildInfoCard(Lead lead) => Container();
  Widget _buildScreenshotsCard(Lead lead) => Container();
  Widget _buildTimelineCard(Lead lead) => Container();
  Widget _buildContactSection(Lead lead) => Container();
  Widget _buildMetricsSection(Lead lead) => Container();
  Widget _buildNotesSection(Lead lead) => Container();
  Widget _buildKeyInfoGrid(Lead lead) => Container();
  Widget _buildWebsitePreview(Lead lead) => Container();
  
  Future<void> _runPageSpeedTest(Lead lead) async {
    // Implementation
  }
}