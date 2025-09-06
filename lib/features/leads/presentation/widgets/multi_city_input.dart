import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/automation_form_provider.dart';
import '../providers/cities_provider.dart';

class MultiCityInput extends ConsumerStatefulWidget {
  const MultiCityInput({super.key});

  @override
  ConsumerState<MultiCityInput> createState() => _MultiCityInputState();
}

class _MultiCityInputState extends ConsumerState<MultiCityInput> {
  final TextEditingController _cityController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoadingCities = false;
  
  @override
  void initState() {
    super.initState();
    // Add listener to rebuild when focus changes for border effect
    _focusNode.addListener(() {
      setState(() {});
    });
  }
  
  // US States list
  final List<String> _usStates = [
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
    'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
    'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana',
    'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota',
    'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada',
    'New Hampshire', 'New Jersey', 'New Mexico', 'New York',
    'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon',
    'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota',
    'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington',
    'West Virginia', 'Wisconsin', 'Wyoming'
  ];

  @override
  void dispose() {
    _cityController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addCity() {
    final city = _cityController.text.trim();
    if (city.isNotEmpty) {
      // Add state abbreviation if not already present
      String formattedCity = city;
      if (!city.contains(',')) {
        // If no comma, assume it needs state abbreviation
        // You could enhance this with a default state or smarter logic
        formattedCity = city;
      }
      ref.read(automationFormProvider.notifier).addLocation(formattedCity);
      _cityController.clear();
      _focusNode.requestFocus();
    }
  }
  
  
  Future<void> _loadAllCitiesInState(String state) async {
    setState(() {
      _isLoadingCities = true;
    });
    
    try {
      // Use the proper data source through provider
      final citiesAsync = await ref.read(citiesForStateProvider(state).future);
      
      if (citiesAsync.isNotEmpty) {
        final formNotifier = ref.read(automationFormProvider.notifier);
        for (final city in citiesAsync) {
          formNotifier.addLocation(city);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${citiesAsync.length} cities from $state'),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No cities found for $state. Try adding cities manually.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cities: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingCities = false;
      });
    }
  }
  
  void _showStateSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text(
            'Select State',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _usStates.length,
              itemBuilder: (context, index) {
                final state = _usStates[index];
                return ListTile(
                  title: Text(
                    state,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _loadAllCitiesInState(state);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(automationFormProvider);
    final formNotifier = ref.read(automationFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_city,
                color: AppTheme.primaryGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Target Cities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${formState.selectedLocations.length} selected',
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            // Add entire state button
            TextButton.icon(
              onPressed: _isLoadingCities ? null : _showStateSelectionDialog,
              icon: _isLoadingCities 
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    ),
                  )
                : const Icon(Icons.map, size: 16),
              label: Text(
                _isLoadingCities ? 'Loading...' : 'Add State',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
              ),
            ),
            if (formState.selectedLocations.isNotEmpty)
              TextButton(
                onPressed: () => formNotifier.clearSelectedLocations(),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Enhanced input field with chips inside
        Container(
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNode.hasFocus 
                ? AppTheme.primaryGold 
                : Colors.transparent,
              width: _focusNode.hasFocus ? 2 : 0,
            ),
          ),
          child: Column(
            children: [
              // Chips inside the field
              if (formState.selectedLocations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: formState.selectedLocations.map((city) {
                      return Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                city,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => formNotifier.removeLocation(city),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              
              // Input field
              Focus(
                onKeyEvent: (FocusNode node, KeyEvent event) {
                  if (event is KeyDownEvent && 
                      event.logicalKey == LogicalKeyboardKey.tab) {
                    // Add city and prevent tab navigation
                    _addCity();
                    return KeyEventResult.handled; // Consume the tab key event
                  }
                  return KeyEventResult.ignored;
                },
                child: TextFormField(
                  controller: _cityController,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    // Trigger rebuild to update suffix icon
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: formState.selectedLocations.isEmpty 
                      ? 'Type city name and press Tab or Enter...'
                      : 'Add another city...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    suffixIcon: _cityController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: AppTheme.primaryGold,
                          ),
                          onPressed: _addCity,
                        )
                      : null,
                    filled: true,
                    fillColor: Colors.transparent, // Make the field background transparent
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onFieldSubmitted: (_) => _addCity(),
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
        ),
        
        if (formState.selectedLocations.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Add at least one city to search',
              style: TextStyle(
                color: Colors.orange.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        
        // Info message about multi-city and state-wide search
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryBlue.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pro tip: Use "Add State" to search all cities in an entire state!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Multiple cities × multiple industries = maximum lead generation!',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}