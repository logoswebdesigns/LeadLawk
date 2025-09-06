import 'package:flutter/foundation.dart';

/// Debug logging utility that only outputs in debug mode
class DebugLogger {
  static void log(String message, {String? prefix}) {
    if (kDebugMode) {
      final logPrefix = prefix != null ? '[$prefix] ' : '';
      debugPrint('$logPrefix$message');
    }
  }
  
  static void error(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace:\n$stackTrace');
      }
    }
  }
  
  static void network(String message) {
    log(message, prefix: 'NETWORK');
  }
  
  static void database(String message) {
    log(message, prefix: 'DB');
  }
  
  static void websocket(String message) {
    log(message, prefix: 'WS');
  }
  
  static void navigation(String message) {
    log(message, prefix: 'NAV');
  }
  
  static void state(String message) {
    log(message, prefix: 'STATE');
  }
}