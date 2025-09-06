import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/pagespeed_notification_service.dart';
import '../../../../core/utils/debug_logger.dart';

enum PageSpeedTestStatus {
  idle,
  queued,
  testingMobile,
  testingDesktop,
  processing,
  completed,
  error
}

class PageSpeedTestState {
  final String leadId;
  final PageSpeedTestStatus status;
  final String? currentStep;
  final String? errorMessage;
  final int progress; // 0-100
  final DateTime? startTime;
  final DateTime? endTime;

  PageSpeedTestState({
    required this.leadId,
    this.status = PageSpeedTestStatus.idle,
    this.currentStep,
    this.errorMessage,
    this.progress = 0,
    this.startTime,
    this.endTime,
  });

  PageSpeedTestState copyWith({
    PageSpeedTestStatus? status,
    String? currentStep,
    String? errorMessage,
    int? progress,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return PageSpeedTestState(
      leadId: leadId,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get statusText {
    switch (status) {
      case PageSpeedTestStatus.idle:
        return 'Ready to test';
      case PageSpeedTestStatus.queued:
        return 'Test queued...';
      case PageSpeedTestStatus.testingMobile:
        return 'Testing mobile performance...';
      case PageSpeedTestStatus.testingDesktop:
        return 'Testing desktop performance...';
      case PageSpeedTestStatus.processing:
        return 'Processing results...';
      case PageSpeedTestStatus.completed:
        return 'Test completed';
      case PageSpeedTestStatus.error:
        return 'Test failed';
    }
  }

  Duration? get elapsedTime {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }
}

class PageSpeedStatusNotifier extends StateNotifier<Map<String, PageSpeedTestState>> {
  final Dio dio;
  final PageSpeedNotificationService notificationService;
  final Map<String, Timer> _pollers = {};

  PageSpeedStatusNotifier(this.dio, this.notificationService) : super({});

  void startTest(String leadId) {
    state = {
      ...state,
      leadId: PageSpeedTestState(
        leadId: leadId,
        status: PageSpeedTestStatus.queued,
        startTime: DateTime.now(),
        progress: 0,
      ),
    };

    // Start polling for status
    _startPolling(leadId);
  }

  void _startPolling(String leadId) {
    _pollers[leadId]?.cancel();
    
    int pollCount = 0;
    _pollers[leadId] = Timer.periodic(const Duration(seconds: 2), (timer) async {
      pollCount++;
      
      // Simulate progress based on time
      final currentState = state[leadId];
      if (currentState == null) {
        timer.cancel();
        return;
      }

      // Update progress and status based on elapsed time
      final elapsed = currentState.elapsedTime?.inSeconds ?? 0;
      
      if (elapsed < 5) {
        _updateState(leadId, 
          status: PageSpeedTestStatus.queued,
          progress: 10,
          currentStep: 'Initializing PageSpeed test...'
        );
      } else if (elapsed < 15) {
        _updateState(leadId,
          status: PageSpeedTestStatus.testingMobile,
          progress: 30 + (elapsed - 5) * 3,
          currentStep: 'Analyzing mobile performance metrics...'
        );
      } else if (elapsed < 25) {
        _updateState(leadId,
          status: PageSpeedTestStatus.testingDesktop,
          progress: 60 + (elapsed - 15) * 2,
          currentStep: 'Analyzing desktop performance metrics...'
        );
      } else if (elapsed < 30) {
        _updateState(leadId,
          status: PageSpeedTestStatus.processing,
          progress: 80 + (elapsed - 25) * 4,
          currentStep: 'Calculating Core Web Vitals...'
        );
      } else {
        // Check if results are ready
        try {
          final response = await dio.get('/leads/$leadId');
          final lead = response.data;
          
          if (lead['pagespeed_mobile_score'] != null || 
              lead['pagespeed_desktop_score'] != null ||
              lead['pagespeed_test_error'] != null) {
            // Test completed
            DebugLogger.log('🎯 PageSpeed test completed for $leadId - Mobile: ${lead['pagespeed_mobile_score']}, Desktop: ${lead['pagespeed_desktop_score']}');
            
            // Show notification
            notificationService.showPageSpeedComplete(
              leadId: leadId,
              businessName: lead['business_name'] ?? 'Unknown',
              mobileScore: lead['pagespeed_mobile_score'],
              desktopScore: lead['pagespeed_desktop_score'],
              hasError: lead['pagespeed_test_error'] != null,
            );
            
            _updateState(leadId,
              status: lead['pagespeed_test_error'] != null 
                ? PageSpeedTestStatus.error 
                : PageSpeedTestStatus.completed,
              progress: 100,
              currentStep: lead['pagespeed_test_error'] ?? 
                'Test completed - Mobile: ${lead['pagespeed_mobile_score']}, Desktop: ${lead['pagespeed_desktop_score']}',
              errorMessage: lead['pagespeed_test_error'],
              endTime: DateTime.now(),
            );
            timer.cancel();
            _pollers.remove(leadId);
            
            DebugLogger.log('📊 PageSpeed test completed for lead $leadId');
            
            // Clear state after a longer delay to allow UI to see the completion
            Future.delayed(const Duration(seconds: 15), () {
              if (state.containsKey(leadId)) {
                DebugLogger.log('🧹 Clearing PageSpeed status for $leadId');
                state = Map.from(state)..remove(leadId);
              }
            });
          }
        } catch (e) {
          DebugLogger.error('⚠️ Error polling PageSpeed status for $leadId: $e');
          // Continue polling
        }
      }

      // Timeout after 2 minutes
      if (pollCount > 60) {
        _updateState(leadId,
          status: PageSpeedTestStatus.error,
          progress: 100,
          errorMessage: 'Test timeout - took too long to complete',
          endTime: DateTime.now(),
        );
        timer.cancel();
        _pollers.remove(leadId);
      }
    });
  }

  void _updateState(String leadId, {
    PageSpeedTestStatus? status,
    String? currentStep,
    String? errorMessage,
    int? progress,
    DateTime? endTime,
  }) {
    final current = state[leadId];
    if (current != null) {
      state = {
        ...state,
        leadId: current.copyWith(
          status: status,
          currentStep: currentStep,
          errorMessage: errorMessage,
          progress: progress,
          endTime: endTime,
        ),
      };
    }
  }

  void cancelTest(String leadId) {
    _pollers[leadId]?.cancel();
    _pollers.remove(leadId);
    state = Map.from(state)..remove(leadId);
  }

  @override
  void dispose() {
    for (final timer in _pollers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

final pageSpeedStatusProvider = StateNotifierProvider<PageSpeedStatusNotifier, Map<String, PageSpeedTestState>>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  
  final notificationService = ref.watch(pageSpeedNotificationServiceProvider);
  
  return PageSpeedStatusNotifier(dio, notificationService);
});