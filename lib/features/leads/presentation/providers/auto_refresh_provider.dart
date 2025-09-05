import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage auto-refresh preference for the leads list
/// When enabled, new leads from WebSocket will automatically refresh the list
/// When disabled, user must manually refresh to see new leads
final autoRefreshLeadsProvider = StateProvider<bool>((ref) {
  // Default to disabled for better performance and less jarring UX
  return false;
});

/// Provider to track if there are pending updates that haven't been shown
/// This is used to show a notification badge when auto-refresh is off
final pendingLeadsUpdateProvider = StateProvider<int>((ref) {
  return 0;
});