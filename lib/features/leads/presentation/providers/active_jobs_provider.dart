import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/entities/job.dart';
import '../../../../core/utils/debug_logger.dart';

class ActiveJobsState {
  final List<Job> jobs;
  final bool isLoading;
  final String? error;

  ActiveJobsState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
  });

  ActiveJobsState copyWith({
    List<Job>? jobs,
    bool? isLoading,
    String? error,
  }) {
    return ActiveJobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ActiveJobsNotifier extends StateNotifier<ActiveJobsState> {
  final Dio dio;
  Timer? _pollTimer;
  final Map<String, WebSocketChannel> _wsChannels = {};
  final Map<String, StreamSubscription> _wsSubscriptions = {};

  ActiveJobsNotifier(this.dio) : super(ActiveJobsState()) {
    _startPolling();
  }

  void _startPolling() {
    // Initial fetch
    fetchActiveJobs();
    
    // Poll for updates - use longer interval if many jobs to reduce server load
    _pollTimer = Timer.periodic(Duration(seconds: 5), (_) {
      fetchActiveJobs();
    });
  }

  Future<void> fetchActiveJobs() async {
    try {
      // Get the API base URL
      final apiUrl = kIsWeb 
          ? 'http://127.0.0.1:8000'
          : Platform.isMacOS 
              ? 'http://127.0.0.1:8000'
              : 'http://10.0.2.2:8000';
      
      final response = await dio.get(
        '$apiUrl/jobs',
        options: Options(
          headers: {'Accept': 'application/json'},
          sendTimeout: Duration(milliseconds: 5000),
          receiveTimeout: Duration(milliseconds: 10000),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson = response.data;
        
        // Debug logging
        print('📊 Total jobs from server: ${jobsJson.length}');
        final runningJobs = jobsJson.where((j) => j['status'] == 'running').length;
        final completedJobs = jobsJson.where((j) => j['status'] == 'completed' || j['status'] == 'done').length;
        print('  Running: $runningJobs, Completed: $completedJobs');
        
        // Filter for active jobs (running or pending)
        final activeJobs = jobsJson
            .where((job) => 
                job['status'] == 'running' || 
                job['status'] == 'pending' ||
                job['status'] == 'initializing' ||
                job['status'] == 'queued')
            .map((job) => Job(
                  id: job['id'],
                  status: _parseJobStatus(job['status']),
                  processed: job['processed'] ?? 0,
                  total: job['total'] ?? 0,
                  message: job['message'],
                  industry: job['industry'],
                  location: job['location'],
                  query: job['query'],
                  timestamp: _parseTimestamp(job),
                  type: job['type'],
                  totalCombinations: job['total_combinations'],
                  completedCombinations: job['completed_combinations'],
                  childJobs: job['child_jobs'] != null 
                      ? List<String>.from(job['child_jobs'])
                      : null,
                  parentId: job['parent_id'],
                  leadsFound: job['leads_found'],
                  totalRequested: job['total_requested'] ?? job['total'],
                  elapsedSeconds: job['elapsed_seconds'],
                ))
            .toList();

        print('  Active jobs to display: ${activeJobs.length}');
        if (activeJobs.isNotEmpty) {
          for (final job in activeJobs) {
            if (job.parentId != null) {
              print('    Child job: ${job.location} - Status: ${job.status} - Elapsed: ${job.elapsedSeconds}s');
            }
          }
        }
        
        state = state.copyWith(
          jobs: activeJobs,
          isLoading: false,
          error: null,
        );
        
        // Temporarily disable WebSocket connections due to 403 errors
        // The polling mechanism will still update job status every 2 seconds
        /*
        final jobsToConnect = activeJobs.take(5).toList();
        for (final job in jobsToConnect) {
          if (!_wsChannels.containsKey(job.id)) {
            connectToJob(job.id);
          }
        }
        */
        
        // Disconnect WebSocket for completed jobs
        final activeJobIds = activeJobs.map((j) => j.id).toSet();
        _wsChannels.keys.toList().forEach((jobId) {
          if (!activeJobIds.contains(jobId)) {
            disconnectFromJob(jobId);
          }
        });
      }
    } catch (e) {
      // Only log non-timeout errors to reduce console spam
      if (!e.toString().contains('Connection closed') && 
          !e.toString().contains('timeout')) {
        DebugLogger.error('Error fetching active jobs: $e');
      }
      // Don't set error state for network issues, just keep trying
      // The polling will retry in 2 seconds
    }
  }

  void connectToJob(String jobId) async {
    // Prevent connecting if we already have too many connections
    if (_wsChannels.length >= 5) {
      return;
    }
    
    try {
      // Get the WebSocket URL
      final wsUrl = kIsWeb 
          ? 'ws://127.0.0.1:8000'
          : Platform.isMacOS 
              ? 'ws://127.0.0.1:8000'
              : 'ws://10.0.2.2:8000';
      
      final uri = Uri.parse('$wsUrl/ws/$jobId');
      
      final channel = WebSocketChannel.connect(uri);
      _wsChannels[jobId] = channel;
      
      _wsSubscriptions[jobId] = channel.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            _updateJobFromWebSocket(jobId, data);
          } catch (e) {
            DebugLogger.websocket('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          DebugLogger.websocket('WebSocket error for job $jobId: $error');
          // Clean up on error
          _wsChannels.remove(jobId);
          _wsSubscriptions[jobId]?.cancel();
          _wsSubscriptions.remove(jobId);
          
          // Only reconnect if it's not a connection failure and job still active
          if (!error.toString().contains('Failed host lookup') && 
              !error.toString().contains('Connection refused') &&
              !error.toString().contains('Connection reset')) {
            Future.delayed(Duration(seconds: 10), () {
              if (state.jobs.any((job) => job.id == jobId && job.status == JobStatus.running)) {
                connectToJob(jobId);
              }
            });
          }
        },
        onDone: () {
          DebugLogger.websocket('WebSocket closed for job $jobId');
          _wsChannels.remove(jobId);
          _wsSubscriptions.remove(jobId);
        },
        cancelOnError: true,
      );
    } catch (e) {
      DebugLogger.websocket('Failed to connect to WebSocket for job $jobId: $e');
      // Clean up on failure
      _wsChannels.remove(jobId);
      _wsSubscriptions[jobId]?.cancel();
      _wsSubscriptions.remove(jobId);
    }
  }
  
  void disconnectFromJob(String jobId) {
    _wsSubscriptions[jobId]?.cancel();
    _wsChannels[jobId]?.sink.close();
    _wsSubscriptions.remove(jobId);
    _wsChannels.remove(jobId);
  }

  void _updateJobFromWebSocket(String jobId, Map<String, dynamic> data) {
    // Debug logging for WebSocket data
    print('🔄 WebSocket update for job $jobId:');
    print('  Status: ${data['status']}');
    print('  Elapsed seconds: ${data['elapsed_seconds']}');
    print('  Processed: ${data['processed']} / Total: ${data['total']}');
    print('  Leads found: ${data['leads_found']}');
    print('  Message: ${data['message']}');
    
    final jobs = List<Job>.from(state.jobs);
    final index = jobs.indexWhere((job) => job.id == jobId);
    
    if (index != -1) {
      print('  Found job at index $index, updating...');
      jobs[index] = Job(
        id: jobId,
        status: _parseJobStatus(data['status']),
        processed: data['processed'] ?? jobs[index].processed,
        total: data['total'] ?? jobs[index].total,
        message: data['message'] ?? jobs[index].message,
        industry: data['industry'] ?? jobs[index].industry,
        location: data['location'] ?? jobs[index].location,
        query: data['query'] ?? jobs[index].query,
        timestamp: _parseTimestamp(data) ?? jobs[index].timestamp,
        type: jobs[index].type,
        totalCombinations: data['total_combinations'] ?? jobs[index].totalCombinations,
        completedCombinations: data['completed_combinations'] ?? jobs[index].completedCombinations,
        childJobs: jobs[index].childJobs,
        parentId: jobs[index].parentId,
        leadsFound: data['leads_found'] ?? jobs[index].leadsFound,
        totalRequested: data['total_requested'] ?? data['total'] ?? jobs[index].totalRequested,
        elapsedSeconds: data['elapsed_seconds'] ?? jobs[index].elapsedSeconds,
      );
      
      // Log the updated job status
      print('  Updated job status: ${jobs[index].status}');
      print('  Updated elapsed: ${jobs[index].elapsedSeconds}s');
      
      // Remove completed jobs after a delay
      if (jobs[index].status == JobStatus.done) {
        print('  🏁 Job marked as done, will remove in 3 seconds');
        Future.delayed(const Duration(seconds: 3), () {
          removeJob(jobId);
        });
      }
      
      state = state.copyWith(jobs: jobs);
      print('  State updated with ${jobs.length} jobs');
    } else {
      print('  ⚠️ Job not found in current state');
    }
  }

  void removeJob(String jobId) {
    final jobs = state.jobs.where((job) => job.id != jobId).toList();
    state = state.copyWith(jobs: jobs);
  }

  JobStatus _parseJobStatus(String? status) {
    switch (status) {
      case 'pending':
      case 'queued':
        return JobStatus.pending;
      case 'initializing':
      case 'running':
        return JobStatus.running;
      case 'completed':
      case 'done':
        return JobStatus.done;
      case 'error':
      case 'failed':
        return JobStatus.error;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.pending;
    }
  }

  DateTime? _parseTimestamp(Map<String, dynamic> job) {
    
    // Try timestamp field first (server now consistently uses this)
    if (job['timestamp'] != null) {
      // Handle number (could be event loop time or unix timestamp)
      if (job['timestamp'] is num) {
        final value = (job['timestamp'] as num).toDouble();
        
        // If it's a small number (< year 2000 in unix time), treat as seconds ago
        if (value < 946684800) {
          final result = DateTime.now().subtract(Duration(seconds: value.toInt()));
          return result;
        }
        // Otherwise treat as unix timestamp
        final result = DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
        return result;
      }
      // Handle string (ISO format)
      if (job['timestamp'] is String) {
        // Parse as UTC and convert to local
        final parsed = DateTime.tryParse(job['timestamp']);
        if (parsed != null) {
          // If the timestamp doesn't have a timezone indicator, assume it's UTC
          final utcTime = parsed.isUtc ? parsed : DateTime.utc(
            parsed.year, parsed.month, parsed.day,
            parsed.hour, parsed.minute, parsed.second,
            parsed.millisecond, parsed.microsecond
          );
          final localTime = utcTime.toLocal();
          return localTime;
        }
      }
    }
    
    // Fall back to created_at field (for older jobs)
    if (job['created_at'] != null) {
      if (job['created_at'] is String) {
        final parsed = DateTime.tryParse(job['created_at']);
        if (parsed != null) {
          // If the timestamp doesn't have a timezone indicator, assume it's UTC
          final utcTime = parsed.isUtc ? parsed : DateTime.utc(
            parsed.year, parsed.month, parsed.day,
            parsed.hour, parsed.minute, parsed.second,
            parsed.millisecond, parsed.microsecond
          );
          final localTime = utcTime.toLocal();
          return localTime;
        }
      }
    }
    
    // If neither exists or parse fails, return null
    return null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    // Close all WebSocket connections
    for (final jobId in _wsChannels.keys) {
      disconnectFromJob(jobId);
    }
    super.dispose();
  }
}

final activeJobsProvider = StateNotifierProvider<ActiveJobsNotifier, ActiveJobsState>((ref) {
  final dio = ref.watch(dioProvider);
  return ActiveJobsNotifier(dio);
});

// Import from existing provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});