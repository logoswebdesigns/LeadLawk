import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SmartSearchInput extends StatefulWidget {
  final Function(List<Map<String, String>>) onSearchesGenerated;
  
  const SmartSearchInput({
    super.key,
    required this.onSearchesGenerated,
  });

  @override
  State<SmartSearchInput> createState() => _SmartSearchInputState();
}

class _SmartSearchInputState extends State<SmartSearchInput> {
  final _searchController = TextEditingController();
  final List<String> _searchQueries = [];
  
  // Common state abbreviations (focusing on midwest/central US)
  static const Map<String, String> stateNames = {
    // Central/Midwest
    'NE': 'Nebraska',
    'IA': 'Iowa', 
    'KS': 'Kansas',
    'MO': 'Missouri',
    'SD': 'South Dakota',
    'ND': 'North Dakota',
    'MN': 'Minnesota',
    'WI': 'Wisconsin',
    'IL': 'Illinois',
    'CO': 'Colorado',
    'WY': 'Wyoming',
    'MT': 'Montana',
    // Add more as needed
    'OK': 'Oklahoma',
    'TX': 'Texas',
    'AR': 'Arkansas',
    'IN': 'Indiana',
    'MI': 'Michigan',
    'OH': 'Ohio',
  };
  
  // Major cities by state for state-wide searches
  static const Map<String, List<String>> majorCitiesByState = {
    'Nebraska': ['Omaha', 'Lincoln', 'Grand Island', 'Kearney', 'Fremont'],
    'Iowa': ['Des Moines', 'Cedar Rapids', 'Davenport', 'Sioux City', 'Iowa City'],
    'Kansas': ['Wichita', 'Overland Park', 'Kansas City', 'Topeka', 'Olathe'],
    'Missouri': ['Kansas City', 'St. Louis', 'Springfield', 'Columbia', 'Independence'],
  };
  
  void _addSearchQuery() {
    final query = _searchController.text.trim();
    
    // Validation
    if (query.isEmpty) {
      _showError('Please enter a search query');
      return;
    }
    
    if (_searchQueries.contains(query)) {
      _showError('This search is already added');
      return;
    }
    
    if (_searchQueries.length >= 20) {
      _showError('Maximum 20 searches allowed per batch');
      return;
    }
    
    // Validate format
    if (!_isValidQuery(query)) {
      _showError('Invalid format. Use: "industry in location" or "industry state"');
      return;
    }
    
    setState(() {
      _searchQueries.add(query);
      _searchController.clear();
    });
    _generateSearches();
  }
  
  bool _isValidQuery(String query) {
    // Basic validation - at least 2 characters
    if (query.length < 2) return false;
    
    // Check for basic patterns
    final words = query.split(' ');
    if (words.isEmpty) return false;
    
    // Industry should be at least 3 chars
    if (words[0].length < 3) return false;
    
    return true;
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _removeQuery(String query) {
    setState(() {
      _searchQueries.remove(query);
    });
    _generateSearches();
  }
  
  void _generateSearches() {
    final searches = <Map<String, String>>[];
    
    for (final query in _searchQueries) {
      final parsedSearches = _parseSearchQuery(query);
      searches.addAll(parsedSearches);
    }
    
    widget.onSearchesGenerated(searches);
  }
  
  List<Map<String, String>> _parseSearchQuery(String query) {
    final searches = <Map<String, String>>[];
    
    // Parse format: "industry in location" or just "industry location"
    final parts = query.toLowerCase().split(' in ');
    String industry = '';
    String location = '';
    
    if (parts.length == 2) {
      industry = parts[0].trim();
      location = parts[1].trim();
    } else {
      // Try to split by common patterns
      final words = query.split(' ');
      if (words.length >= 2) {
        // Assume first word is industry, rest is location
        industry = words[0];
        location = words.sublist(1).join(' ');
      } else {
        // Single word - treat as industry in all configured cities
        industry = query;
        location = 'all';
      }
    }
    
    // Normalize industry
    industry = _normalizeIndustry(industry);
    
    // Expand location
    final locations = _expandLocation(location);
    
    // Create search combinations
    for (final loc in locations) {
      searches.add({
        'industry': industry,
        'location': loc,
        'use_expansion': 'true', // Let backend handle suburb expansion
      });
    }
    
    return searches;
  }
  
  String _normalizeIndustry(String industry) {
    // Common industry mappings
    final mappings = {
      'painter': 'painting',
      'plumber': 'plumbing',
      'electrician': 'electrical',
      'landscaper': 'landscaping',
      'roofer': 'roofing',
      'cleaner': 'cleaning',
    };
    
    return mappings[industry.toLowerCase()] ?? industry;
  }
  
  List<String> _expandLocation(String location) {
    final locations = <String>[];
    
    // Check if it's a state name or abbreviation
    final upperLocation = location.toUpperCase();
    if (stateNames.containsKey(upperLocation)) {
      // State abbreviation - expand to major cities
      final stateName = stateNames[upperLocation]!;
      final cities = majorCitiesByState[stateName] ?? [];
      for (final city in cities) {
        locations.add('$city, $upperLocation');
      }
    } else if (majorCitiesByState.containsKey(location.split(',')[0].trim())) {
      // Full state name - expand to major cities
      final cities = majorCitiesByState[location.split(',')[0].trim()] ?? [];
      final stateAbbr = stateNames.entries
          .firstWhere((e) => e.value == location.split(',')[0].trim(), 
                      orElse: () => const MapEntry('', ''))
          .key;
      for (final city in cities) {
        locations.add('$city, $stateAbbr');
      }
    } else if (location == 'all' || location.isEmpty) {
      // Add a few default cities
      locations.addAll([
        'Omaha, NE',
        'Lincoln, NE',
        'Des Moines, IA',
        'Kansas City, MO',
      ]);
    } else {
      // Assume it's a city - add state if not present
      if (!location.contains(',')) {
        // Try to guess the state based on common cities
        final cityState = _guessCityState(location);
        locations.add(cityState);
      } else {
        locations.add(location);
      }
    }
    
    return locations;
  }
  
  String _guessCityState(String city) {
    // Common city to state mappings
    final cityStates = {
      'omaha': 'Omaha, NE',
      'lincoln': 'Lincoln, NE',
      'des moines': 'Des Moines, IA',
      'kansas city': 'Kansas City, MO',
      'wichita': 'Wichita, KS',
      'papillion': 'Papillion, NE',
      'bellevue': 'Bellevue, NE',
    };
    
    return cityStates[city.toLowerCase()] ?? '$city, NE'; // Default to NE
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Smart Search Builder',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type searches like: "painter in Omaha" or "plumbing Nebraska"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            
            // Input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g., "painter in Omaha" or "plumbing NE"',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addSearchQuery(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addSearchQuery,
                  icon: const Icon(Icons.add_circle, color: AppTheme.primaryGold),
                  iconSize: 32,
                ),
              ],
            ),
            
            if (_searchQueries.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Search Queue:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _searchQueries.map((query) {
                  final searches = _parseSearchQuery(query);
                  return Chip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          query,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${searches.length} locations',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    deleteIconColor: Colors.white.withValues(alpha: 0.7),
                    onDeleted: () => _removeQuery(query),
                    backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                    side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Total searches to execute: ${_searchQueries.fold<int>(0, (sum, q) => sum + _parseSearchQuery(q).length)}',
                style: const TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[300], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Each search automatically expands to include suburbs using our zoom-out feature. '
                      'State searches run in major cities.',
                      style: TextStyle(
                        color: Colors.blue[200],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}