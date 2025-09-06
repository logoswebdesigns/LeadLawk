import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'paginated_leads_provider.dart';
import 'auto_refresh_provider.dart';
import '../../../../core/utils/debug_logger.dart';

class PageSpeedWebSocketNotifier extends StateNotifier<PageSpeedWebSocketState> {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  final Ref ref;
  final Map<String, Timer> _animationTimers = {};

  PageSpeedWebSocketNotifier(this.ref) : super(PageSpeedWebSocketState.disconnected()) {
    connect();
  }

  void connect() {
    try {
      state = PageSpeedWebSocketState.connecting();
      
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/ws/pagespeed'),
      );

      _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          DebugLogger.websocket('WebSocket error: $error');
          state = PageSpeedWebSocketState.disconnected(error: error.toString());
          _scheduleReconnect();
        },
        onDone: () {
          DebugLogger.websocket('WebSocket connection closed');
          state = PageSpeedWebSocketState.disconnected();
          _scheduleReconnect();
        },
      );

      state = PageSpeedWebSocketState.connected();
      DebugLogger.websocket('✅ PageSpeed WebSocket connected');
      
    } catch (e) {
      DebugLogger.websocket('Failed to connect WebSocket: $e');
      state = PageSpeedWebSocketState.disconnected(error: e.toString());
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> message = jsonDecode(data);
      final type = message['type'];
      
      switch (type) {
        case 'connected':
          DebugLogger.websocket('PageSpeed WebSocket confirmed connection');
          break;
          
        case 'heartbeat':
          // Ignore heartbeats
          break;
          
        case 'pagespeed_update':
          _handlePageSpeedUpdate(message);
          break;
          
        default:
          DebugLogger.websocket('Unknown WebSocket message type: $type');
      }
    } catch (e) {
      DebugLogger.websocket('Error handling WebSocket message: $e');
    }
  }

  void _handlePageSpeedUpdate(Map<String, dynamic> message) {
    final updateType = message['update_type'];
    final leadId = message['lead_id'];
    final data = message['data'] ?? {};
    
    DebugLogger.log('📊 PageSpeed update: $updateType for lead $leadId');
    
    switch (updateType) {
      case 'score_received':
        // Refresh leads list to show new scores
        DebugLogger.log('PageSpeed scores received for lead $leadId: Mobile=${data['mobile_score']}, Desktop=${data['desktop_score']}');
        // Only refresh if this lead is not pending deletion AND auto-refresh is enabled
        if (!state.pendingDeletions.contains(leadId)) {
          final autoRefresh = ref.read(autoRefreshLeadsProvider);
          if (autoRefresh) {
            ref.read(paginatedLeadsProvider.notifier).refreshLeads();
          } else {
            // Increment pending updates counter for PageSpeed scores
            final currentPending = ref.read(pendingLeadsUpdateProvider);
            ref.read(pendingLeadsUpdateProvider.notifier).state = currentPending + 1;
            DebugLogger.log('📦 Auto-refresh disabled, PageSpeed score update pending');
          }
        }
        break;
        
      case 'lead_deleted':
        // Mark lead for deletion animation
        final reason = data['reason'] ?? 'PageSpeed threshold exceeded';
        DebugLogger.log('Lead $leadId will be deleted: $reason');
        
        // Update state with pending deletion
        final newPendingDeletions = Set<String>.from(state.pendingDeletions)..add(leadId);
        final newDeletionReasons = Map<String, String>.from(state.deletionReasons);
        newDeletionReasons[leadId] = reason;
        
        state = state.copyWith(
          pendingDeletions: newPendingDeletions,
          deletionReasons: newDeletionReasons,
        );
        
        // Cancel any existing timer for this lead
        _animationTimers[leadId]?.cancel();
        
        // After animation delay, remove from pending deletions
        _animationTimers[leadId] = Timer(Duration(seconds: 3), () {
          final updatedPendingDeletions = Set<String>.from(state.pendingDeletions)..remove(leadId);
          final updatedDeletionReasons = Map<String, String>.from(state.deletionReasons)..remove(leadId);
          
          state = state.copyWith(
            pendingDeletions: updatedPendingDeletions,
            deletionReasons: updatedDeletionReasons,
          );
          
          // Now refresh to remove the deleted lead (only if auto-refresh is enabled)
          final autoRefresh = ref.read(autoRefreshLeadsProvider);
          if (autoRefresh) {
            ref.read(paginatedLeadsProvider.notifier).refreshLeads();
          } else {
            // Increment pending updates counter for deleted lead
            final currentPending = ref.read(pendingLeadsUpdateProvider);
            ref.read(pendingLeadsUpdateProvider.notifier).state = currentPending + 1;
            DebugLogger.log('📦 Auto-refresh disabled, lead deletion pending refresh');
          }
          _animationTimers.remove(leadId);
        });
        break;
        
      case 'test_started':
        // Could show test started indicator if needed
        DebugLogger.log('PageSpeed test started for lead $leadId');
        break;
        
      case 'lead_created':
        // Mark lead as new for animation
        DebugLogger.log('🆕 New lead created: $leadId');
        DebugLogger.log('🔄 Triggering leads refresh for new lead...');
        
        // Update state with new lead FIRST
        final newLeadsList = Set<String>.from(state.newLeads)..add(leadId);
        state = state.copyWith(newLeads: newLeadsList);
        
        // Force refresh the leads provider after a small delay to ensure database is updated (only if auto-refresh is enabled)
        Future.delayed(Duration(milliseconds: 100), () {
          final autoRefresh = ref.read(autoRefreshLeadsProvider);
          if (autoRefresh) {
            DebugLogger.log('🔄 Auto-refresh enabled, fetching new lead');
            ref.read(paginatedLeadsProvider.notifier).refreshLeads();
          } else {
            // Don't increment pending counter here as it's already handled in leads_list_page.dart
            DebugLogger.log('📦 Auto-refresh disabled, new lead will be shown on manual refresh');
          }
        });
        
        // Cancel any existing timer for this lead
        _animationTimers['new_$leadId']?.cancel();
        
        // Remove from new leads after animation (keep it longer for visibility)
        _animationTimers['new_$leadId'] = Timer(Duration(seconds: 5), () {
          final updatedNewLeads = Set<String>.from(state.newLeads)..remove(leadId);
          state = state.copyWith(newLeads: updatedNewLeads);
          _animationTimers.remove('new_$leadId');
        });
        break;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 5), () {
      DebugLogger.websocket('Attempting to reconnect PageSpeed WebSocket...');
      connect();
    });
  }

  bool isLeadPendingDeletion(String leadId) {
    return state.pendingDeletions.contains(leadId);
  }
  
  bool isNewLead(String leadId) {
    return state.newLeads.contains(leadId);
  }
  
  String? getDeletionReason(String leadId) {
    return state.deletionReasons[leadId];
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _animationTimers.forEach((_, timer) => timer.cancel());
    _animationTimers.clear();
    _channel?.sink.close(status.normalClosure);
    super.dispose();
  }
}

class PageSpeedWebSocketState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final Set<String> pendingDeletions;
  final Set<String> newLeads;
  final Map<String, String> deletionReasons;

  PageSpeedWebSocketState({
    required this.isConnected,
    required this.isConnecting,
    this.error,
    Set<String>? pendingDeletions,
    Set<String>? newLeads,
    Map<String, String>? deletionReasons,
  }) : pendingDeletions = pendingDeletions ?? {},
       newLeads = newLeads ?? {},
       deletionReasons = deletionReasons ?? {};

  factory PageSpeedWebSocketState.disconnected({String? error}) {
    return PageSpeedWebSocketState(
      isConnected: false,
      isConnecting: false,
      error: error,
    );
  }

  factory PageSpeedWebSocketState.connecting() {
    return PageSpeedWebSocketState(
      isConnected: false,
      isConnecting: true,
    );
  }

  factory PageSpeedWebSocketState.connected({
    Set<String>? pendingDeletions,
    Set<String>? newLeads,
    Map<String, String>? deletionReasons,
  }) {
    return PageSpeedWebSocketState(
      isConnected: true,
      isConnecting: false,
      pendingDeletions: pendingDeletions,
      newLeads: newLeads,
      deletionReasons: deletionReasons,
    );
  }
  
  PageSpeedWebSocketState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    Set<String>? pendingDeletions,
    Set<String>? newLeads,
    Map<String, String>? deletionReasons,
  }) {
    return PageSpeedWebSocketState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error ?? this.error,
      pendingDeletions: pendingDeletions ?? this.pendingDeletions,
      newLeads: newLeads ?? this.newLeads,
      deletionReasons: deletionReasons ?? this.deletionReasons,
    );
  }
}

final pageSpeedWebSocketProvider = StateNotifierProvider<PageSpeedWebSocketNotifier, PageSpeedWebSocketState>((ref) {
  return PageSpeedWebSocketNotifier(ref);
});