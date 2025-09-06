// Custom exception hierarchy for the application.
// Pattern: Exception Hierarchy - structured error handling.
// Single Responsibility: Define all application exceptions.

import 'package:flutter/foundation.dart';

/// Base exception class for all app exceptions
@immutable
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  
  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });
  
  @override
  String toString() => '$runtimeType: $message ${code != null ? '(Code: $code)' : ''}';
  
  /// Get user-friendly error message
  String get userMessage => message;
  
  /// Check if error is retryable
  bool get isRetryable => false;
  
  /// Get error severity
  ErrorSeverity get severity => ErrorSeverity.medium;
}

/// Error severity levels
enum ErrorSeverity {
  low,      // Can be ignored or logged
  medium,   // Should be shown to user
  high,     // Requires user action
  critical  // Application cannot continue
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  bool get isRetryable => true;
  
  @override
  String get userMessage => 'Network error. Please check your connection.';
}

/// API-related exceptions
class ApiException extends AppException {
  final int? statusCode;
  final Map<String, dynamic>? response;
  
  const ApiException({
    required super.message,
    this.statusCode,
    this.response,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  bool get isRetryable => statusCode == null || statusCode! >= 500;
  
  @override
  String get userMessage {
    if (statusCode == 404) return 'Resource not found';
    if (statusCode == 401) return 'Please login again';
    if (statusCode == 403) return 'Access denied';
    if (statusCode! >= 500) return 'Server error. Please try again later.';
    return 'An error occurred. Please try again.';
  }
  
  @override
  ErrorSeverity get severity {
    if (statusCode == 401 || statusCode == 403) return ErrorSeverity.high;
    if (statusCode! >= 500) return ErrorSeverity.critical;
    return ErrorSeverity.medium;
  }
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;
  
  const ValidationException({
    required super.message,
    this.fieldErrors,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  String get userMessage => 'Please check your input and try again.';
  
  @override
  ErrorSeverity get severity => ErrorSeverity.low;
}

/// Business logic exceptions
class BusinessException extends AppException {
  const BusinessException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  ErrorSeverity get severity => ErrorSeverity.medium;
}

/// Cache exceptions
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  bool get isRetryable => true;
  
  @override
  ErrorSeverity get severity => ErrorSeverity.low;
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  ErrorSeverity get severity => ErrorSeverity.high;
  
  @override
  String get userMessage => 'Authentication failed. Please login again.';
}

/// Permission exceptions
class PermissionException extends AppException {
  final String permission;
  
  const PermissionException({
    required super.message,
    required this.permission,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  ErrorSeverity get severity => ErrorSeverity.high;
  
  @override
  String get userMessage => 'Permission required: $permission';
}

/// Data exceptions
class DataException extends AppException {
  const DataException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  bool get isRetryable => true;
}

/// Timeout exceptions
class TimeoutException extends AppException {
  final Duration timeout;
  
  const TimeoutException({
    required super.message,
    required this.timeout,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  bool get isRetryable => true;
  
  @override
  String get userMessage => 'Request timed out. Please try again.';
}

/// Unknown exceptions wrapper
class UnknownException extends AppException {
  const UnknownException({
    super.message = 'An unexpected error occurred',
    super.originalError,
    super.stackTrace,
  });
  
  @override
  ErrorSeverity get severity => ErrorSeverity.critical;
  
  @override
  String get userMessage => 'Something went wrong. Please try again later.';
}