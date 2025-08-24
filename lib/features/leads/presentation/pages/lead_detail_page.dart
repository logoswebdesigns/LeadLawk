import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isEditingNotes = false;

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return Colors.grey;
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
    ref.invalidate(leadDetailProvider(widget.leadId));
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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadDetailProvider(widget.leadId));

    return Scaffold(
      appBar: AppBar(
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
                        if (lead.platformHint != null)
                          _buildInfoRow(Icons.info_outline, 'Platform: ${lead.platformHint}'),
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
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: LeadStatus.values.map((status) {
                            return ElevatedButton(
                              onPressed: lead.status == status
                                  ? null
                                  : () => _updateStatus(lead, status),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getStatusColor(status),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_getStatusLabel(status)),
                            );
                          }).toList(),
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
                            Expanded(
                              child: Text(
                                'Notes',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              icon: Icon(_isEditingNotes ? Icons.check : Icons.edit),
                              onPressed: () {
                                if (_isEditingNotes) {
                                  _updateNotes(lead);
                                } else {
                                  setState(() => _isEditingNotes = true);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isEditingNotes)
                          TextField(
                            controller: _notesController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Add notes...',
                              border: OutlineInputBorder(),
                            ),
                          )
                        else
                          Text(
                            lead.notes?.isNotEmpty == true
                                ? lead.notes!
                                : 'No notes yet',
                            style: TextStyle(
                              color: lead.notes?.isNotEmpty == true
                                  ? null
                                  : Colors.grey,
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
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        _buildFlagRow('Has Website', lead.hasWebsite),
                        _buildFlagRow('Meets Rating Threshold', lead.meetsRatingThreshold),
                        _buildFlagRow('Has Recent Reviews', lead.hasRecentReviews),
                        _buildFlagRow('Is Candidate', lead.isCandidate),
                      ],
                    ),
                  ),
                ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  decoration: onTap != null ? TextDecoration.underline : null,
                  color: onTap != null ? Colors.blue : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: value ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}