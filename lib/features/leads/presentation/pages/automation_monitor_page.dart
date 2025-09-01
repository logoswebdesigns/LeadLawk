import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/websocket_service.dart';
import '../providers/server_status_provider.dart';

class AutomationMonitorPage extends ConsumerStatefulWidget {
  final String jobId;
  
  const AutomationMonitorPage({super.key, required this.jobId});
  
  @override
  ConsumerState<AutomationMonitorPage> createState() => _AutomationMonitorPageState();
}

class _AutomationMonitorPageState extends ConsumerState<AutomationMonitorPage> {
  final WebSocketService _wsService = WebSocketService();
  final List<String> _logs = [];
  Map<String, dynamic>? _jobStatus;
  final ScrollController _scrollController = ScrollController();
  Timer? _httpPoller;
  int _httpTailCount = 0;
  
  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _startHttpFallbackPoller();
  }
  
  void _connectWebSocket() {
    _wsService.connect(widget.jobId);
    
    _wsService.logs.listen((log) {
      setState(() {
        _logs.add(log);
      });
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
    
    _wsService.status.listen((status) {
      // DEBUG: print('🔔 WebSocket status update received: $status');
      setState(() {
        _jobStatus = status;
      });
      
      if (status['status'] == 'done') {
        // DEBUG: print('✅ Job completed - processed: ${status['processed']}, total: ${status['total']}');
        _showCompletionDialog();
      } else if (status['status'] == 'error') {
        // DEBUG: print('❌ Job failed with error: ${status['message']}');
        _showErrorDialog(status['message'] ?? 'Unknown error');
      } else if (status['status'] == 'running') {
        // DEBUG: print('🏃 Job running - processed: ${status['processed']}, total: ${status['total']}');
      }
    });
  }
  
  void _startHttpFallbackPoller() {
    // Poll HTTP logs as a fallback in case WS is blocked or drops events
    _httpPoller?.cancel();
    _httpPoller = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final dio = ref.read(dioProvider);
        final resp = await dio.get(
          'http://localhost:8000/jobs/${widget.jobId}/logs',
          queryParameters: {'tail': 500},
          options: Options(
            receiveTimeout: const Duration(seconds: 2),
            sendTimeout: const Duration(seconds: 2),
          ),
        );
        final data = resp.data as Map<String, dynamic>;
        final lines = (data['lines'] as List<dynamic>).cast<String>();
        // Append only new lines we haven't seen
        if (lines.length > _httpTailCount) {
          final newLines = lines.sublist(_httpTailCount);
          setState(() {
            _logs.addAll(newLines);
            _httpTailCount = lines.length;
          });
          // Auto-scroll to bottom
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        }
      } catch (_) {
        // ignore; keep polling
      }
    });
  }
  
  void _showCompletionDialog() async {
    // Get the actual lead count from the API instead of relying on WebSocket status
    int actualLeadCount = _jobStatus?['processed'] ?? 0;
    // DEBUG: print('💬 Completion dialog - WebSocket processed count: $actualLeadCount');
    // DEBUG: print('💬 Full job status: $_jobStatus');
    
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('http://localhost:8000/leads');
      if (response.statusCode == 200) {
        final leads = response.data as List;
        // DEBUG: print('💬 Total leads in database: ${leads.length}');
        
        // Count recently created leads (within the last few minutes)
        final now = DateTime.now();
        final recentLeads = leads.where((lead) {
          try {
            final createdAt = DateTime.parse(lead['created_at']);
            return now.difference(createdAt).inMinutes < 10; // Leads created in last 10 minutes
          } catch (e) {
            return false;
          }
        }).length;
        
        // DEBUG: print('💬 Recent leads (last 10 minutes): $recentLeads');
        
        // Use the higher count between WebSocket status and recent leads
        if (recentLeads > actualLeadCount) {
          actualLeadCount = recentLeads;
          // DEBUG: print('💬 Using recent leads count: $actualLeadCount');
        } else {
          // DEBUG: print('💬 Using WebSocket count: $actualLeadCount');
        }
      }
    } catch (e) {
      // If API call fails, fall back to WebSocket status
      // DEBUG: print('❌ Failed to fetch actual lead count: $e');
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen),
            SizedBox(width: 12),
            Text('Automation Complete!'),
          ],
        ),
        content: Text(
          'Successfully scraped $actualLeadCount leads.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/');
            },
            child: const Text('View Leads'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String error) {
    final logsPreview = _logs.isNotEmpty
        ? _logs.sublist(_logs.length - (_logs.length > 10 ? 10 : _logs.length))
        : const <String>[];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: AppTheme.errorRed),
            SizedBox(width: 12),
            Text('Automation Failed'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(error),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Recent output:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                color: Colors.black87,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: logsPreview.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                      child: Text(
                        logsPreview[index],
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Stay Here'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/server');
            },
            child: const Text('View Diagnostics'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/');
            },
            child: const Text('Back to Leads'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _wsService.dispose();
    _scrollController.dispose();
    _httpPoller?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final processed = _jobStatus?['processed'] ?? 0;
    final total = _jobStatus?['total'] ?? 0;
    final progress = total > 0 ? processed / total : 0.0;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkGray),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/LeadLoq-logo.png',
              height: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Browser Automation Progress',
                style: const TextStyle(
                  color: AppTheme.darkGray,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (_jobStatus?['status'] == 'running')
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cancel Job?'),
                      content: const Text('Are you sure you want to cancel this browser automation job?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed == true) {
                    try {
                      final dio = ref.read(dioProvider);
                      await dio.post('http://localhost:8000/jobs/${widget.jobId}/cancel');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Job cancellation requested')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to cancel: $e')),
                        );
                      }
                    }
                  }
                },
                tooltip: 'Cancel Job',
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if ((_jobStatus?['message'] as String?) != null && (_jobStatus?['status'] == 'error'))
            Container(
              width: double.infinity,
              color: AppTheme.errorRed.withOpacity(0.1),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error, color: AppTheme.errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _jobStatus?['message'] ?? 'Unknown error',
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  ),
                ],
              ),
            ),
          // Progress section
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: ${_jobStatus?['status'] ?? 'Initializing'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(_jobStatus?['status']),
                      ),
                    ),
                    Text(
                      '${_jobStatus?['processed'] ?? 0} / ${_jobStatus?['total'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.mediumGray.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(_jobStatus?['status']),
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}% Complete',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          
          // Logs section
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        color: Colors.green.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Server Logs',
                        style: TextStyle(
                          color: Colors.green.shade400,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'running':
        return AppTheme.primaryBlue;
      case 'done':
        return AppTheme.successGreen;
      case 'error':
        return AppTheme.errorRed;
      default:
        return AppTheme.mediumGray;
    }
  }
}
