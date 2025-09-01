import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';

class LeadMonitorNotifier extends StateNotifier<List<Lead>> {
  final Ref ref;
  Timer? _timer;
  Set<String> _previousLeadIds = {};
  
  LeadMonitorNotifier(this.ref) : super([]) {
    _startMonitoring();
  }
  
  void _startMonitoring() {
    // Check for new leads every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForNewLeads();
    });
    
    // Initial check
    _checkForNewLeads();
  }
  
  Future<void> _checkForNewLeads() async {
    try {
      // Fetch leads directly from API
      final dio = Dio();
      final response = await dio.get('http://localhost:8000/leads');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final leads = data.map((json) => LeadModel.fromJson(json)).toList();
        
        final currentLeadIds = leads.map((lead) => lead.id).toSet();
        
        // Find new leads
        final newLeadIds = currentLeadIds.difference(_previousLeadIds);
        
        if (newLeadIds.isNotEmpty && _previousLeadIds.isNotEmpty) {
          // Don't show notifications on first load
          final List<Lead> newLeads = leads.where((lead) => newLeadIds.contains(lead.id)).cast<Lead>().toList();
          state = newLeads; // Store new leads in state for UI to handle
        }
        
        _previousLeadIds = currentLeadIds;
      }
    } catch (e) {
      // Silently handle errors - this is background monitoring
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// Global navigator key for accessing context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final leadMonitorProvider = StateNotifierProvider.autoDispose<LeadMonitorNotifier, List<Lead>>((ref) {
  return LeadMonitorNotifier(ref);
});