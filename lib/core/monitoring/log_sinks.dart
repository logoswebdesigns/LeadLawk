// Log sink implementations.
// Pattern: Strategy Pattern - different log outputs.
// Single Responsibility: Write logs to specific destinations.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'structured_logger.dart';

/// Console log sink
class ConsoleLogSink implements LogSink {
  final bool prettyPrint;
  
  ConsoleLogSink({this.prettyPrint = kDebugMode});
  
  @override
  void write(LogEntry entry) {
    if (prettyPrint) {
      _writePretty(entry);
    } else {
      _writeJson(entry);
    }
  }
  
  void _writePretty(LogEntry entry) {
    final levelIcon = _getLevelIcon(entry.level);
    final levelColor = _getLevelColor(entry.level);
    
    debugPrint('$levelIcon ${entry.timestamp.toIso8601String()} '
        '[$levelColor${entry.level.name.toUpperCase()}$_resetColor] '
        '${entry.message}');
    
    if (entry.fields.isNotEmpty) {
      entry.fields.forEach((key, value) {
        debugPrint('  $key: $value');
      });
    }
  }
  
  void _writeJson(LogEntry entry) {
    debugPrint(jsonEncode(entry.toJson()));
  }
  
  String _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.trace: return '🔍';
      case LogLevel.debug: return '🐛';
      case LogLevel.info: return 'ℹ️';
      case LogLevel.warning: return '⚠️';
      case LogLevel.error: return '❌';
      case LogLevel.fatal: return '💀';
    }
  }
  
  String _getLevelColor(LogLevel level) {
    if (!kDebugMode) return '';
    switch (level) {
      case LogLevel.trace: return '\x1B[90m';  // Gray
      case LogLevel.debug: return '\x1B[36m';  // Cyan
      case LogLevel.info: return '\x1B[32m';   // Green
      case LogLevel.warning: return '\x1B[33m'; // Yellow
      case LogLevel.error: return '\x1B[31m';  // Red
      case LogLevel.fatal: return '\x1B[35m';  // Magenta
    }
  }
  
  static const String _resetColor = '\x1B[0m';
}

/// File log sink
class FileLogSink implements LogSink {
  final String filePath;
  final int maxFileSize;
  final int maxFiles;
  IOSink? _sink;
  
  FileLogSink({
    required this.filePath,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
  }) {
    _openFile();
  }
  
  void _openFile() {
    final file = File(filePath);
    _sink = file.openWrite(mode: FileMode.append);
  }
  
  @override
  void write(LogEntry entry) {
    _sink?.writeln(jsonEncode(entry.toJson()));
    _checkRotation();
  }
  
  void _checkRotation() {
    // Simplified rotation check
    final file = File(filePath);
    if (file.existsSync() && file.lengthSync() > maxFileSize) {
      _rotate();
    }
  }
  
  void _rotate() {
    _sink?.close();
    // Rotate files logic here
    _openFile();
  }
}