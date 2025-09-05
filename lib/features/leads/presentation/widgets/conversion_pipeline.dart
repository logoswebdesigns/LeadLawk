import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_statistics_provider.dart';

class ConversionPipeline extends ConsumerWidget {
  const ConversionPipeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsAsync = ref.watch(leadStatisticsProvider);
    final stages = _getStages();
    
    // Always show the pipeline structure immediately
    // Don't block on loading - show empty/placeholder data
    final statistics = statisticsAsync.valueOrNull;
    final isLoading = statisticsAsync.isLoading && statistics == null;
    
    final maxCount = statistics?.byStatus.values
        .fold(0, (a, b) => a > b ? a : b) ?? 1;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.backgroundDark,
            AppTheme.backgroundDark.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Pipeline',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statistics?.total.toString() ?? (isLoading ? '...' : '0'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
                const Spacer(),
                if (statistics != null) 
                  _buildConversionRate(statistics)
                else if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryGold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Pipeline Stages
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (int i = 0; i < stages.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < stages.length - 1 ? 8 : 0,
                        ),
                        child: _buildPipelineStage(
                          stage: stages[i],
                          count: statistics?.byStatus[stages[i].status] ?? 0,
                          maxCount: maxCount,
                          isFirst: i == 0,
                          isLast: i == stages.length - 1,
                          isLoading: isLoading,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPipelineStage({
    required StageData stage,
    required int count,
    required int maxCount,
    required bool isFirst,
    required bool isLast,
    required bool isLoading,
  }) {
    final heightFraction = maxCount > 0 ? count / maxCount : 0.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: stage.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isLoading && count == 0 ? '...' : count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: stage.color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Bar
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  heightFactor: heightFraction,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          stage.color.withValues(alpha: 0.8),
                          stage.color.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Label
        Text(
          stage.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildConversionRate(LeadStatistics statistics) {
    final rate = statistics.conversionRate;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: rate > 0 
                ? AppTheme.successGreen.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: rate > 0 
                  ? AppTheme.successGreen.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rate > 0 ? Icons.trending_up : Icons.trending_flat,
                color: rate > 0 
                    ? AppTheme.successGreen 
                    : Colors.white.withValues(alpha: 0.5),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: rate > 0 
                      ? AppTheme.successGreen 
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<StageData> _getStages() {
    return [
      StageData(
        label: 'New',
        status: LeadStatus.new_,
        color: const Color(0xFF007AFF),
        icon: Icons.fiber_new,
      ),
      StageData(
        label: 'Viewed',
        status: LeadStatus.viewed,
        color: const Color(0xFF5856D6),
        icon: Icons.visibility,
      ),
      StageData(
        label: 'Contacted',
        status: LeadStatus.called,
        color: const Color(0xFFFF9500),
        icon: Icons.phone_in_talk,
      ),
      StageData(
        label: 'Interested',
        status: LeadStatus.interested,
        color: const Color(0xFF34C759),
        icon: Icons.thumb_up,
      ),
      StageData(
        label: 'Converted',
        status: LeadStatus.converted,
        color: const Color(0xFF30D158),
        icon: Icons.check_circle,
      ),
    ];
  }
}

class StageData {
  final String label;
  final LeadStatus status;
  final Color color;
  final IconData icon;

  const StageData({
    required this.label,
    required this.status,
    required this.color,
    required this.icon,
  });
}