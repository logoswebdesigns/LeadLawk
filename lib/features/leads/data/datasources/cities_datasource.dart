import 'package:dio/dio.dart';

abstract class CitiesDataSource {
  Future<List<String>> getCitiesForState(String state);
}

class CitiesDataSourceImpl implements CitiesDataSource {
  final Dio dio;
  final String censusApiKey = '45734c6f0205ee86872a05d2c8951f1a0eee5ca2';

  CitiesDataSourceImpl({required this.dio});

  @override
  Future<List<String>> getCitiesForState(String state) async {
    final cities = <String>{};
    final stateAbbr = _getStateAbbreviation(state);
    final stateFips = _getStateFipsCode(state);
    
    print('🔍 Loading cities for state: $state ($stateAbbr, FIPS: $stateFips)');
    
    // Try Census.gov API first (most comprehensive)
    try {
      cities.addAll(await _fetchFromCensusAPI(state, stateAbbr, stateFips));
    } catch (e) {
      print('⚠️ Census API failed: $e, trying fallback');
      
      // Fallback to OpenDataSoft if Census fails
      try {
        cities.addAll(await _fetchFromOpenDataSoft(state, stateAbbr));
      } catch (e2) {
        print('⚠️ OpenDataSoft API also failed: $e2');
      }
    }
    
    print('📊 Total unique cities found: ${cities.length}');
    return cities.toList()..sort();
  }
  
  Future<Set<String>> _fetchFromCensusAPI(String state, String stateAbbr, String stateFips) async {
    final cities = <String>{};
    
    try {
      // Census API endpoint for all places (cities, towns, etc.) in a state
      // Using the 2020 ACS 5-year estimates
      final url = 'https://api.census.gov/data/2020/acs/acs5';
      
      final response = await dio.get(
        url,
        queryParameters: {
          'get': 'NAME',  // Get place names
          'for': 'place:*',  // All places (cities, towns, CDPs)
          'in': 'state:$stateFips',  // In the specified state
          'key': censusApiKey,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>;
        
        // Skip header row if present
        final startIndex = data[0][0] == 'NAME' ? 1 : 0;
        
        for (int i = startIndex; i < data.length; i++) {
          final placeName = data[i][0] as String?;
          if (placeName != null && placeName.isNotEmpty) {
            // Census returns names like "Austin city, Texas"
            // Clean it up to just "Austin, TX"
            final cleanName = placeName
                .replaceAll(' city', '')
                .replaceAll(' town', '')
                .replaceAll(' village', '')
                .replaceAll(' CDP', '')
                .replaceAll(' borough', '')
                .replaceAll(' municipality', '')
                .replaceAll(', $state', '');
            
            if (cleanName.isNotEmpty && !cleanName.contains('County')) {
              cities.add('$cleanName, $stateAbbr');
            }
          }
        }
        
        print('✅ Census API returned ${cities.length} cities');
      }
    } catch (e) {
      print('Error fetching from Census API: $e');
      throw e;
    }
    
    return cities;
  }
  
  Future<Set<String>> _fetchFromOpenDataSoft(String state, String stateAbbr) async {
    final cities = <String>{};
    int offset = 0;
    const int limit = 100;
    bool hasMore = true;
    
    while (hasMore) {
      try {
        final response = await dio.get(
          'https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/us-cities-demographics/records',
          queryParameters: {
            'where': 'state = "$state"',
            'limit': limit,
            'offset': offset,
            'select': 'city,state',
          },
        );
        
        if (response.statusCode == 200) {
          final data = response.data;
          final results = data['results'] as List<dynamic>?;
          
          if (results != null && results.isNotEmpty) {
            for (final result in results) {
              final city = result['city'] as String?;
              if (city != null && !cities.contains('$city, $stateAbbr')) {
                cities.add('$city, $stateAbbr');
              }
            }
            
            final totalCount = data['total_count'] as int?;
            offset += limit;
            hasMore = totalCount != null && offset < totalCount;
          } else {
            hasMore = false;
          }
        } else {
          hasMore = false;
        }
      } catch (e) {
        print('Error in OpenDataSoft batch at offset $offset: $e');
        hasMore = false;
      }
    }
    
    return cities;
  }
  
  String _getStateAbbreviation(String stateName) {
    final stateAbbreviations = {
      'Alabama': 'AL', 'Alaska': 'AK', 'Arizona': 'AZ', 'Arkansas': 'AR',
      'California': 'CA', 'Colorado': 'CO', 'Connecticut': 'CT', 'Delaware': 'DE',
      'Florida': 'FL', 'Georgia': 'GA', 'Hawaii': 'HI', 'Idaho': 'ID',
      'Illinois': 'IL', 'Indiana': 'IN', 'Iowa': 'IA', 'Kansas': 'KS',
      'Kentucky': 'KY', 'Louisiana': 'LA', 'Maine': 'ME', 'Maryland': 'MD',
      'Massachusetts': 'MA', 'Michigan': 'MI', 'Minnesota': 'MN', 'Mississippi': 'MS',
      'Missouri': 'MO', 'Montana': 'MT', 'Nebraska': 'NE', 'Nevada': 'NV',
      'New Hampshire': 'NH', 'New Jersey': 'NJ', 'New Mexico': 'NM', 'New York': 'NY',
      'North Carolina': 'NC', 'North Dakota': 'ND', 'Ohio': 'OH', 'Oklahoma': 'OK',
      'Oregon': 'OR', 'Pennsylvania': 'PA', 'Rhode Island': 'RI', 'South Carolina': 'SC',
      'South Dakota': 'SD', 'Tennessee': 'TN', 'Texas': 'TX', 'Utah': 'UT',
      'Vermont': 'VT', 'Virginia': 'VA', 'Washington': 'WA', 'West Virginia': 'WV',
      'Wisconsin': 'WI', 'Wyoming': 'WY'
    };
    return stateAbbreviations[stateName] ?? stateName;
  }
  
  String _getStateFipsCode(String stateName) {
    // FIPS codes required for Census API
    final stateFipsCodes = {
      'Alabama': '01', 'Alaska': '02', 'Arizona': '04', 'Arkansas': '05',
      'California': '06', 'Colorado': '08', 'Connecticut': '09', 'Delaware': '10',
      'Florida': '12', 'Georgia': '13', 'Hawaii': '15', 'Idaho': '16',
      'Illinois': '17', 'Indiana': '18', 'Iowa': '19', 'Kansas': '20',
      'Kentucky': '21', 'Louisiana': '22', 'Maine': '23', 'Maryland': '24',
      'Massachusetts': '25', 'Michigan': '26', 'Minnesota': '27', 'Mississippi': '28',
      'Missouri': '29', 'Montana': '30', 'Nebraska': '31', 'Nevada': '32',
      'New Hampshire': '33', 'New Jersey': '34', 'New Mexico': '35', 'New York': '36',
      'North Carolina': '37', 'North Dakota': '38', 'Ohio': '39', 'Oklahoma': '40',
      'Oregon': '41', 'Pennsylvania': '42', 'Rhode Island': '44', 'South Carolina': '45',
      'South Dakota': '46', 'Tennessee': '47', 'Texas': '48', 'Utah': '49',
      'Vermont': '50', 'Virginia': '51', 'Washington': '53', 'West Virginia': '54',
      'Wisconsin': '55', 'Wyoming': '56'
    };
    return stateFipsCodes[stateName] ?? '00';
  }
}