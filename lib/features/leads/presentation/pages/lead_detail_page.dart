import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/job_provider.dart';

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
    return '''Hi there! I noticed your business online and wanted to reach out about something that could really help you stand out from your competition.

I specialize in creating professional websites for local businesses like yours. A great website can help you:
• Attract more customers online
• Look more professional and trustworthy  
• Show up better in Google searches
• Give customers an easy way to contact you

I'd love to show you some examples of websites I've built for other businesses in your area. Would you be interested in a quick 10-minute call to discuss how a professional website could help grow your business?

Thanks for your time!''';
  }

  Future<void> _updateStatus(Lead lead, LeadStatus newStatus) async {
    final repository = ref.read(leadsRepositoryProvider);
    final updatedLead = lead.copyWith(status: newStatus);
    await repository.updateLead(updatedLead);
    ref.invalidate(leadDetailProvider(widget.leadId));
  }

  Future<void> _updateNotes(Lead lead) async {
    final repository = ref.read(leadsRepositoryProvider);
    final updatedLead = lead.copyWith(notes: _notesController.text);
    await repository.updateLead(updatedLead);
    setState(() => _isEditingNotes = false);
    _notesFocusNode.unfocus();
    ref.invalidate(leadDetailProvider(widget.leadId));
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
          tooltip: 'Back',
        ),
        title: const Text('Lead Details'),
        elevation: 2,
      ),
      body: leadAsync.when(
        data: (lead) {
          if (!_isEditingNotes) {
            _notesController.text = lead.notes ?? '';
          }

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
                        _buildInfoRow(Icons.phone, lead.phone, () => _launchPhone(lead.phone)),
                        if (lead.websiteUrl != null)
                          _buildInfoRow(Icons.language, lead.websiteUrl!, () => _launchUrl(lead.websiteUrl!)),
                        if (lead.profileUrl != null)
                          _buildInfoRow(Icons.link, 'Google Maps Profile', () => _launchUrl(lead.profileUrl!)),
                        _buildInfoRow(Icons.location_on, lead.location),
                        _buildInfoRow(Icons.business, lead.industry.toUpperCase()),
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
    );
  }

  Widget _buildInfoRow(IconData icon, String text, [VoidCallback? onTap]) {
    final isClickable = onTap != null;
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
                  color: AppTheme.mediumGray,
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
}