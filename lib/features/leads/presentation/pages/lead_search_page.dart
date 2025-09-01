import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/automation_form_provider.dart';
import '../providers/job_provider.dart';
import '../providers/server_status_provider.dart';
import '../widgets/multi_city_input.dart';
import '../widgets/pagespeed_filter.dart';

class LeadSearchPage extends ConsumerStatefulWidget {
  const LeadSearchPage({super.key});

  @override
  ConsumerState<LeadSearchPage> createState() => _LeadSearchPageState();
}

class _LeadSearchPageState extends ConsumerState<LeadSearchPage> {
  final _formKey = GlobalKey<FormState>();
  final _customIndustryController = TextEditingController();
  final _locationController = TextEditingController();
  final _limitController = TextEditingController();

  final List<String> _industries = [
    'Restaurant',
    'Retail Store',
    'Auto Repair Shop',
    'Hair Salon',
    'Barbershop',
    'Nail Salon',
    'Spa',
    'Dentist',
    'Lawyer',
    'Real Estate Agent',
    'Insurance Agent',
    'Accountant',
    'Chiropractor',
    'Veterinarian',
    'Contractor',
    'Plumber',
    'Electrician',
    'HVAC Contractor',
    'Landscaper',
    'Painter',
    'Roofer',
    'Flooring Contractor',
    'Home Remodeling',
    'Cleaning Service',
    'Photographer',
    'Wedding Planner',
    'Catering',
    'Bakery',
    'Florist',
    'Gym/Fitness Center',
    'Personal Trainer',
    'Massage Therapist',
    'Physical Therapist',
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
      body: Stack(
        children: [
          RefreshIndicator(
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Select Multiple Industries:',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (formState.selectedIndustries.isEmpty && !formState.isCustomIndustry)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                                ),
                                              child: const Text(
                                                'Required',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              // Select all industries except Custom
                                              final nonCustomIndustries = _industries.where((i) => i != 'Custom...').toList();
                                              formNotifier.setSelectedIndustries(nonCustomIndustries);
                                            },
                                            child: const Text(
                                              'Select All',
                                              style: TextStyle(color: AppTheme.primaryGold, fontSize: 12),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              formNotifier.clearSelectedIndustries();
                                            },
                                            child: const Text(
                                              'Clear All',
                                              style: TextStyle(color: AppTheme.primaryGold, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _industries.map((industry) {
                                      final isSelected = industry == 'Custom...'
                                          ? formState.isCustomIndustry
                                          : formState.selectedIndustries.any((selected) => selected.toLowerCase() == industry.toLowerCase());
                                      return FilterChip(
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            industry,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : AppTheme.primaryBlue,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
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
                                          if (industry == 'Custom...') {
                                            if (selected) {
                                              formNotifier.setIndustry('custom');
                                            } else {
                                              formNotifier.clearCustomIndustry();
                                            }
                                          } else {
                                            if (selected) {
                                              formNotifier.addIndustry(industry);
                                            } else {
                                              formNotifier.removeIndustry(industry);
                                            }
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
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
                              const SizedBox(height: 24),
                              
                              // Multi-city input replacing the single location field
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
                                child: const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: MultiCityInput(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _limitController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Maximum Results',
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                  hintText: 'How many leads to find',
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
                                  if (limit == null || limit < 1) {
                                    return 'Please enter a valid number greater than 0';
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
                      const SizedBox(height: 24),
                      
                      // Enhanced PageSpeed Testing with Filter
                      const PageSpeedFilter(),
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
                        // Check if at least one industry is selected
                        if (formState.selectedIndustries.isEmpty && !formState.isCustomIndustry) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select at least one industry from the list above'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                        
                        if (formState.isCustomIndustry && (formState.industry.isEmpty || formState.industry == 'custom')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a custom industry name'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        // Check if at least one location is selected
                        if (formState.selectedLocations.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please add at least one city or select a state'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }

                        // Log the request details
                        final params = formState.toParams();
                        print('🚀 START LEAD GENERATION PRESSED');
                        print('📍 Selected Locations: ${formState.selectedLocations}');
                        print('🏢 Selected Industries: ${formState.selectedIndustries.isNotEmpty ? formState.selectedIndustries : [formState.industry]}');
                        print('🎯 Limit: ${formState.limit}');
                        print('⭐ Min Rating: ${formState.minRating}');
                        print('💬 Min Reviews: ${formState.minReviews}');
                        print('🌐 Requires Website: ${formState.requiresWebsite}');
                        print('📅 Recent Reviews (months): ${formState.recentReviewMonths}');
                        print('🚀 Enable PageSpeed: ${formState.enablePagespeed}');
                        print('📊 Max PageSpeed Score: ${formState.maxPagespeedScore}');
                        
                        await jobNotifier.startAutomation(params);

                        // Wait a moment for the state to update
                        await Future.delayed(const Duration(milliseconds: 100));
                        
                        final updatedJobState = ref.read(jobProvider);
                        if (updatedJobState.jobId != null && context.mounted) {
                          // Navigate back to the leads list page
                          context.go('/leads');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  jobState.isRunning ? 'Generating Leads...' : 'Start Lead Generation',
                  maxLines: 1,
                ),
              ),
            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ],
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
