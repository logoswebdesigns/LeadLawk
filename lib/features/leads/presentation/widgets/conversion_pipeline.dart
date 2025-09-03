import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_statistics_provider.dart';
import 'pipeline_stage.dart';

class ConversionPipeline extends ConsumerWidget {
  const ConversionPipeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsAsync = ref.watch(leadStatisticsProvider);
    final stages = _getStages();
    
    return statisticsAsync.when(
      data: (statistics) {
        final maxCount = statistics.byStatus.values
            .fold(0, (a, b) => a > b ? a : b);
    
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
                Text(
                  'Pipeline',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${statistics.total} leads',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const Spacer(),
                _buildConversionRate(statistics),
              ],
            ),
          ),
          // Pipeline Visualization
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: stages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final stage = stages[index];
                final leadCount = statistics.byStatus[stage.status] ?? 0;
                return PipelineStage(
                  stage: stage,
                  leadCount: leadCount,
                  leads: [], // Empty list since we're using statistics
                  totalLeads: statistics.total,
                  maxCount: maxCount,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
      },
      loading: () => Container(
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
        child: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGold,
          ),
        ),
      ),
      error: (error, stack) => Container(
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
        child: Center(
          child: Text(
            'Failed to load statistics',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversionRate(LeadStatistics statistics) {
    final rate = statistics.conversionRate;
    
    return Row(
      children: [
        Icon(Icons.trending_up, size: 16, color: AppTheme.successGreen),
        const SizedBox(width: 4),
        Text(
          '${rate.toStringAsFixed(1)}% conversion',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.successGreen,
          ),
        ),
      ],
    );
  }

  List<StageInfo> _getStages() {
    return [
      StageInfo(LeadStatus.new_, 'New', const Color(0xFF007AFF), Icons.fiber_new),
      StageInfo(LeadStatus.viewed, 'Viewed', const Color(0xFF5856D6), Icons.visibility),
      StageInfo(LeadStatus.called, 'Called', const Color(0xFFFF9500), Icons.phone_in_talk),
      StageInfo(LeadStatus.interested, 'Interest', const Color(0xFF34C759), Icons.star),
      StageInfo(LeadStatus.callbackScheduled, 'Callback', const Color(0xFF5AC8FA), Icons.schedule),
      StageInfo(LeadStatus.converted, 'Won', const Color(0xFF30D158), Icons.check_circle),
      StageInfo(LeadStatus.didNotConvert, 'Lost', const Color(0xFFFF3B30), Icons.cancel),
      StageInfo(LeadStatus.doNotCall, 'DNC', const Color(0xFF8E8E93), Icons.block),
    ];
  }


}

class StageInfo {
  final LeadStatus status;
  final String label;
  final Color color;
  final IconData icon;

  StageInfo(this.status, this.label, this.color, this.icon);
}