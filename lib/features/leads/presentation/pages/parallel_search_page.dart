import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/smart_search_input.dart';
import '../providers/parallel_search_provider.dart';

class ParallelSearchPage extends ConsumerStatefulWidget {
  const ParallelSearchPage({super.key});

  @override
  ConsumerState<ParallelSearchPage> createState() => _ParallelSearchPageState();
}

class _ParallelSearchPageState extends ConsumerState<ParallelSearchPage> {
  List<Map<String, String>> generatedSearches = [];
  
  // Search parameters
  int searchLimit = 50;
  double minRating = 0.0;
  int minReviews = 0;
  bool requiresNoWebsite = true;
  int recentReviewMonths = 24;
  bool enablePagespeed = false;
  
  @override
  Widget build(BuildContext context) {
    final totalSearches = generatedSearches.length;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text(
          'Parallel Search Configuration',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.refresh),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search summary
                  _buildSummaryCard(totalSearches),
                  const SizedBox(height: 20),
                  
                  // Smart search input
                  SmartSearchInput(
                    onSearchesGenerated: (searches) {
                      setState(() {
                        generatedSearches = searches;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Search parameters
                  _buildSearchParameters(),
                ],
              ),
            ),
          ),
          
          // Bottom action bar
          _buildActionBar(totalSearches),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard(int totalSearches) {
    final estimatedTime = totalSearches * 2; // Estimate 2 minutes per search
    
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.rocket_launch,
                  color: totalSearches > 0 ? Colors.amber : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalSearches > 0
                            ? '$totalSearches Parallel Searches'
                            : 'Configure Your Search',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (totalSearches > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Estimated time: ${estimatedTime ~/ 60}h ${estimatedTime % 60}m with parallel execution',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (totalSearches > 10) ...[
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Large search: Will use up to ${totalSearches > 10 ? 10 : totalSearches} parallel browser instances',
                        style: TextStyle(
                          color: Colors.orange[200],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
Widget _buildSearchParameters() {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Parameters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Results per search
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Results per search',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: searchLimit > 10
                          ? () => setState(() => searchLimit -= 10)
                          : null,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$searchLimit',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: searchLimit < 100
                          ? () => setState(() => searchLimit += 10)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            
            // Website filter
            SwitchListTile(
              title: Text(
                'Find businesses WITHOUT websites',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              subtitle: Text(
                'Ideal for finding prospects',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              value: requiresNoWebsite,
              onChanged: (value) => setState(() => requiresNoWebsite = value),
              activeColor: AppTheme.primaryGold,
            ),
            
            // Recent reviews filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent reviews (months)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: recentReviewMonths > 6
                          ? () => setState(() => recentReviewMonths -= 6)
                          : null,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$recentReviewMonths',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: recentReviewMonths < 48
                          ? () => setState(() => recentReviewMonths += 6)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionBar(int totalSearches) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: totalSearches > 0 ? _startParallelSearch : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGold,
            disabledBackgroundColor: Colors.grey,
            minimumSize: Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rocket_launch,
                color: totalSearches > 0 ? AppTheme.backgroundDark : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                totalSearches > 0
                    ? 'Launch $totalSearches Parallel Searches'
                    : 'Select Industries and Locations',
                style: TextStyle(
                  color: totalSearches > 0 ? AppTheme.backgroundDark : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _startParallelSearch() async {
    final parallelSearch = ref.read(parallelSearchProvider.notifier);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text(
          'Start Parallel Search',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will launch ${generatedSearches.length} searches in parallel.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Text(
              'Searches to execute:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...generatedSearches.take(5).map((search) => Padding(padding: EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${search['industry']} in ${search['location']}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            )),
            if (generatedSearches.length > 5)
              Text(
                '... and ${generatedSearches.length - 5} more',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Start the parallel search
              await parallelSearch.startParallelSearch(
                searches: generatedSearches,
                limit: searchLimit,
                requiresNoWebsite: requiresNoWebsite,
                recentReviewMonths: recentReviewMonths,
                enablePagespeed: enablePagespeed,
              );
              
              // Check for errors
              final state = ref.read(parallelSearchProvider);
              if (state.error != null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.error!),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (state.parentJobId != null) {
                if (!context.mounted) return;
                // Navigate back to the leads list page
                context.go('/leads');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
            ),
            child: const Text(
              'Start',
              style: TextStyle(color: AppTheme.backgroundDark),
            ),
          ),
        ],
      ),
    );
  }
}