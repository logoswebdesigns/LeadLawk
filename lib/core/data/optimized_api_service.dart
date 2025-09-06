// Optimized API service with batching and deduplication.
// Pattern: Facade Pattern - simplify complex API operations.
// Single Responsibility: Optimize API communication.

import 'dart:async';
import 'package:dio/dio.dart';
import '../monitoring/structured_logger.dart';
import '../monitoring/metrics_collector.dart';
import 'batch_processor.dart';

/// Request deduplication entry
class DedupEntry {
  final String key;
  final DateTime timestamp;
  final Completer<Response> completer;
  
  DedupEntry({
    required this.key,
    required this.completer,
  }) : timestamp = DateTime.now();
}

/// Optimized API service
class OptimizedApiService {
  final Dio _dio;
  final StructuredLogger _logger;
  final MetricsCollector _metrics;
  
  // Request deduplication
  final Map<String, DedupEntry> _pendingRequests = {};
  final Duration _dedupWindow = const Duration(milliseconds: 100);
  
  // Batch processors for different endpoints
  final Map<String, BatchProcessor> _batchProcessors = {};
  
  OptimizedApiService({
    required Dio dio,
    StructuredLogger? logger,
    MetricsCollector? metrics,
  }) : _dio = dio,
       _logger = logger ?? StructuredLogger(),
       _metrics = metrics ?? MetricsCollector();
  
  /// Register batch processor for endpoint
  void registerBatchProcessor(
    String endpoint,
    BatchProcessor processor,
  ) {
    _batchProcessors[endpoint] = processor;
  }
  
  /// Make optimized GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool deduplicate = true,
  }) async {
    // Create dedup key
    final dedupKey = deduplicate 
        ? _createDedupKey('GET', path, queryParameters)
        : null;
    
    // Check for pending request
    if (dedupKey != null) {
      final pending = _pendingRequests[dedupKey];
      if (pending != null && 
          DateTime.now().difference(pending.timestamp) < _dedupWindow) {
        _logger.debug('Request deduplicated', fields: {
          'method': 'GET',
          'path': path,
        });
        _metrics.incrementCounter('api.deduplicated');
        return await pending.completer.future;
      }
    }
    
    // Create new request
    final completer = Completer<Response>();
    if (dedupKey != null) {
      _pendingRequests[dedupKey] = DedupEntry(
        key: dedupKey,
        completer: completer,
      );
    }
    
    try {
      final response = await _metrics.timeOperation(
        'api.request',
        () => _dio.get(path, 
          queryParameters: queryParameters,
          options: options,
        ),
        tags: {'method': 'GET', 'path': path},
      );
      
      completer.complete(response);
      _metrics.incrementCounter('api.success');
      
      return response;
    } catch (e) {
      completer.completeError(e);
      _metrics.incrementCounter('api.error');
      rethrow;
    } finally {
      // Clean up dedup entry
      if (dedupKey != null) {
        Future.delayed(_dedupWindow, () {
          _pendingRequests.remove(dedupKey);
        });
      }
    }
  }
  
  /// Make batch GET request
  Future<List<T>> getBatch<T>(
    String endpoint,
    List<String> ids,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final processor = _batchProcessors[endpoint];
    if (processor == null) {
      throw Exception('No batch processor for endpoint: $endpoint');
    }
    
    // Process through batch
    final futures = <Future<T>>[];
    for (final id in ids) {
      futures.add(processor.add<T>(id, id));
    }
    
    return await Future.wait(futures);
  }
  
  /// Make optimized POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _metrics.timeOperation(
      'api.request',
      () => _dio.post(path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      tags: {'method': 'POST', 'path': path},
    );
  }
  
  /// Make batch POST request
  Future<List<Response>> postBatch(
    String path,
    List<Map<String, dynamic>> items, {
    Options? options,
  }) async {
    // Send as single batch request
    final response = await post(
      '$path/batch',
      data: {'items': items},
      options: options,
    );
    
    // Extract individual responses
    final results = response.data['results'] as List;
    return results.map((r) => Response(
      requestOptions: response.requestOptions,
      data: r,
      statusCode: 200,
    )).toList();
  }
  
  /// Create deduplication key
  String _createDedupKey(
    String method,
    String path,
    Map<String, dynamic>? params,
  ) {
    final paramStr = params?.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&') ?? '';
    return '$method:$path?$paramStr';
  }
  
  /// Prefetch data
  Future<void> prefetch(List<String> paths) async {
    final futures = <Future>[];
    
    for (final path in paths) {
      futures.add(
        get(path).catchError((e) {
          _logger.warning('Prefetch failed', fields: {
            'path': path,
            'error': e.toString(),
          });
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 500,
          );
        }),
      );
    }
    
    await Future.wait(futures);
    
    _logger.info('Prefetch completed', fields: {
      'paths': paths.length,
    });
  }
  
  /// Cancel all pending requests
  void cancelAll() {
    _dio.close();
    
    // Cancel batch processors
    for (final processor in _batchProcessors.values) {
      processor.cancel();
    }
  }
}