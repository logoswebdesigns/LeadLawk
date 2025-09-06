import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/lead.dart';
import 'lead_statistics_provider.dart';
import '../../../../core/utils/debug_logger.dart';

class GoalsState {
  final int dailyCallGoal;
  final int monthlyConversionGoal;
  final int todaysCalls;
  final int thisMonthsConversions;
  final DateTime lastResetDate;

  GoalsState({
    required this.dailyCallGoal,
    required this.monthlyConversionGoal,
    required this.todaysCalls,
    required this.thisMonthsConversions,
    required this.lastResetDate,
  });

  GoalsState copyWith({
    int? dailyCallGoal,
    int? monthlyConversionGoal,
    int? todaysCalls,
    int? thisMonthsConversions,
    DateTime? lastResetDate,
  }) {
    return GoalsState(
      dailyCallGoal: dailyCallGoal ?? this.dailyCallGoal,
      monthlyConversionGoal: monthlyConversionGoal ?? this.monthlyConversionGoal,
      todaysCalls: todaysCalls ?? this.todaysCalls,
      thisMonthsConversions: thisMonthsConversions ?? this.thisMonthsConversions,
      lastResetDate: lastResetDate ?? this.lastResetDate,
    );
  }
}

final goalsProvider = StateNotifierProvider<GoalsNotifier, GoalsState>((ref) {
  return GoalsNotifier(ref);
});

class GoalsNotifier extends StateNotifier<GoalsState> {
  static const String _dailyGoalKey = 'daily_call_goal';
  static const String _monthlyGoalKey = 'monthly_conversion_goal';
  final Ref ref;

  GoalsNotifier(this.ref) : super(GoalsState(
    dailyCallGoal: 20,
    monthlyConversionGoal: 5,
    todaysCalls: 0,
    thisMonthsConversions: 0,
    lastResetDate: DateTime.now(),
  )) {
    _loadGoals();
    // Defer metrics loading to avoid blocking initial render
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadTodayMetrics();
      }
    });
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final dailyGoal = prefs.getInt(_dailyGoalKey) ?? 20;
    final monthlyGoal = prefs.getInt(_monthlyGoalKey) ?? 5;
    
    state = state.copyWith(
      dailyCallGoal: dailyGoal,
      monthlyConversionGoal: monthlyGoal,
    );
  }

  Future<void> setDailyCallGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyGoalKey, goal);
    state = state.copyWith(dailyCallGoal: goal);
  }

  Future<void> setMonthlyConversionGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_monthlyGoalKey, goal);
    state = state.copyWith(monthlyConversionGoal: goal);
  }

  Future<void> _loadTodayMetrics() async {
    try {
      final dio = Dio();
      String baseUrl;
      try {
        baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      } catch (_) {
        baseUrl = 'http://localhost:8000';
      }
      
      // Fetch today's statistics from the new endpoint
      final response = await dio.get('$baseUrl/leads/statistics/today');
      
      if (response.data != null) {
        final todaysCalls = response.data['calls_today'] ?? 0;
        final conversionsToday = response.data['conversions_today'] ?? 0;
        
        DebugLogger.log('📊 Goals: Today\'s calls: $todaysCalls');
        DebugLogger.log('📊 Goals: Today\'s conversions: $conversionsToday');
        
        // Also get month's conversions from general statistics
        final statisticsAsync = ref.read(leadStatisticsProvider);
        statisticsAsync.whenData((statistics) {
          final monthConversions = statistics.byStatus[LeadStatus.converted] ?? 0;
          
          state = state.copyWith(
            todaysCalls: todaysCalls,
            thisMonthsConversions: monthConversions,
          );
        });
      }
    } catch (e) {
      DebugLogger.error('📊 Goals: Error fetching today\'s metrics: $e');
      // Fall back to general statistics if today endpoint fails
      _fallbackToGeneralStatistics();
    }
  }
  
  void _fallbackToGeneralStatistics() {
    try {
      final statisticsAsync = ref.read(leadStatisticsProvider);
      statisticsAsync.whenData((statistics) {
        // This is the old behavior as a fallback
        final calledCount = statistics.byStatus[LeadStatus.called] ?? 0;
        final interestedCount = statistics.byStatus[LeadStatus.interested] ?? 0;
        final convertedCount = statistics.byStatus[LeadStatus.converted] ?? 0;
        final todaysCalls = calledCount + interestedCount + convertedCount;
        final monthConversions = convertedCount;
        
        state = state.copyWith(
          todaysCalls: todaysCalls,
          thisMonthsConversions: monthConversions,
        );
      });
    } catch (e) {
      DebugLogger.error('📊 Goals: Error reading statistics: $e');
    }
  }

  void refreshMetrics() {
    // Don't block - just trigger an async update
    Future.microtask(() => _loadTodayMetrics());
  }
}