import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/call_statistics_provider.dart';

class CallCalendarDrawer extends ConsumerStatefulWidget {
  const CallCalendarDrawer({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CallCalendarDrawer(),
    );
  }

  @override
  ConsumerState<CallCalendarDrawer> createState() => _CallCalendarDrawerState();
}

class _CallCalendarDrawerState extends ConsumerState<CallCalendarDrawer> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final callStatsAsync = ref.watch(callStatisticsProvider);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: callStatsAsync.when(
              data: (callStats) => _buildCalendarContent(callStats),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGold,
                ),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading call statistics',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.calendar,
            color: AppTheme.primaryGold,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Call History Calendar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              CupertinoIcons.xmark_circle_fill,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarContent(Map<DateTime, int> callStats) {
    return Column(
      children: [
        TableCalendar<int>(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            final calls = callStats[key] ?? 0;
            return calls > 0 ? [calls] : [];
          },
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            defaultTextStyle: TextStyle(color: Colors.white),
            weekendTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            selectedDecoration: BoxDecoration(
              color: AppTheme.primaryGold,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppTheme.primaryGold.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: AppTheme.successGreen,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 1,
            markersAlignment: Alignment.bottomCenter,
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonShowsNext: false,
            formatButtonDecoration: BoxDecoration(
              color: AppTheme.primaryGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            formatButtonTextStyle: TextStyle(
              color: AppTheme.primaryGold,
              fontSize: 14,
            ),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: AppTheme.primaryGold,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: AppTheme.primaryGold,
            ),
          ),
          calendarBuilders: CalendarBuilders<int>(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;
              
              final callCount = events.first;
              return Container(
                margin: const EdgeInsets.only(top: 30),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _getColorForCallCount(callCount),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      callCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
        const SizedBox(height: 16),
        _buildSelectedDayStats(callStats),
      ],
    );
  }

  Widget _buildSelectedDayStats(Map<DateTime, int> callStats) {
    final key = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final calls = callStats[key] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.phone_fill,
                color: AppTheme.primaryGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(_selectedDay),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Calls',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              Text(
                calls.toString(),
                style: TextStyle(
                  color: calls > 0 ? AppTheme.successGreen : Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (calls > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (calls / 50).clamp(0.0, 1.0), // Assuming 50 calls is excellent
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getColorForCallCount(calls),
              ),
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            Text(
              _getPerformanceText(calls),
              style: TextStyle(
                color: _getColorForCallCount(calls),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getColorForCallCount(int count) {
    if (count >= 40) return AppTheme.successGreen;
    if (count >= 25) return AppTheme.primaryGold;
    if (count >= 10) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceText(int count) {
    if (count >= 40) return 'Excellent Performance! 🎉';
    if (count >= 25) return 'Great Job! 👍';
    if (count >= 10) return 'Good Progress';
    return 'Keep Going!';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) {
      return 'Today';
    }
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    if (isSameDay(date, now.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}