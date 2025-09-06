import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/goals_provider.dart';
import 'goals_setting_dialog.dart';

class GoalsTrackingCard extends ConsumerWidget {
  const GoalsTrackingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(goalsProvider);
    
    final dailyProgress = goalsState.dailyCallGoal > 0 
      ? (goalsState.todaysCalls / goalsState.dailyCallGoal).clamp(0.0, 1.0)
      : 0.0;
    
    final monthlyProgress = goalsState.monthlyConversionGoal > 0
      ? (goalsState.thisMonthsConversions / goalsState.monthlyConversionGoal).clamp(0.0, 1.0)
      : 0.0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactGoalItem(
              'Calls Today',
              goalsState.todaysCalls,
              goalsState.dailyCallGoal,
              dailyProgress,
              Icons.phone,
              AppTheme.primaryGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactGoalItem(
              'Month Conversions',
              goalsState.thisMonthsConversions,
              goalsState.monthlyConversionGoal,
              monthlyProgress,
              Icons.trending_up,
              AppTheme.successGreen,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: AppTheme.primaryGold,
              size: 18,
            ),
            onPressed: () {
              GoalsSettingDialog.show(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactGoalItem(
    String label,
    int current,
    int goal,
    double progress,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppTheme.successGreen : color,
                  ),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$current/$goal',
              style: TextStyle(
                color: progress >= 1.0 ? AppTheme.successGreen : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}