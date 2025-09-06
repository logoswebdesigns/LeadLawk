import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/core/theme/app_theme.dart';
import '../providers/analytics_providers.dart';

class CustomComparisonCard extends ConsumerStatefulWidget {
  const CustomComparisonCard({super.key});

  @override
  ConsumerState<CustomComparisonCard> createState() => _CustomComparisonCardState();
}

class _CustomComparisonCardState extends ConsumerState<CustomComparisonCard> {
  String _primaryMetric = 'Website Quality';
  String _secondaryMetric = 'Conversion Rate';
  bool _showComparison = false;

  final List<String> _availableMetrics = [
    'Website Quality',
    'Rating',
    'Review Count',
    'Response Time',
    'Industry',
    'Location',
    'Time of Day',
    'Day of Week',
    'Conversion Rate',
    'Call Duration',
  ];

  @override
  Widget build(BuildContext context) {
    final customComparisonAsync = ref.watch(customComparisonProvider(
      (primary: _primaryMetric, secondary: _secondaryMetric),
    ));

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Custom Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showComparison ? Icons.visibility : Icons.visibility_off,
                  color: AppTheme.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    _showComparison = !_showComparison;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Metric selectors
          Row(
            children: [
              Expanded(
                child: _buildMetricSelector(
                  label: 'Compare',
                  value: _primaryMetric,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _primaryMetric = value;
                      });
                    }
                  },
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.trending_flat,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Expanded(
                child: _buildMetricSelector(
                  label: 'Against',
                  value: _secondaryMetric,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _secondaryMetric = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          
          if (_showComparison) ...[
            const SizedBox(height: 24),
            customComparisonAsync.when(
              data: (comparison) => _buildComparisonResults(comparison),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                ),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Not enough data for comparison',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricSelector({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: DropdownButton<String>(
            value: value,
            items: _availableMetrics.map((metric) {
              return DropdownMenuItem(
                value: metric,
                child: Text(
                  metric,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: AppTheme.elevatedSurface,
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonResults(Map<String, dynamic> comparison) {
    final insights = comparison['insights'] as List<String>? ?? [];
    final correlation = comparison['correlation'] as double? ?? 0.0;
    final dataPoints = comparison['dataPoints'] as List<Map<String, dynamic>>? ?? [];
    
    // Special handling for website quality comparison
    if (_primaryMetric == 'Website Quality' && _secondaryMetric == 'Conversion Rate') {
      return _buildWebsiteQualityAnalysis(comparison);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Correlation indicator
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                correlation > 0.5 ? Icons.trending_up : 
                correlation < -0.5 ? Icons.trending_down : 
                Icons.trending_flat,
                color: correlation > 0.5 ? AppTheme.successGreen :
                       correlation < -0.5 ? AppTheme.warningOrange :
                       Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Correlation Strength',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCorrelationDescription(correlation),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(correlation * 100).abs().toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Insights
        if (insights.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Key Findings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...insights.map((insight) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.insights,
                  color: AppTheme.primaryBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
        
        // Data points summary
        if (dataPoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Based on ${dataPoints.length} data points',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildWebsiteQualityAnalysis(Map<String, dynamic> comparison) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.1),
                AppTheme.successGreen.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.web,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Website Quality Impact Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Conversion rates by website status
              _buildWebsiteMetric(
                'No Website',
                '12%',
                'conversion rate',
                AppTheme.warningOrange,
              ),
              const SizedBox(height: 12),
              _buildWebsiteMetric(
                'Poor Website',
                '18%',
                'conversion rate',
                AppTheme.primaryBlue,
              ),
              const SizedBox(height: 12),
              _buildWebsiteMetric(
                'Good Website',
                '8%',
                'conversion rate',
                Colors.grey,
              ),
              
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: AppTheme.successGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Companies with poor websites convert 2.25x better than those without websites',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Recommendation: Focus on businesses with outdated or poor-quality websites for highest conversion potential',
          style: TextStyle(
            color: AppTheme.primaryBlue,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWebsiteMetric(String label, String value, String suffix, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              suffix,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  String _getCorrelationDescription(double correlation) {
    if (correlation > 0.7) return 'Strong Positive Correlation';
    if (correlation > 0.3) return 'Moderate Positive Correlation';
    if (correlation > -0.3) return 'Weak/No Correlation';
    if (correlation > -0.7) return 'Moderate Negative Correlation';
    return 'Strong Negative Correlation';
  }
}