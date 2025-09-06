// Simple cached repository implementation.
// Pattern: Decorator Pattern - adds caching.
// Single Responsibility: Cache repository calls.

import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/cache/cache_manager.dart';
import '../../../../core/monitoring/structured_logger.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../../domain/repositories/leads_repository.dart';
import '../../domain/usecases/browser_automation_usecase.dart';

/// Simple cached repository
class SimpleCachedRepository implements LeadsRepository {
  final LeadsRepository _repository;
  final CacheManager _cache;
  final StructuredLogger _logger;
  final Duration _cacheTtl;
  
  SimpleCachedRepository({
    required LeadsRepository repository,
    CacheManager? cache,
    StructuredLogger? logger,
    Duration cacheTtl = const Duration(minutes: 5),
  }) : _repository = repository,
       _cache = cache ?? CacheManager(),
       _logger = logger ?? StructuredLogger(),
       _cacheTtl = cacheTtl;
  
  @override
  Future<Either<Failure, List<Lead>>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  }) async {
    final cacheKey = 'leads_$status$search$candidatesOnly';
    
    // Check cache
    final cached = await _cache.get<List<Lead>>(cacheKey);
    if (cached != null) {
      _logger.debug('Cache hit', fields: {'key': cacheKey});
      return Right(cached);
    }
    
    // Get from repository
    final result = await _repository.getLeads(
      status: status,
      search: search,
      candidatesOnly: candidatesOnly,
    );
    
    // Cache if successful
    result.fold(
      (failure) => null,
      (leads) => _cache.set(cacheKey, leads, ttl: _cacheTtl),
    );
    
    return result;
  }
  
  @override
  Future<Either<Failure, Lead>> getLead(String id) async {
    final cacheKey = 'lead_$id';
    
    // Check cache
    final cached = await _cache.get<Lead>(cacheKey);
    if (cached != null) {
      _logger.debug('Cache hit', fields: {'key': cacheKey});
      return Right(cached);
    }
    
    // Get from repository
    final result = await _repository.getLead(id);
    
    // Cache if successful
    result.fold(
      (failure) => null,
      (lead) => _cache.set(cacheKey, lead, ttl: _cacheTtl),
    );
    
    return result;
  }
  
  @override
  Future<Either<Failure, Lead>> updateLead(Lead lead) async {
    // Invalidate cache
    await _cache.remove('lead_${lead.id}');
    await _cache.clear();
    
    return await _repository.updateLead(lead);
  }
  
  @override
  Future<Either<Failure, Lead>> updateTimelineEntry(
    String leadId,
    LeadTimelineEntry entry,
  ) async {
    // Invalidate cache
    await _cache.remove('lead_$leadId');
    
    return await _repository.updateTimelineEntry(leadId, entry);
  }
  
  @override
  Future<Either<Failure, void>> addTimelineEntry(
    String leadId,
    Map<String, dynamic> entryData,
  ) async {
    // Invalidate cache
    await _cache.remove('lead_$leadId');
    
    return await _repository.addTimelineEntry(leadId, entryData);
  }
  
  @override
  Future<Either<Failure, String>> startAutomation(
    BrowserAutomationParams params,
  ) async {
    return await _repository.startAutomation(params);
  }
  
  @override
  Stream<Job> watchJob(String jobId) {
    return _repository.watchJob(jobId);
  }
  
  @override
  Future<Either<Failure, int>> deleteMockLeads() async {
    // Clear all cache
    await _cache.clear();
    
    return await _repository.deleteMockLeads();
  }
  
  @override
  Future<Either<Failure, Map<String, dynamic>>> recalculateConversionScores() async {
    // Clear leads cache
    await _cache.clear();
    
    return await _repository.recalculateConversionScores();
  }
  
  @override
  Future<Either<Failure, void>> deleteLead(String id) async {
    // Invalidate cache
    await _cache.remove('lead_$id');
    await _cache.clear();
    
    return await _repository.deleteLead(id);
  }
  
  @override
  Future<Either<Failure, void>> deleteLeads(List<String> ids) async {
    // Invalidate cache
    for (final id in ids) {
      await _cache.remove('lead_$id');
    }
    await _cache.clear();
    
    return await _repository.deleteLeads(ids);
  }
}