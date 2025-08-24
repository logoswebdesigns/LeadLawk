import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/lead.dart';
import '../providers/job_provider.dart';
import '../widgets/server_status_indicator.dart';

final leadsProvider = FutureProvider.family<List<Lead>, Map<String, dynamic>>(
  (ref, params) async {
    final repository = ref.watch(leadsRepositoryProvider);
    final result = await repository.getLeads(
      status: params['status'],
      search: params['search'],
      candidatesOnly: params['candidatesOnly'],
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (leads) => leads,
    );
  },
);

class LeadsListPage extends ConsumerStatefulWidget {
  final String? initialFilter;

  const LeadsListPage({super.key, this.initialFilter});

  @override
  ConsumerState<LeadsListPage> createState() => _LeadsListPageState();
}

class _LeadsListPageState extends ConsumerState<LeadsListPage> {
  final _searchController = TextEditingController();
  String? _statusFilter;
  bool _candidatesOnly = false;
  String? _lastIndustry;
  String? _lastLocation;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter == 'candidates') {
      _candidatesOnly = true;
    }
    _loadLastScrapeContext();
  }

  Future<void> _loadLastScrapeContext() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastIndustry = prefs.getString('last_industry');
      _lastLocation = prefs.getString('last_location');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final params = {
      'status': _statusFilter,
      'search': _searchController.text.isEmpty ? null : _searchController.text,
      'candidatesOnly': _candidatesOnly,
    };
    final leadsAsync = ref.watch(leadsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('LeadLawk'),
        elevation: 2,
        actions: [
          const ServerStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => context.go('/scrape'),
            tooltip: 'Run Scrape',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
        children: [
          if (_lastIndustry != null && _lastLocation != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '$_lastIndustry • $_lastLocation',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search leads...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Candidates Only'),
                        selected: _candidatesOnly,
                        onSelected: (selected) {
                          setState(() => _candidatesOnly = selected);
                        },
                      ),
                      const SizedBox(width: 8),
                      ...LeadStatus.values.map((status) {
                        final isSelected = _statusFilter == 
                            _getStatusLabel(status).toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_getStatusLabel(status)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _statusFilter = selected
                                    ? _getStatusLabel(status).toLowerCase()
                                    : null;
                              });
                            },
                            backgroundColor: isSelected
                                ? _getStatusColor(status).withOpacity(0.2)
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: leadsAsync.when(
              data: (leads) {
                if (leads.isEmpty) {
                  return const Center(
                    child: Text('No leads found'),
                  );
                }
                return ListView.builder(
                  itemCount: leads.length,
                  itemBuilder: (context, index) {
                    final lead = leads[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(lead.status),
                        child: Text(
                          lead.businessName.isNotEmpty
                              ? lead.businessName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(lead.businessName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lead.phone),
                          if (lead.rating != null)
                            Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                Text(' ${lead.rating!.toStringAsFixed(1)}'),
                                if (lead.reviewCount != null)
                                  Text(' (${lead.reviewCount} reviews)'),
                              ],
                            ),
                          Row(
                            children: [
                              if (lead.hasWebsite)
                                const Icon(Icons.language, size: 16, color: Colors.green),
                              if (lead.isCandidate)
                                const Icon(Icons.check_circle, size: 16, color: Colors.blue),
                              if (lead.platformHint != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Chip(
                                    label: Text(
                                      lead.platformHint!,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(
                          _getStatusLabel(lead.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: _getStatusColor(lead.status),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () => context.go('/leads/${lead.id}'),
                    );
                  },
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
          const ServerStatusBadge(),
        ],
      ),
    );
  }
}