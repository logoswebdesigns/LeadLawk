import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ServerStatus {
  checking,
  online,
  offline,
  starting,
  error,
}

class ServerState {
  final ServerStatus status;
  final String? message;
  final DateTime? lastCheck;
  final List<String> logs;

  ServerState({
    required this.status,
    this.message,
    this.lastCheck,
    List<String>? logs,
  }) : logs = logs ?? const [];

  ServerState copyWith({
    ServerStatus? status,
    String? message,
    DateTime? lastCheck,
    List<String>? logs,
  }) {
    return ServerState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastCheck: lastCheck ?? this.lastCheck,
      logs: logs ?? this.logs,
    );
  }
}

class ServerStatusNotifier extends StateNotifier<ServerState> {
  final Dio dio;
  Timer? _healthCheckTimer;
  Process? _serverProcess;
  
  ServerStatusNotifier(this.dio) : super(ServerState(status: ServerStatus.checking)) {
    checkServerHealth();
    _startPeriodicHealthCheck();
  }

  void _startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkServerHealth();
    });
  }

  Future<void> checkServerHealth() async {
    try {
      state = state.copyWith(status: ServerStatus.checking);
      
      final response = await dio.get(
        'http://localhost:8000/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 2),
          sendTimeout: const Duration(seconds: 2),
        ),
      );
      
      if (response.statusCode == 200) {
        state = ServerState(
          status: ServerStatus.online,
          message: 'Connected to LeadLoq API',
          lastCheck: DateTime.now(),
          logs: state.logs,
        );
      } else {
        state = ServerState(
          status: ServerStatus.offline,
          message: 'Server not responding',
          lastCheck: DateTime.now(),
          logs: state.logs,
        );
        _tryStartServer();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        state = ServerState(
          status: ServerStatus.offline,
          message: 'Cannot connect to server',
          lastCheck: DateTime.now(),
          logs: state.logs,
        );
        _tryStartServer();
      } else {
        state = ServerState(
          status: ServerStatus.error,
          message: 'Error: ${e.message}',
          lastCheck: DateTime.now(),
          logs: state.logs,
        );
      }
    } catch (e) {
      state = ServerState(
        status: ServerStatus.error,
        message: 'Unexpected error: $e',
        lastCheck: DateTime.now(),
        logs: state.logs,
      );
    }
  }

  Future<void> _tryStartServer() async {
    if (_serverProcess != null) {
      return;
    }
    
    state = state.copyWith(
      status: ServerStatus.starting,
      message: 'Starting server...',
    );
    
    try {
      final projectPath = Directory.current.path;
      final serverPath = '$projectPath/server';
      final venvPath = '$serverPath/venv';
      
      if (!await Directory(venvPath).exists()) {
        state = ServerState(
          status: ServerStatus.error,
          message: 'Server not configured. Please run: cd server && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt',
          lastCheck: DateTime.now(),
          logs: state.logs,
        );
        return;
      }
      
      _serverProcess = await Process.start(
        '$venvPath/bin/python',
        ['main.py'],
        workingDirectory: serverPath,
        environment: {
          'PATH': '$venvPath/bin:${Platform.environment['PATH']}',
        },
      );
      
      void appendLog(String line) {
        final List<String> updated = List<String>.from(state.logs)..add(line);
        // Keep last 500 lines
        final trimmed = updated.length > 500 ? updated.sublist(updated.length - 500) : updated;
        state = state.copyWith(logs: trimmed);
      }

      _serverProcess!.stdout.listen((data) {
        final output = String.fromCharCodes(data);
        for (final line in output.split('\n')) {
          if (line.trim().isEmpty) continue;
          appendLog('[OUT] ${line.trim()}');
        }
        if (output.contains('Uvicorn running on')) {
          Future.delayed(const Duration(seconds: 2), () {
            checkServerHealth();
          });
        }
      });

      _serverProcess!.stderr.listen((data) {
        final error = String.fromCharCodes(data);
        for (final line in error.split('\n')) {
          if (line.trim().isEmpty) continue;
          appendLog('[ERR] ${line.trim()}');
        }
      });
      
      await Future.delayed(const Duration(seconds: 5));
      checkServerHealth();
      
    } catch (e) {
      state = ServerState(
        status: ServerStatus.error,
        message: 'Failed to start server: $e',
        lastCheck: DateTime.now(),
        logs: state.logs,
      );
    }
  }

  Future<void> stopServer() async {
    _serverProcess?.kill();
    _serverProcess = null;
    state = state.copyWith(
      status: ServerStatus.offline,
      message: 'Server stopped',
    );
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _serverProcess?.kill();
    super.dispose();
  }
}

final serverStatusProvider = StateNotifierProvider<ServerStatusNotifier, ServerState>((ref) {
  final dio = ref.watch(dioProvider);
  return ServerStatusNotifier(dio);
});

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

/// Fetches the last N lines from the backend server logs.
final serverLogsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final resp = await dio.get(
      'http://localhost:8000/logs',
      queryParameters: {'tail': 500},
      options: Options(
        receiveTimeout: const Duration(seconds: 2),
        sendTimeout: const Duration(seconds: 2),
      ),
    );
    final data = resp.data;
    if (data is Map && data['lines'] is List) {
      return List<String>.from(data['lines']);
    }
  } catch (_) {
    // ignore
  }
  return const <String>[];
});

/// Returns the list of current jobs from the API (sorted by updated_at).
final jobsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final resp = await dio.get(
      'http://localhost:8000/jobs',
      options: Options(
        receiveTimeout: const Duration(seconds: 2),
        sendTimeout: const Duration(seconds: 2),
      ),
    );
    final data = resp.data;
    if (data is List) {
      return data.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
  } catch (_) {}
  return const <Map<String, dynamic>>[];
});

/// Auto-refreshing jobs provider that updates every 3 seconds
class AutoRefreshJobsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  Timer? _timer;
  
  AutoRefreshJobsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _startAutoRefresh();
  }
  
  void _startAutoRefresh() {
    // Initial fetch
    _fetchJobs();
    
    // Set up periodic refresh every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchJobs();
    });
  }
  
  Future<void> _fetchJobs() async {
    // Check if notifier is still mounted before updating state
    if (!mounted) return;
    
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get(
        'http://localhost:8000/jobs',
        options: Options(
          receiveTimeout: const Duration(seconds: 2),
          sendTimeout: const Duration(seconds: 2),
        ),
      );
      
      // Check again after async operation
      if (!mounted) return;
      
      final data = resp.data;
      if (data is List) {
        final jobs = data.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        state = AsyncValue.data(jobs);
      } else {
        state = const AsyncValue.data(<Map<String, dynamic>>[]);
      }
    } catch (e, stack) {
      // Check if mounted before setting error state
      if (!mounted) return;
      
      // Don't overwrite existing data with error on refresh failure
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final autoRefreshJobsProvider = StateNotifierProvider.autoDispose<AutoRefreshJobsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return AutoRefreshJobsNotifier(ref);
});
