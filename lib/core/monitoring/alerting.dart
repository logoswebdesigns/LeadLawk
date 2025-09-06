// Alerting system for monitoring.
// Pattern: Observer Pattern - alert on conditions.
// Single Responsibility: Manage and trigger alerts.

import 'dart:async';
import 'structured_logger.dart';
import 'package:flutter/foundation.dart';

/// Alert severity
enum AlertSeverity {
  info,
  warning,
  critical,
  emergency,
}

/// Alert
class Alert {
  final String id;
  final String name;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  
  Alert({
    required this.id,
    required this.name,
    required this.message,
    required this.severity,
    required this.timestamp,
    Map<String, dynamic>? context,
  }) : context = context ?? {};
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'message': message,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
  };
}

/// Alert rule
abstract class AlertRule {
  String get name;
  Duration get evaluationInterval;
  
  Future<Alert?> evaluate();
}

/// Alert manager
class AlertManager {
  static final AlertManager _instance = AlertManager._internal();
  factory AlertManager() => _instance;
  AlertManager._internal();
  
  final List<AlertRule> _rules = [];
  final List<AlertChannel> _channels = [];
  final Map<String, Timer> _ruleTimers = {};
  final StructuredLogger _logger = StructuredLogger();
  final Set<String> _activeAlerts = {};
  
  /// Register an alert rule
  void registerRule(AlertRule rule) {
    _rules.add(rule);
    _startRuleEvaluation(rule);
  }
  
  /// Add alert channel
  void addChannel(AlertChannel channel) {
    _channels.add(channel);
  }
  
  /// Start rule evaluation
  void _startRuleEvaluation(AlertRule rule) {
    _ruleTimers[rule.name]?.cancel();
    _ruleTimers[rule.name] = Timer.periodic(
      rule.evaluationInterval,
      (_) => _evaluateRule(rule),
    );
  }
  
  /// Evaluate a rule
  Future<void> _evaluateRule(AlertRule rule) async {
    try {
      final alert = await rule.evaluate();
      
      if (alert != null) {
        await _triggerAlert(alert);
      } else {
        _clearAlert(rule.name);
      }
    } catch (e) {
      _logger.error('Alert rule evaluation failed', fields: {
        'rule': rule.name,
        'error': e.toString(),
      });
    }
  }
  
  /// Trigger an alert
  Future<void> _triggerAlert(Alert alert) async {
    // Deduplicate alerts
    if (_activeAlerts.contains(alert.id)) {
      return;
    }
    
    _activeAlerts.add(alert.id);
    
    _logger.warning('Alert triggered', fields: alert.toJson());
    
    // Send to all channels
    for (final channel in _channels) {
      try {
        await channel.send(alert);
      } catch (e) {
        _logger.error('Failed to send alert', fields: {
          'channel': channel.runtimeType.toString(),
          'alert': alert.id,
          'error': e.toString(),
        });
      }
    }
  }
  
  /// Clear an alert
  void _clearAlert(String ruleName) {
    _activeAlerts.removeWhere((id) => id.startsWith(ruleName));
  }
  
  /// Stop all rules
  void stopAllRules() {
    for (final timer in _ruleTimers.values) {
      timer.cancel();
    }
    _ruleTimers.clear();
  }
}

/// Alert channel interface
abstract class AlertChannel {
  Future<void> send(Alert alert);
}

/// Console alert channel
class ConsoleAlertChannel implements AlertChannel {
  @override
  Future<void> send(Alert alert) async {
    final icon = _getSeverityIcon(alert.severity);
    debugPrint('$icon ALERT: ${alert.name} - ${alert.message}');
  }
  
  String _getSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info: return 'ℹ️';
      case AlertSeverity.warning: return '⚠️';
      case AlertSeverity.critical: return '🚨';
      case AlertSeverity.emergency: return '🆘';
    }
  }
}

/// Threshold alert rule
class ThresholdAlertRule implements AlertRule {
  @override
  final String name;
  
  @override
  final Duration evaluationInterval;
  
  final Future<double> Function() getValue;
  final double threshold;
  final AlertSeverity severity;
  final String message;
  
  ThresholdAlertRule({
    required this.name,
    required this.getValue,
    required this.threshold,
    required this.severity,
    required this.message,
    this.evaluationInterval = const Duration(minutes: 1),
  });
  
  @override
  Future<Alert?> evaluate() async {
    final value = await getValue();
    
    if (value > threshold) {
      return Alert(
        id: '$name-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        message: message,
        severity: severity,
        timestamp: DateTime.now(),
        context: {
          'value': value,
          'threshold': threshold,
        },
      );
    }
    
    return null;
  }
}