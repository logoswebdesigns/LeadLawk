// Error reporting system for critical errors.
// Pattern: Error Reporting - external error tracking.
// Single Responsibility: Report critical errors to monitoring service.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_exceptions.dart';

/// Error report
class ErrorReport {
  final String id;
  final DateTime timestamp;
  final AppException exception;
  final StackTrace? stackTrace;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> appInfo;
  final String? userId;
  final String? sessionId;
  
  ErrorReport({
    required this.id,
    required this.timestamp,
    required this.exception,
    this.stackTrace,
    required this.deviceInfo,
    required this.appInfo,
    this.userId,
    this.sessionId,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'exception': {
      'type': exception.runtimeType.toString(),
      'message': exception.message,
      'code': exception.code,
      'severity': exception.severity.name,
    },
    'device_info': deviceInfo,
    'app_info': appInfo,
    'user_id': userId,
    'session_id': sessionId,
    'stack_trace': stackTrace?.toString(),
  };
}

/// Error reporter
class ErrorReporter {
  static final ErrorReporter _instance = ErrorReporter._internal();
  factory ErrorReporter() => _instance;
  ErrorReporter._internal();
  
  Map<String, dynamic> _deviceInfo = {};
  Map<String, dynamic> _appInfo = {};
  String? _userId;
  String? _sessionId;
  
  final List<ErrorReport> _pendingReports = [];
  Timer? _retryTimer;
  
  /// Initialize reporter
  Future<void> initialize({
    Map<String, dynamic>? deviceInfo,
    Map<String, dynamic>? appInfo,
    String? userId,
    String? sessionId,
  }) async {
    _deviceInfo = deviceInfo ?? await _collectDeviceInfo();
    _appInfo = appInfo ?? await _collectAppInfo();
    _userId = userId;
    _sessionId = sessionId;
  }
  
  /// Collect device information
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    // TODO: Use device_info_plus package to get real device info
    return {
      'platform': defaultTargetPlatform.name,
      'debug_mode': kDebugMode,
      'profile_mode': kProfileMode,
      'release_mode': kReleaseMode,
    };
  }
  
  /// Collect app information
  Future<Map<String, dynamic>> _collectAppInfo() async {
    // TODO: Use package_info_plus to get real app info
    return {
      'app_name': 'LeadLawk',
      'version': '1.0.0',
      'build_number': '1',
    };
  }
  
  /// Update user context
  void setUser(String? userId) {
    _userId = userId;
  }
  
  /// Update session
  void setSession(String? sessionId) {
    _sessionId = sessionId;
  }
  
  /// Report an error
  Future<void> reportError(
    AppException exception,
    StackTrace? stackTrace,
  ) async {
    final report = ErrorReport(
      id: _generateReportId(),
      timestamp: DateTime.now(),
      exception: exception,
      stackTrace: stackTrace,
      deviceInfo: _deviceInfo,
      appInfo: _appInfo,
      userId: _userId,
      sessionId: _sessionId,
    );
    
    try {
      await _sendReport(report);
    } catch (e) {
      // Queue for retry if sending fails
      _pendingReports.add(report);
      _scheduleRetry();
      
      if (kDebugMode) {
        debugPrint('Failed to send error report: $e');
      }
    }
  }
  
  /// Generate unique report ID
  String _generateReportId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}';
  }
  
  /// Send report to monitoring service
  Future<void> _sendReport(ErrorReport report) async {
    // TODO: Integrate with real error monitoring service
    // Options: Sentry, Crashlytics, Bugsnag, etc.
    
    if (kDebugMode) {
      debugPrint('📊 Error Report Generated:');
      debugPrint('  ID: ${report.id}');
      debugPrint('  Exception: ${report.exception.runtimeType}');
      debugPrint('  Message: ${report.exception.message}');
      debugPrint('  Severity: ${report.exception.severity.name}');
    }
    
    // Simulate network request
    await Future.delayed(Duration(milliseconds: 100));
    
    // In production, this would send to:
    // - Sentry.captureException(exception, stackTrace: stackTrace);
    // - FirebaseCrashlytics.instance.recordError(exception, stackTrace);
    // - Custom error monitoring endpoint
  }
  
  /// Schedule retry for pending reports
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(minutes: 1), _retryPendingReports);
  }
  
  /// Retry sending pending reports
  Future<void> _retryPendingReports() async {
    if (_pendingReports.isEmpty) return;
    
    final reports = List<ErrorReport>.from(_pendingReports);
    _pendingReports.clear();
    
    for (final report in reports) {
      try {
        await _sendReport(report);
      } catch (e) {
        _pendingReports.add(report);
      }
    }
    
    if (_pendingReports.isNotEmpty) {
      _scheduleRetry();
    }
  }
  
  /// Get pending report count
  int get pendingReportCount => _pendingReports.length;
  
  /// Force flush all pending reports
  Future<void> flush() async {
    await _retryPendingReports();
  }
  
  /// Clear all pending reports
  void clearPending() {
    _pendingReports.clear();
    _retryTimer?.cancel();
  }
  
  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
  }
}