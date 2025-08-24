import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/job.dart';
import '../providers/scrape_form_provider.dart';
import '../providers/job_provider.dart';

class RunScrapePage extends ConsumerStatefulWidget {
  const RunScrapePage({super.key});

  @override
  ConsumerState<RunScrapePage> createState() => _RunScrapePageState();
}

class _RunScrapePageState extends ConsumerState<RunScrapePage> {
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
      final formState = ref.read(scrapeFormProvider);
      _locationController.text = formState.location;
      _limitController.text = formState.limit.toString();
      if (formState.isCustomIndustry) {
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
    final formState = ref.watch(scrapeFormProvider);
    final formNotifier = ref.read(scrapeFormProvider.notifier);
    final jobState = ref.watch(jobProvider);
    final jobNotifier = ref.read(jobProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/leads'),
        ),
        title: const Text('Run Scrape'),
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Industry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
                      color: isSelected ? Colors.white : AppTheme.primaryIndigo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryIndigo,
                  backgroundColor: AppTheme.lightGray,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryIndigo
                        : AppTheme.primaryIndigo.withOpacity(0.3),
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _customIndustryController,
                decoration: const InputDecoration(
                  labelText: 'Custom Industry',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (formState.isCustomIndustry &&
                      (value == null || value.isEmpty)) {
                    return 'Please enter a custom industry';
                  }
                  return null;
                },
                onChanged: (value) {
                  formNotifier.setIndustry(value);
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Austin, TX',
                border: OutlineInputBorder(),
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
              decoration: const InputDecoration(
                labelText: 'Result Limit',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Advanced Settings'),
              initiallyExpanded: formState.isAdvancedExpanded,
              onExpansionChanged: (expanded) {
                formNotifier.toggleAdvanced();
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent Days: ${formState.recentDays}',
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Slider(
                              value: formState.recentDays.toDouble(),
                              min: 30,
                              max: 730,
                              divisions: 70,
                              label: formState.recentDays.toString(),
                              onChanged: (value) {
                                formNotifier.setRecentDays(value.toInt());
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
                        if (formState.industry.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select an industry'),
                            ),
                          );
                          return;
                        }

                        await jobNotifier.startScrape(formState.toParams());

                        // Wait a moment for the state to update
                        await Future.delayed(const Duration(milliseconds: 100));
                        
                        final updatedJobState = ref.read(jobProvider);
                        if (updatedJobState.jobId != null && context.mounted) {
                          // Navigate to the monitoring page
                          context.go('/scrape/monitor/${updatedJobState.jobId}');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(jobState.isRunning ? 'Running...' : 'Run Scrape'),
            ),
          ],
        ),
      ),
    );
  }
}
