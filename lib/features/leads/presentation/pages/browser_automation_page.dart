import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/automation_form_provider.dart';
import '../providers/job_provider.dart';
import '../providers/server_status_provider.dart';

class BrowserAutomationPage extends ConsumerStatefulWidget {
  const BrowserAutomationPage({super.key});

  @override
  ConsumerState<BrowserAutomationPage> createState() => _BrowserAutomationPageState();
}

class _BrowserAutomationPageState extends ConsumerState<BrowserAutomationPage> {
  final _formKey = GlobalKey<FormState>();
  final _customIndustryController = TextEditingController();
  final _locationController = TextEditingController();
  final _limitController = TextEditingController();

  final List<String> _industries = [
    'Painter',
    'Landscaper',
    'Roofer',
    'Plumber',
    'Electrician',
    'Custom...',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formState = ref.read(automationFormProvider);
      _locationController.text = formState.location;
      _limitController.text = formState.limit.toString();
      if (formState.isCustomIndustry && formState.industry != 'custom') {
        _customIndustryController.text = formState.industry;
      }
    });
  }

  @override
  void dispose() {
    _customIndustryController.dispose();
    _locationController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(automationFormProvider);
    final formNotifier = ref.read(automationFormProvider.notifier);
    final jobState = ref.watch(jobProvider);
    final jobNotifier = ref.read(jobProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh job data
          ref.invalidate(jobsListProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppTheme.primaryGold,
        backgroundColor: AppTheme.backgroundDark,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Find New Leads',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryGold.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: AppTheme.primaryGold,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Recent Jobs Section
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Consumer(
                  builder: (context, ref, _) {
                    final jobsAsync = ref.watch(jobsListProvider);
                    return jobsAsync.when(
                      data: (jobs) {
                        if (jobs.isEmpty) return const SizedBox.shrink();
                        
                        // Show only recent 3 jobs
                        final recentJobs = jobs.take(3).toList();
                        
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue.withOpacity(0.1),
                                AppTheme.primaryBlue.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Header
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => context.go('/server'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.history,
                                            color: AppTheme.primaryBlue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Recent Lead Jobs',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                'View your automation history',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'View All',
                                          style: TextStyle(
                                            color: AppTheme.primaryBlue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          color: AppTheme.primaryBlue,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Job Cards
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                child: Column(
                                  children: [
                                    const Divider(color: AppTheme.backgroundDark),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 140,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: recentJobs.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                                        itemBuilder: (context, index) {
                                          final job = recentJobs[index];
                                          final status = job['status']?.toString() ?? 'unknown';
                                          final jobId = job['job_id']?.toString() ?? '';
                                          final processed = job['processed'] ?? 0;
                                          final total = job['total'] ?? 0;
                                          final color = _getJobStatusColor(status);
                                          
                                          return Container(
                                            width: 200,
                                            decoration: BoxDecoration(
                                              color: AppTheme.elevatedSurface,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: color.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(12),
                                                onTap: () => context.go('/browser/monitor/$jobId'),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            status == 'running' 
                                                                ? Icons.sync 
                                                                : status == 'done' 
                                                                    ? Icons.check_circle
                                                                    : Icons.error,
                                                            color: color,
                                                            size: 16,
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              jobId.length > 15 
                                                                  ? '${jobId.substring(0, 15)}...'
                                                                  : jobId,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: color.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          status.toUpperCase(),
                                                          style: TextStyle(
                                                            color: color,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      if (total > 0) ...[
                                                        LinearProgressIndicator(
                                                          value: (processed / total).toDouble(),
                                                          minHeight: 4,
                                                          backgroundColor: color.withOpacity(0.15),
                                                          valueColor: AlwaysStoppedAnimation<Color>(color),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          '$processed / $total leads',
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.white70,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
            
            // Form Content
            SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGold.withOpacity(0.1),
                              AppTheme.primaryGold.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryGold.withOpacity(0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: AppTheme.primaryGold,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Define Your Search',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Configure parameters for lead generation',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Industry Selection Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryBlue.withOpacity(0.1),
                              AppTheme.primaryBlue.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withOpacity(0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.business,
                                      color: AppTheme.primaryBlue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Industry Type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _industries.map((industry) {
                                  final isSelected = industry == 'Custom...'
                                      ? formState.isCustomIndustry
                                      : formState.industry.toLowerCase() ==
                                          industry.toLowerCase();
                                  return ChoiceChip(
                                    label: Text(
                                      industry,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppTheme.primaryBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: AppTheme.primaryBlue,
                                    backgroundColor: AppTheme.lightGray,
                                    checkmarkColor: Colors.white,
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppTheme.primaryBlue
                                          : AppTheme.primaryBlue.withOpacity(0.3),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        if (industry == 'Custom...') {
                                          formNotifier.setIndustry('custom');
                                        } else {
                                          formNotifier.setIndustry(industry);
                                        }
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              if (formState.isCustomIndustry) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _customIndustryController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Custom Industry',
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                    hintText: 'e.g., HVAC Contractor, Auto Repair Shop',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                    prefixIcon: const Icon(Icons.edit, color: AppTheme.primaryGold),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.primaryGold.withOpacity(0.05),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (formState.isCustomIndustry &&
                                        (value == null || value.isEmpty || value.trim().isEmpty)) {
                                      return 'Please enter a custom industry';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    if (value.trim().isNotEmpty) {
                                      formNotifier.setIndustry(value.trim());
                                    }
                                  },
                                  autofocus: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Search Parameters Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGold.withOpacity(0.1),
                              AppTheme.primaryGold.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryGold.withOpacity(0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGold.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.tune,
                                      color: AppTheme.primaryGold,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Search Parameters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _locationController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Target Location',
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                  hintText: 'e.g., Austin, TX or New York City',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryGold),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.primaryGold.withOpacity(0.05),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a location';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  formNotifier.setLocation(value);
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _limitController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Maximum Results',
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                  hintText: 'How many leads to find (1-200)',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  prefixIcon: const Icon(Icons.format_list_numbered, color: AppTheme.primaryGold),
                                  suffixText: 'leads',
                                  suffixStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.primaryGold.withOpacity(0.05),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a limit';
                                  }
                                  final limit = int.tryParse(value);
                                  if (limit == null || limit < 1 || limit > 200) {
                                    return 'Limit must be between 1 and 200';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  final limit = int.tryParse(value);
                                  if (limit != null) {
                                    formNotifier.setLimit(limit);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 1,
                        child: SwitchListTile(
                          title: const Text('Use Mock Data'),
                          subtitle: Text(
                            formState.useMockData 
                              ? 'Test mode - Using simulated Google Places data'
                              : 'Real mode - Using actual API data',
                            style: TextStyle(
                              color: formState.useMockData ? Colors.orange : Colors.green,
                            ),
                          ),
                          value: formState.useMockData,
                          onChanged: (_) => formNotifier.toggleMockData(),
                          secondary: Icon(
                            formState.useMockData ? Icons.science : Icons.public,
                            color: formState.useMockData ? Colors.orange : AppTheme.primaryGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 1,
                        color: AppTheme.elevatedSurface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.web_outlined, color: AppTheme.primaryGold, size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Lead Generation',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Intelligent lead discovery system',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Extracts real business data directly from Google Maps',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
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
                        elevation: 1,
                        color: AppTheme.elevatedSurface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.tune, color: AppTheme.primaryGold, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Business Search Criteria',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Min Rating: ${formState.minRating.toStringAsFixed(1)}',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Slider(
                                      value: formState.minRating,
                                      min: 0,
                                      max: 5,
                                      divisions: 50,
                                      label: formState.minRating.toStringAsFixed(1),
                                      onChanged: (value) {
                                        formNotifier.setMinRating(value);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Min Reviews: ${formState.minReviews}',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Slider(
                                      value: formState.minReviews.toDouble(),
                                      min: 0,
                                      max: 100,
                                      divisions: 100,
                                      label: formState.minReviews.toString(),
                                      onChanged: (value) {
                                        formNotifier.setMinReviews(value.toInt());
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.web_outlined, size: 18, color: AppTheme.primaryGold),
                                      SizedBox(width: 8),
                                      Text(
                                        'Website Filter',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                      ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Filter businesses by their website presence (ideal prospects have no website)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<bool?>(
                            segments: const [
                              ButtonSegment<bool?>(
                                value: null,
                                label: Text('All Businesses'),
                                icon: Icon(Icons.business, size: 16),
                              ),
                              ButtonSegment<bool?>(
                                value: false,
                                label: Text('No Website'),
                                icon: Icon(Icons.star, size: 16),
                              ),
                              ButtonSegment<bool?>(
                                value: true,
                                label: Text('Has Website'),
                                icon: Icon(Icons.web, size: 16),
                              ),
                            ],
                            selected: {formState.requiresWebsite},
                            onSelectionChanged: (Set<bool?> selection) {
                              formNotifier.setRequiresWebsite(selection.first);
                            },
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: AppTheme.primaryGold,
                              selectedForegroundColor: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.primaryGold),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tip: Businesses without websites are prime prospects for web design services',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryGold.withOpacity(0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Recent Review Activity Filter
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.access_time, size: 18, color: AppTheme.primaryGold),
                              SizedBox(width: 8),
                              Text(
                                'Recent Review Activity',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Filter for businesses with recent customer reviews (active businesses)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Note: This filter requires clicking into business profiles (slower but accurate)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Any timeframe',
                                    suffixText: 'months',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  initialValue: formState.recentReviewMonths?.toString() ?? '',
                                  onChanged: (value) {
                                    final months = value.isEmpty ? null : int.tryParse(value);
                                    formNotifier.setRecentReviewMonths(months);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Slower processing when enabled - only applies after other filters',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Photo Count Filter
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.photo_camera, size: 18, color: AppTheme.primaryGold),
                              SizedBox(width: 8),
                              Text(
                                'Digital Presence (Photos)',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Minimum number of photos (indicates business digital engagement)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Any amount',
                                    suffixText: 'photos',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  initialValue: formState.minPhotos?.toString() ?? '',
                                  onChanged: (value) {
                                    final photos = value.isEmpty ? null : int.tryParse(value);
                                    formNotifier.setMinPhotos(photos);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Higher photo count = more engaged business',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Business Description Quality Filter
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.description, size: 18, color: AppTheme.primaryGold),
                              SizedBox(width: 8),
                              Text(
                                'Business Description Quality',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Minimum description length (indicates business professionalism)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Any length',
                                    suffixText: 'characters',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  initialValue: formState.minDescriptionLength?.toString() ?? '',
                                  onChanged: (value) {
                                    final length = value.isEmpty ? null : int.tryParse(value);
                                    formNotifier.setMinDescriptionLength(length);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Well-described = more professional business',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (jobState.isRunning) ...[
              LinearProgressIndicator(
                value: jobState.currentJob != null &&
                        jobState.currentJob!.total > 0
                    ? jobState.currentJob!.processed /
                        jobState.currentJob!.total
                    : null,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  jobState.currentJob != null
                      ? 'Processed ${jobState.currentJob!.processed} / ${jobState.currentJob!.total}'
                      : 'Starting...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            if (jobState.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        jobState.error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: jobState.isRunning
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        // Check if industry is properly set
                        if (formState.industry.isEmpty || formState.industry == 'custom') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(formState.isCustomIndustry 
                                ? 'Please enter a custom industry name'
                                : 'Please select an industry'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        await jobNotifier.startAutomation(formState.toParams());

                        // Wait a moment for the state to update
                        await Future.delayed(const Duration(milliseconds: 100));
                        
                        final updatedJobState = ref.read(jobProvider);
                        if (updatedJobState.jobId != null && context.mounted) {
                          // Navigate to the monitoring page
                          context.go('/browser/monitor/${updatedJobState.jobId}');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(jobState.isRunning ? 'Generating Leads...' : 'Start Lead Generation'),
            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getJobStatusColor(String status) {
    switch (status) {
      case 'running':
        return AppTheme.primaryBlue;
      case 'done':
        return AppTheme.successGreen;
      case 'error':
        return AppTheme.errorRed;
      default:
        return AppTheme.mediumGray;
    }
  }
}
