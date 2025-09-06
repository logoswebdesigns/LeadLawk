// Global error handler for the application.
// Pattern: Exception Shielding Pattern - centralized error handling.
// Single Responsibility: Handle and transform all errors.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'app_exceptions.dart';
import 'app_exceptions.dart' as lib;
import 'error_logger.dart';
import 'error_reporter.dart';

/// Global error handler
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();
  
  final ErrorLogger _logger = ErrorLogger();
  final ErrorReporter _reporter = ErrorReporter();
  
  /// Initialize error handling
  void initialize() {
    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      handleFlutterError(details);
    };
    
    // Set up async error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      handleError(error, stack);
      return true;
    };
  }
  
  /// Handle Flutter framework errors
  void handleFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
    
    final exception = _transformError(details.exception);
    _logger.logError(exception, details.stack);
    
    if (exception.severity == ErrorSeverity.critical) {
      _reporter.reportError(exception, details.stack);
    }
  }
  
  /// Handle general errors
  Future<void> handleError(
    dynamic error,
    StackTrace? stackTrace, {
    BuildContext? context,
    bool silent = false,
  }) async {
    final exception = _transformError(error, stackTrace: stackTrace);
    
    // Log error
    await _logger.logError(exception, stackTrace);
    
    // Report critical errors
    if (exception.severity == ErrorSeverity.critical) {
      await _reporter.reportError(exception, stackTrace);
    }
    
    // Show user feedback if context available
    if (context != null && context.mounted && !silent) {
      _showErrorToUser(context, exception);
    }
  }
  
  /// Transform any error into AppException
  AppException _transformError(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    if (error is AppException) {
      return error;
    }
    
    if (error is DioException) {
      return _transformDioError(error);
    }
    
    if (error is TimeoutException) {
      return lib.TimeoutException(
        message: 'Operation timed out',
        timeout: Duration.zero,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    if (error is FormatException) {
      return DataException(
        message: 'Invalid data format: ${error.message}',
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    if (error is TypeError) {
      return DataException(
        message: 'Type error: ${error.toString()}',
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    return UnknownException(
      message: error?.toString() ?? 'Unknown error',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Transform Dio errors
  ApiException _transformDioError(DioException error) {
    String message = error.message ?? 'Network request failed';
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Request timed out',
          statusCode: null,
          code: 'TIMEOUT',
          originalError: error,
          stackTrace: error.stackTrace,
        );
        
      case DioExceptionType.badResponse:
        return ApiException(
          message: error.response?.data?['message'] ?? message,
          statusCode: error.response?.statusCode,
          response: error.response?.data,
          originalError: error,
          stackTrace: error.stackTrace,
        );
        
      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request cancelled',
          code: 'CANCELLED',
          originalError: error,
          stackTrace: error.stackTrace,
        );
        
      default:
        return ApiException(
          message: message,
          code: 'NETWORK_ERROR',
          originalError: error,
          stackTrace: error.stackTrace,
        );
    }
  }
  
  /// Show error to user
  void _showErrorToUser(BuildContext context, AppException exception) {
    final theme = Theme.of(context);
    final severity = exception.severity;
    
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    switch (severity) {
      case ErrorSeverity.low:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.info_outline;
        break;
      case ErrorSeverity.medium:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = Icons.warning_amber_outlined;
        break;
      case ErrorSeverity.high:
        backgroundColor = theme.colorScheme.errorContainer;
        textColor = theme.colorScheme.onErrorContainer;
        icon = Icons.error_outline;
        break;
      case ErrorSeverity.critical:
        backgroundColor = theme.colorScheme.error;
        textColor = theme.colorScheme.onError;
        icon = Icons.dangerous_outlined;
        break;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exception.userMessage,
                style: TextStyle(color: textColor),
              ),
            ),
            if (exception.isRetryable)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  // Trigger retry logic
                },
                child: Text(
                  'RETRY',
                  style: TextStyle(color: textColor),
                ),
              ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(
          seconds: severity == ErrorSeverity.critical ? 10 : 5,
        ),
      ),
    );
  }
  
  /// Create error widget for builders
  Widget buildErrorWidget(
    AppException exception, {
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(exception.severity),
              size: 64,
              color: _getErrorColor(exception.severity),
            ),
            const SizedBox(height: 16),
            Text(
              exception.userMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (exception.isRetryable && onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  IconData _getErrorIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }
  
  Color _getErrorColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Colors.blue;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return Colors.red;
      case ErrorSeverity.critical:
        return Colors.red.shade900;
    }
  }
}