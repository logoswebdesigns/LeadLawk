// Batch processor for optimizing API calls.
// Pattern: Batch Pattern - group multiple operations.
// Single Responsibility: Batch and optimize operations.

import 'dart:async';
import 'dart:collection';
import '../monitoring/structured_logger.dart';

/// Batch request
class BatchRequest<T> {
  final String id;
  final T data;
  final Completer<dynamic> completer;
  final DateTime timestamp;
  
  BatchRequest({
    required this.id,
    required this.data,
    required this.completer,
  }) : timestamp = DateTime.now();
}

/// Batch processor
class BatchProcessor<T> {
  final Duration batchWindow;
  final int maxBatchSize;
  final Future<Map<String, dynamic>> Function(List<T>) processBatch;
  final StructuredLogger _logger;
  
  final Queue<BatchRequest<T>> _queue = Queue();
  Timer? _batchTimer;
  bool _processing = false;
  
  BatchProcessor({
    required this.processBatch,
    this.batchWindow = const Duration(milliseconds: 100),
    this.maxBatchSize = 50,
    StructuredLogger? logger,
  }) : _logger = logger ?? StructuredLogger();
  
  /// Add item to batch
  Future<R> add<R>(String id, T item) {
    final completer = Completer<R>();
    final request = BatchRequest(
      id: id,
      data: item,
      completer: completer,
    );
    
    _queue.add(request);
    
    // Start batch timer if not running
    _batchTimer ??= Timer(batchWindow, _processPendingBatch);
    
    // Process immediately if batch is full
    if (_queue.length >= maxBatchSize) {
      _processPendingBatch();
    }
    
    return completer.future;
  }
  
  /// Process pending batch
  Future<void> _processPendingBatch() async {
    if (_processing || _queue.isEmpty) return;
    
    _processing = true;
    _batchTimer?.cancel();
    _batchTimer = null;
    
    // Get batch
    final batch = <BatchRequest<T>>[];
    while (batch.length < maxBatchSize && _queue.isNotEmpty) {
      batch.add(_queue.removeFirst());
    }
    
    _logger.debug('Processing batch', fields: {
      'size': batch.length,
      'remaining': _queue.length,
    });
    
    try {
      // Process batch
      final results = await processBatch(batch.map((r) => r.data).toList());
      
      // Complete futures
      for (final request in batch) {
        if (results.containsKey(request.id)) {
          request.completer.complete(results[request.id]);
        } else {
          request.completer.completeError(
            Exception('No result for batch item: ${request.id}'),
          );
        }
      }
      
      _logger.info('Batch processed successfully', fields: {
        'size': batch.length,
        'duration_ms': DateTime.now()
            .difference(batch.first.timestamp)
            .inMilliseconds,
      });
    } catch (e) {
      // Complete all with error
      for (final request in batch) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
      
      _logger.error('Batch processing failed', fields: {
        'size': batch.length,
        'error': e.toString(),
      });
    } finally {
      _processing = false;
      
      // Process next batch if queue not empty
      if (_queue.isNotEmpty) {
        _batchTimer = Timer(batchWindow, _processPendingBatch);
      }
    }
  }
  
  /// Flush all pending items
  Future<void> flush() async {
    while (_queue.isNotEmpty || _processing) {
      await _processPendingBatch();
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
  
  /// Cancel all pending items
  void cancel() {
    _batchTimer?.cancel();
    _batchTimer = null;
    
    while (_queue.isNotEmpty) {
      final request = _queue.removeFirst();
      request.completer.completeError(
        Exception('Batch processor cancelled'),
      );
    }
  }
}