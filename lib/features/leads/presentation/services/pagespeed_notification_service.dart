import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/pagespeed_status_provider.dart';

/// Service to handle PageSpeed test completion notifications
/// Implements rate limiting and global notification display
class PageSpeedNotificationService {
  static final PageSpeedNotificationService _instance = PageSpeedNotificationService._internal();
  factory PageSpeedNotificationService() => _instance;
  PageSpeedNotificationService._internal();

  // Rate limiting configuration
  static const int _maxNotificationsPerMinute = 5;
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  
  // Track recent notifications for rate limiting
  final List<DateTime> _recentNotifications = [];
  Timer? _cleanupTimer;
  
  // Queue for pending notifications when rate limited
  final List<_NotificationData> _pendingQueue = [];
  bool _processingQueue = false;
  
  // Global context for showing notifications
  BuildContext? _context;
  
  void initialize(BuildContext context) {
    _context = context;
    _startCleanupTimer();
  }
  
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cleanupOldNotifications();
    });
  }
  
  void _cleanupOldNotifications() {
    final cutoff = DateTime.now().subtract(_rateLimitWindow);
    _recentNotifications.removeWhere((time) => time.isBefore(cutoff));
  }
  
  /// Show a PageSpeed completion notification with rate limiting
  void showPageSpeedComplete({
    required String leadId,
    required String businessName,
    int? mobileScore,
    int? desktopScore,
    bool hasError = false,
  }) {
    if (_context == null) return;
    
    final notification = _NotificationData(
      leadId: leadId,
      businessName: businessName,
      mobileScore: mobileScore,
      desktopScore: desktopScore,
      hasError: hasError,
      timestamp: DateTime.now(),
    );
    
    // Check rate limit
    if (_shouldRateLimit()) {
      _pendingQueue.add(notification);
      _scheduleQueueProcessing();
      return;
    }
    
    _showNotification(notification);
  }
  
  bool _shouldRateLimit() {
    _cleanupOldNotifications();
    return _recentNotifications.length >= _maxNotificationsPerMinute;
  }
  
  void _scheduleQueueProcessing() {
    if (_processingQueue) return;
    _processingQueue = true;
    
    Future.delayed(const Duration(seconds: 15), () {
      _processingQueue = false;
      if (_pendingQueue.isNotEmpty && !_shouldRateLimit()) {
        final notification = _pendingQueue.removeAt(0);
        _showNotification(notification);
        
        if (_pendingQueue.isNotEmpty) {
          _scheduleQueueProcessing();
        }
      }
    });
  }
  
  void _showNotification(_NotificationData data) {
    if (_context == null || !_context!.mounted) return;
    
    _recentNotifications.add(DateTime.now());
    
    final message = data.hasError
        ? 'PageSpeed test failed for ${data.businessName}'
        : 'PageSpeed complete: ${data.businessName}\nMobile: ${data.mobileScore ?? "N/A"} | Desktop: ${data.desktopScore ?? "N/A"}';
    
    final backgroundColor = data.hasError
        ? AppTheme.errorRed
        : (data.mobileScore != null && data.mobileScore! < 50) || 
          (data.desktopScore != null && data.desktopScore! < 50)
            ? AppTheme.warningOrange
            : AppTheme.successGreen;
    
    // Show the toast with tap action
    _showInteractiveToast(
      context: _context!,
      message: message,
      icon: data.hasError ? Icons.error : Icons.speed,
      backgroundColor: backgroundColor,
      onTap: () {
        // Navigate to lead details page
        if (_context != null && _context!.mounted) {
          _context!.go('/leads/${data.leadId}');
        }
      },
    );
  }
  
  /// Show a summary notification for bulk PageSpeed tests
  void showBulkSummary({
    required int totalTests,
    required int completed,
    required int failed,
  }) {
    if (_context == null || !_context!.mounted) return;
    
    final message = 'PageSpeed batch complete\n$completed succeeded, $failed failed';
    
    _showInteractiveToast(
      context: _context!,
      message: message,
      icon: Icons.dashboard,
      backgroundColor: failed > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
      duration: const Duration(seconds: 5),
    );
  }
  
  /// Enhanced toast with tap support
  void _showInteractiveToast({
    required BuildContext context,
    required String message,
    IconData? icon,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _InteractiveToastWidget(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        duration: duration,
        onTap: onTap,
        onDismiss: () => overlayEntry.remove(),
      ),
    );
    
    overlay.insert(overlayEntry);
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
    _context = null;
  }
}

class _NotificationData {
  final String leadId;
  final String businessName;
  final int? mobileScore;
  final int? desktopScore;
  final bool hasError;
  final DateTime timestamp;
  
  _NotificationData({
    required this.leadId,
    required this.businessName,
    this.mobileScore,
    this.desktopScore,
    required this.hasError,
    required this.timestamp,
  });
}

class _InteractiveToastWidget extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  
  const _InteractiveToastWidget({
    required this.message,
    this.icon,
    this.backgroundColor,
    required this.duration,
    this.onTap,
    required this.onDismiss,
  });
  
  @override
  State<_InteractiveToastWidget> createState() => _InteractiveToastWidgetState();
}

class _InteractiveToastWidgetState extends State<_InteractiveToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    _controller.forward();
    
    // Auto dismiss after duration
    _dismissTimer = Timer(widget.duration, _dismiss);
  }
  
  void _dismiss() {
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }
  
  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                widget.onTap?.call();
                _dismiss();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.onTap != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Tap to view details',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.6),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Provider for the notification service
final pageSpeedNotificationServiceProvider = Provider<PageSpeedNotificationService>((ref) {
  return PageSpeedNotificationService();
});