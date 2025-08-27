import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../providers/job_provider.dart';
import '../widgets/lead_timeline.dart';
import 'leads_list_page_v2.dart' show leadsProvider;

final leadDetailProvider = FutureProvider.family<Lead, String>(
  (ref, id) async {
    final repository = ref.watch(leadsRepositoryProvider);
    final result = await repository.getLead(id);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (lead) => lead,
    );
  },
);

// Provider for lead navigation context
final leadNavigationProvider = FutureProvider.family<LeadNavigationContext, String>(
  (ref, currentLeadId) async {
    // Get the same filtered leads that are shown in the leads list
    final leads = await ref.watch(leadsProvider.future);
    
    final currentIndex = leads.indexWhere((lead) => lead.id == currentLeadId);
    if (currentIndex == -1) {
      throw Exception('Lead not found in current list');
    }
    
    return LeadNavigationContext(
      currentLead: leads[currentIndex],
      previousLead: currentIndex > 0 ? leads[currentIndex - 1] : null,
      nextLead: currentIndex < leads.length - 1 ? leads[currentIndex + 1] : null,
      currentIndex: currentIndex,
      totalCount: leads.length,
    );
  },
);

class LeadNavigationContext {
  final Lead currentLead;
  final Lead? previousLead;
  final Lead? nextLead;
  final int currentIndex;
  final int totalCount;
  
  const LeadNavigationContext({
    required this.currentLead,
    this.previousLead,
    this.nextLead,
    required this.currentIndex,
    required this.totalCount,
  });
}

class LeadDetailPage extends ConsumerStatefulWidget {
  final String leadId;

  const LeadDetailPage({super.key, required this.leadId});

  @override
  ConsumerState<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends ConsumerState<LeadDetailPage> {
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  bool _isEditingNotes = false;
  String _salesPitch = '';
  bool _isEnsureLeadCreatedRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSalesPitch();
  }

  Future<void> _loadSalesPitch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _salesPitch = prefs.getString('sales_pitch') ?? _getDefaultSalesPitch();
    });
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return Colors.grey;
      case LeadStatus.viewed:
        return Colors.blueGrey;
      case LeadStatus.called:
        return Colors.orange;
      case LeadStatus.interested:
        return Colors.blue;
      case LeadStatus.converted:
        return Colors.green;
      case LeadStatus.dnc:
        return Colors.black;
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
      case LeadStatus.dnc:
        return 'DNC';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).round();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference < 365) {
      final months = (difference / 30).round();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  String _formatSource(String source) {
    switch (source.toLowerCase()) {
      case 'browser_automation':
        return 'Google Maps (Browser Automation)';
      case 'google_maps':
        return 'Google Maps';
      case 'manual':
        return 'Manual Entry';
      default:
        return source.replaceAll('_', ' ').split(' ').map((word) => 
            word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
    }
  }

  String _getDefaultSalesPitch() {
    return '''Hey, is this [BUSINESS NAME]?

Awesome! My name is [YOUR NAME] and I'm actually a [YOUR BACKGROUND - e.g., stay-at-home parent, freelance] web developer. I found you on Google and took a look at your site - it's a pretty standard WordPress site that could use some work, and I wanted to call and see if I can help make you something better.

[If they don't have a website: "I found you on Google but didn't see a website anywhere, so I wanted to call and see if you needed any help with one."]

When they ask about cost:

I do things a little different - I charge \$0 down and \$150 a month. That includes hosting, unlimited edits, 24/7 support, lifetime updates, analytics, help with your Google Profile, the works. I do everything for you so you never have to worry about it. 6 month minimum contract and month-to-month after that, cancel anytime.

What makes my work different:

I custom code everything line by line - no page builders. This makes your site load instantly and makes Google happy. Google's core vitals update heavily favors mobile performance and speed in search rankings. Right now, your site scores around 30-40 out of 100 - that's terrible for ranking. My sites score 98-100 and are literally as fast as they can be.

Page builders have bloated code, are prone to hacking, and have very messy code. My sites are custom-built to convert traffic into customers by satisfying Google's metrics and making the best performing mobile site possible with keyword-rich content.

For every second of load time, you lose customers who didn't want to wait. When it loads instantly, people stay and convert instead of leaving.

I also use website conversion funnels - there's a specific order you place content and how you write it that guides visitors into a sale. You can't just throw whatever up and expect it to work. It's all calculated, purposeful, and deliberate. I even hire a copywriter to write all your content with keyword research designed to get picked up in search engines and get people to contact you.

When they ask about the monthly fee:

Think about it this way - if the website brings in just one new customer a month, it more than pays for itself. If it brings in 10 or more, imagine that return. The website becomes an asset to your business. That \$150 isn't just the site cost - it's access to me. It's a retainer to call me with any questions and make all your edits. It's peace of mind - I'm here for you so you don't waste time figuring this stuff out when you could be making money instead.

When you cancel, you keep your domain, but the design and code stay with me. You'd have to start over with someone else, which means you'll be 6 months behind where you could have been. It takes 6-12 months for Google to properly rank your site, so after six months you'll start seeing results and want to stick around.

I'm looking for people who understand websites are a long-term investment, not a turnkey product. If you don't see yourself sticking around long-term or aren't 100% committed to improving your online presence, I might not be the right fit. I don't want to waste your time and money if you aren't 100% committed.

The Process:
1. I send a contract to get signed electronically
2. First invoice for this month's work, then \$150 auto-bills on the 1st each month
3. I email you questions about your business and send design examples
4. My designer creates something unique based on your preferences
5. We review the design together and make any changes
6. I code it, optimize everything to score 98-100, add analytics, and set it live

What questions do you have about any of this?''';
  }

  Future<void> _updateStatus(Lead lead, LeadStatus newStatus) async {
    final repository = ref.read(leadsRepositoryProvider);
    
    // Create timeline entry for status change
    final timelineEntry = LeadTimelineEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      leadId: lead.id,
      type: TimelineEntryType.statusChange,
      title: 'Status changed to ${_getStatusLabel(newStatus)}',
      description: lead.status != newStatus 
          ? 'Changed from ${_getStatusLabel(lead.status)} to ${_getStatusLabel(newStatus)}'
          : null,
      previousStatus: lead.status,
      newStatus: newStatus,
      createdAt: DateTime.now(),
    );

    final updatedLead = lead.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    ).addTimelineEntry(timelineEntry);

    await repository.updateLead(updatedLead);
    ref.invalidate(leadDetailProvider(widget.leadId));
  }

  Future<void> _addTimelineEntry(Lead lead, LeadTimelineEntry entry) async {
    final repository = ref.read(leadsRepositoryProvider);
    final updatedLead = lead.addTimelineEntry(entry);
    await repository.updateLead(updatedLead);
    ref.invalidate(leadDetailProvider(widget.leadId));
  }

  Future<void> _updateTimelineEntry(Lead lead, LeadTimelineEntry entry) async {
    final repository = ref.read(leadsRepositoryProvider);
    final updatedLead = lead.updateTimelineEntry(entry);
    await repository.updateLead(updatedLead);
    ref.invalidate(leadDetailProvider(widget.leadId));
  }

  Future<void> _setFollowUpDate(Lead lead, DateTime? date) async {
    final repository = ref.read(leadsRepositoryProvider);
    final updatedLead = lead.copyWith(
      followUpDate: date,
      updatedAt: DateTime.now(),
    );
    await repository.updateLead(updatedLead);
    ref.invalidate(leadDetailProvider(widget.leadId));
  }

  Future<Lead> _ensureLeadCreatedEntry(Lead lead) async {
    // Prevent concurrent executions
    if (_isEnsureLeadCreatedRunning) {
      print('DEBUG: _ensureLeadCreatedEntry already running, skipping');
      return lead;
    }
    
    _isEnsureLeadCreatedRunning = true;
    print('DEBUG: _ensureLeadCreatedEntry called for lead ${lead.id}');
    print('DEBUG: Current timeline length: ${lead.timeline.length}');
    
    try {
      // Check if there's already a lead created entry
      final hasLeadCreatedEntry = lead.timeline.any(
        (entry) => entry.type == TimelineEntryType.leadCreated,
      );
      
      print('DEBUG: Has lead created entry: $hasLeadCreatedEntry');
      
      if (!hasLeadCreatedEntry) {
        try {
          print('DEBUG: Creating lead created entry...');
          
          // Create the lead created entry
          final leadCreatedEntry = LeadTimelineEntry(
            id: '${lead.id}_created',
            leadId: lead.id,
            type: TimelineEntryType.leadCreated,
            title: 'Lead Generated',
            description: 'Lead discovered and added to pipeline from ${_formatSource(lead.source)}',
            createdAt: lead.createdAt,
          );
          
          print('DEBUG: Lead created entry: ${leadCreatedEntry.title}');
          
          // Add the entry and update the lead
          final repository = ref.read(leadsRepositoryProvider);
          final updatedLead = lead.addTimelineEntry(leadCreatedEntry);
          
          print('DEBUG: Updated lead timeline length: ${updatedLead.timeline.length}');
          
          await repository.updateLead(updatedLead);
          
          print('DEBUG: Successfully updated lead in repository');
          
          return updatedLead;
        } catch (e) {
          // If update fails, just return the original lead
          print('Failed to add lead created entry: $e');
          return lead;
        }
      }
      
      print('DEBUG: Lead already has created entry, returning original');
      return lead;
    } finally {
      _isEnsureLeadCreatedRunning = false;
    }
  }

  Future<void> _updateNotes(Lead lead) async {
    try {
      final repository = ref.read(leadsRepositoryProvider);
      final notesText = _notesController.text.trim();
      final updatedLead = lead.copyWith(notes: notesText.isEmpty ? null : notesText);
      
      final result = await repository.updateLead(updatedLead);
      
      result.fold(
        (failure) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update notes: ${failure.message}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        },
        (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notes updated successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          setState(() => _isEditingNotes = false);
          _notesFocusNode.unfocus();
          ref.invalidate(leadDetailProvider(widget.leadId));
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating notes: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _startEditingNotes() {
    setState(() => _isEditingNotes = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notesFocusNode.requestFocus();
    });
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _searchGoogle(Lead lead) async {
    final locationParts = lead.location.split(',');
    final city = locationParts.first.trim();
    
    final query = '${lead.businessName} $city';
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('https://www.google.com/search?q=$encodedQuery');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteLead(Lead lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lead?'),
        content: Text('Are you sure you want to delete "${lead.businessName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Direct API call to delete the lead
        final dio = ref.read(dioProvider);
        await dio.delete('http://localhost:8000/leads/${lead.id}');
        
        // Invalidate the lead detail cache
        ref.invalidate(leadDetailProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lead.businessName} deleted')),
          );
          context.go('/leads');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadDetailProvider(widget.leadId));
    final navigationAsync = ref.watch(leadNavigationProvider(widget.leadId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Fallback to leads list if no route to pop
              context.go('/leads');
            }
          },
          tooltip: 'Back to leads list',
        ),
        title: const Text('Lead Details'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // Lead Navigation Bar
          navigationAsync.when(
            data: (navigation) => _buildLeadNavigationBar(context, navigation),
            loading: () => _buildLeadNavigationBarSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Main content
          Expanded(
            child: leadAsync.when(
        data: (lead) {
          // Only update the notes controller if we're not currently editing
          // and the controller text is different from the lead's notes
          if (!_isEditingNotes && _notesController.text != (lead.notes ?? '')) {
            _notesController.text = lead.notes ?? '';
          }
          
          // Ensure lead has a created timeline entry
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final updatedLead = await _ensureLeadCreatedEntry(lead);
            if (updatedLead != lead) {
              // Only invalidate if we actually added an entry
              ref.invalidate(leadDetailProvider(widget.leadId));
            }
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lead.businessName,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            Chip(
                              label: Text(
                                _getStatusLabel(lead.status),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: _getStatusColor(lead.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Follow-up Date Display
                        if (lead.followUpDate != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lead.hasOverdueFollowUp 
                                  ? AppTheme.errorRed.withOpacity(0.1)
                                  : AppTheme.warningOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: lead.hasOverdueFollowUp 
                                    ? AppTheme.errorRed
                                    : AppTheme.warningOrange,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  lead.hasOverdueFollowUp ? Icons.warning : Icons.schedule,
                                  color: lead.hasOverdueFollowUp 
                                      ? AppTheme.errorRed
                                      : AppTheme.warningOrange,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lead.hasOverdueFollowUp 
                                            ? 'OVERDUE FOLLOW-UP'
                                            : 'FOLLOW-UP SCHEDULED',
                                        style: TextStyle(
                                          color: lead.hasOverdueFollowUp 
                                              ? AppTheme.errorRed
                                              : AppTheme.warningOrange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('EEEE, MMM d, yyyy • h:mm a').format(lead.followUpDate!.toLocal()),
                                        style: TextStyle(
                                          color: lead.hasOverdueFollowUp 
                                              ? AppTheme.errorRed
                                              : AppTheme.warningOrange,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        _buildInfoRow(Icons.phone, lead.phone, () => _launchPhone(lead.phone)),
                        if (lead.websiteUrl != null)
                          _buildInfoRow(Icons.language, lead.websiteUrl!, () => _launchUrl(lead.websiteUrl!)),
                        if (lead.profileUrl != null)
                          _buildInfoRow(Icons.link, 'Google Maps Profile', () => _launchUrl(lead.profileUrl!)),
                        _buildInfoRow(Icons.search, 'Search on Google', () => _searchGoogle(lead)),
                        _buildInfoRow(Icons.location_on, lead.location),
                        _buildInfoRow(Icons.business, lead.industry.toUpperCase()),
                        const SizedBox(height: 16),
                        _buildScreenshotSection(lead.screenshotPath),
                        if (lead.rating != null)
                          _buildInfoRow(
                            Icons.star,
                            '${lead.rating!.toStringAsFixed(1)} stars (${lead.reviewCount ?? 0} reviews)',
                          ),
                        if (lead.lastReviewDate != null)
                          _buildInfoRow(
                            Icons.schedule,
                            'Last Review: ${_formatDate(lead.lastReviewDate!)}',
                          )
                        else if (lead.reviewCount != null && lead.reviewCount! > 0)
                          _buildInfoRow(
                            Icons.schedule,
                            'Last Review: Date not available',
                          ),
                        if (lead.platformHint != null)
                          _buildInfoRow(Icons.info_outline, 'Platform: ${lead.platformHint}'),
                        _buildInfoRow(Icons.source, 'Source: ${_formatSource(lead.source)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...LeadStatus.values.map((status) {
                              final label = _getStatusLabel(status);
                              final isCurrentStatus = lead.status == status;
                              return Semantics(
                                label: isCurrentStatus 
                                    ? '$label (current status)' 
                                    : 'Mark as $label',
                                button: true,
                                enabled: !isCurrentStatus,
                                child: ElevatedButton(
                                  onPressed: isCurrentStatus
                                      ? null
                                      : () => _updateStatus(lead, status),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getStatusColor(status),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: _getStatusColor(status).withOpacity(0.6),
                                  ),
                                  child: Text(label),
                                ),
                              );
                            }).toList(),
                            if (lead.status != LeadStatus.new_)
                              Semantics(
                                label: 'Mark as unread',
                                button: true,
                                child: OutlinedButton.icon(
                                  onPressed: () => _updateStatus(lead, LeadStatus.new_),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: Icon(Icons.mark_as_unread, size: 16),
                                  label: Text('Mark Unread'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _isEditingNotes
                            ? TextField(
                                controller: _notesController,
                                focusNode: _notesFocusNode,
                                maxLines: null,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add your notes here...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.withOpacity(0.6),
                                    fontSize: 15,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryGold,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.03),
                                ),
                                cursorColor: AppTheme.primaryGold,
                                onSubmitted: (_) => _updateNotes(lead),
                                onTapOutside: (_) => _updateNotes(lead),
                              )
                            : GestureDetector(
                                onTap: _startEditingNotes,
                                child: Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(minHeight: 120),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    lead.notes?.isNotEmpty == true
                                        ? lead.notes!
                                        : 'Tap to add notes...',
                                    style: TextStyle(
                                      color: lead.notes?.isNotEmpty == true
                                          ? Colors.white.withOpacity(0.9)
                                          : Colors.grey,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Sales Pitch',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                context.go('/account');
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 100),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _salesPitch,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Timeline Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LeadTimeline(
                      lead: lead,
                      onAddEntry: (entry) => _addTimelineEntry(lead, entry),
                      onUpdateEntry: (entry) => _updateTimelineEntry(lead, entry),
                      onSetFollowUpDate: (date) => _setFollowUpDate(lead, date),
                      onLeadUpdated: (updatedLead) {
                        // Update the provider with new lead data
                        ref.invalidate(leadDetailProvider(widget.leadId));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qualification Flags',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFlagRow('Has Website', lead.hasWebsite, 
                            lead.hasWebsite ? 'Business has existing website' : 'Prime prospect for web design services'),
                        _buildFlagRow('Meets Rating Threshold', lead.meetsRatingThreshold,
                            lead.meetsRatingThreshold ? 'Rating meets minimum criteria' : 'Below minimum rating threshold'),
                        _buildFlagRow('Has Recent Reviews', lead.hasRecentReviews,
                            lead.hasRecentReviews 
                                ? (lead.lastReviewDate != null 
                                    ? 'Last review: ${_formatDate(lead.lastReviewDate!)}' 
                                    : 'Recent customer engagement')
                                : (lead.lastReviewDate != null
                                    ? 'Last review: ${_formatDate(lead.lastReviewDate!)} (too old)'
                                    : 'Low recent review activity')),
                        _buildFlagRow('Is Candidate', lead.isCandidate,
                            lead.isCandidate ? 'Qualified lead candidate' : 'May not meet all criteria'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Delete Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteLead(lead),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text(
                      'Delete Lead',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadNavigationBar(BuildContext context, LeadNavigationContext navigation) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Previous Lead Button
          Expanded(
            child: _buildNavigationButton(
              context: context,
              lead: navigation.previousLead,
              isNext: false,
              onTap: navigation.previousLead != null 
                ? () => _navigateToLead(context, navigation.previousLead!.id)
                : null,
            ),
          ),
          
          // Current Lead Info
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  navigation.currentLead.businessName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${navigation.currentIndex + 1} of ${navigation.totalCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Next Lead Button
          Expanded(
            child: _buildNavigationButton(
              context: context,
              lead: navigation.nextLead,
              isNext: true,
              onTap: navigation.nextLead != null 
                ? () => _navigateToLead(context, navigation.nextLead!.id)
                : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required BuildContext context,
    required Lead? lead,
    required bool isNext,
    required VoidCallback? onTap,
  }) {
    if (lead == null) {
      return Container(
        height: 56,
        alignment: isNext ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).disabledColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            isNext ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
            size: 18,
            color: Theme.of(context).disabledColor,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: isNext ? [
            // Next button layout: Text | Arrow
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Next',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentPurple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lead.businessName,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: AppTheme.accentPurple,
              ),
            ),
          ] : [
            // Previous button layout: Arrow | Text
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.arrow_back_ios,
                size: 18,
                color: AppTheme.accentPurple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Previous',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentPurple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lead.businessName,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadNavigationBarSkeleton() {
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 80,
      child: Row(
        children: [
          // Previous skeleton
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).disabledColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 14,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).disabledColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Center skeleton
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          
          // Next skeleton
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        height: 12,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).disabledColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 14,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Theme.of(context).disabledColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLead(BuildContext context, String leadId) {
    // Navigate to the new lead using the same route pattern
    context.go('/leads/$leadId');
  }

  Widget _buildInfoRow(IconData icon, String text, [VoidCallback? onTap]) {
    final isClickable = onTap != null;
    
    // Get unique color based on icon type
    Color getIconColor(IconData icon) {
      if (icon == Icons.phone) return AppTheme.successGreen;
      if (icon == Icons.language) return AppTheme.primaryBlue;
      if (icon == Icons.link) return AppTheme.primaryBlue;
      if (icon == Icons.search) return AppTheme.primaryGold;
      if (icon == Icons.location_on) return AppTheme.accentCyan;
      if (icon == Icons.business) return AppTheme.primaryIndigo;
      if (icon == Icons.star) return AppTheme.warningOrange;
      if (icon == Icons.schedule) return AppTheme.accentPurple;
      if (icon == Icons.info_outline) return AppTheme.mediumGray;
      if (icon == Icons.source) return AppTheme.accentCyan;
      return AppTheme.mediumGray;
    }
    
    final iconColor = getIconColor(icon);
    
    return Semantics(
      button: isClickable,
      label: isClickable ? 'Open $text' : text,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  icon, 
                  size: 20, 
                  color: iconColor,
                  semanticLabel: null, // Icon is decorative, label is on parent
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      decoration: isClickable ? TextDecoration.underline : null,
                      color: isClickable 
                          ? AppTheme.primaryGold 
                          : Colors.white.withOpacity(0.9),
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isClickable)
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: AppTheme.primaryGold.withOpacity(0.7),
                    semanticLabel: null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlagRow(String label, bool value, [String? description]) {
    return Semantics(
      label: '$label: ${value ? "Yes" : "No"}${description != null ? " - $description" : ""}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  value ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: value ? AppTheme.successGreen : AppTheme.errorRed.withOpacity(0.8),
                  semanticLabel: null, // Semantic label is on parent
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScreenshotSection(String? screenshotPath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.camera_alt,
              size: 20,
              color: AppTheme.accentPurple,
            ),
            const SizedBox(width: 8),
            Text(
              'Business Screenshot',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: screenshotPath != null ? () => _showFullScreenshot(screenshotPath) : null,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: screenshotPath != null
                  ? Image.network(
                      'http://localhost:8000/screenshots/$screenshotPath',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppTheme.accentPurple,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _buildNoScreenshotPlaceholder('Failed to load screenshot');
                      },
                    )
                  : _buildNoScreenshotPlaceholder('No screenshot available for this lead'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoScreenshotPlaceholder(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Screenshots are captured for new leads during automation',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showFullScreenshot(String screenshotPath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      'http://localhost:8000/screenshots/$screenshotPath',
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppTheme.accentPurple,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 64,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load screenshot',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 40,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}