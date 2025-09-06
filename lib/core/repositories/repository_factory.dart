import '../../features/leads/domain/entities/lead.dart';
import '../../features/leads/domain/entities/job.dart';
import '../../features/leads/domain/entities/call_log.dart';
import '../../features/leads/domain/entities/lead_timeline_entry.dart';
import '../../features/leads/domain/repositories/leads_repository.dart';
import '../../features/leads/domain/repositories/job_repository.dart';
import '../../features/leads/domain/repositories/call_log_repository.dart';
import '../../features/leads/domain/repositories/lead_timeline_repository.dart';
import 'base_repository.dart';
import 'cache_decorator.dart';
import 'retry_decorator.dart';
import 'circuit_breaker_decorator.dart';
import 'repository_wrappers.dart';
import 'repository_wrappers_extended.dart';

/// Factory for creating repositories with appropriate decorators
class RepositoryFactory {
  static const RepositoryConfig _defaultConfig = RepositoryConfig();

  /// Create enhanced LeadsRepository with all decorators
  static LeadsRepository createLeadsRepository(
    LeadsRepository baseRepository, {
    RepositoryConfig? config,
  }) {
    final conf = config ?? _defaultConfig;
    
    BaseRepository<Lead> enhanced = _wrapWithBaseRepository(baseRepository);

    if (conf.enableNetworkCache || conf.enablePersistentCache) {
      enhanced = CacheDecorator<Lead>(
        repository: enhanced,
        cachePrefix: 'leads',
        defaultTtl: conf.cacheTimeout,
      );
    }

    enhanced = RetryDecorator<Lead>(
      repository: enhanced,
      maxRetries: conf.maxRetries,
      initialDelay: conf.initialRetryDelay,
    );

    enhanced = CircuitBreakerDecorator<Lead>(
      repository: enhanced,
      serviceName: 'LeadsService',
      failureThreshold: conf.circuitBreakerThreshold,
      timeout: conf.circuitBreakerResetTimeout,
    );

    return _unwrapToLeadsRepository(enhanced, baseRepository);
  }

  /// Create enhanced JobRepository with all decorators
  static JobRepository createJobRepository(
    JobRepository baseRepository, {
    RepositoryConfig? config,
  }) {
    final conf = config ?? _defaultConfig;
    
    BaseRepository<Job> enhanced = _wrapWithJobBaseRepository(baseRepository);

    if (conf.enableNetworkCache || conf.enablePersistentCache) {
      enhanced = CacheDecorator<Job>(
        repository: enhanced,
        cachePrefix: 'jobs',
        defaultTtl: conf.cacheTimeout,
      );
    }

    enhanced = RetryDecorator<Job>(
      repository: enhanced,
      maxRetries: conf.maxRetries,
      initialDelay: conf.initialRetryDelay,
    );

    enhanced = CircuitBreakerDecorator<Job>(
      repository: enhanced,
      serviceName: 'JobService',
      failureThreshold: conf.circuitBreakerThreshold,
      timeout: conf.circuitBreakerResetTimeout,
    );

    return _unwrapToJobRepository(enhanced, baseRepository);
  }

  /// Create enhanced CallLogRepository with all decorators
  static CallLogRepository createCallLogRepository(
    CallLogRepository baseRepository, {
    RepositoryConfig? config,
  }) {
    final conf = config ?? _defaultConfig;
    
    BaseRepository<CallLog> enhanced = _wrapWithCallLogBaseRepository(baseRepository);

    if (conf.enableNetworkCache || conf.enablePersistentCache) {
      enhanced = CacheDecorator<CallLog>(
        repository: enhanced,
        cachePrefix: 'call_logs',
        defaultTtl: conf.cacheTimeout,
      );
    }

    enhanced = RetryDecorator<CallLog>(
      repository: enhanced,
      maxRetries: conf.maxRetries,
      initialDelay: conf.initialRetryDelay,
    );

    enhanced = CircuitBreakerDecorator<CallLog>(
      repository: enhanced,
      serviceName: 'CallLogService',
      failureThreshold: conf.circuitBreakerThreshold,
      timeout: conf.circuitBreakerResetTimeout,
    );

    return _unwrapToCallLogRepository(enhanced, baseRepository);
  }

  /// Create enhanced LeadTimelineRepository with all decorators
  static LeadTimelineRepository createLeadTimelineRepository(
    LeadTimelineRepository baseRepository, {
    RepositoryConfig? config,
  }) {
    final conf = config ?? _defaultConfig;
    
    BaseRepository<LeadTimelineEntry> enhanced = _wrapWithTimelineBaseRepository(baseRepository);

    if (conf.enableNetworkCache || conf.enablePersistentCache) {
      enhanced = CacheDecorator<LeadTimelineEntry>(
        repository: enhanced,
        cachePrefix: 'timeline',
        defaultTtl: conf.cacheTimeout,
      );
    }

    enhanced = RetryDecorator<LeadTimelineEntry>(
      repository: enhanced,
      maxRetries: conf.maxRetries,
      initialDelay: conf.initialRetryDelay,
    );

    enhanced = CircuitBreakerDecorator<LeadTimelineEntry>(
      repository: enhanced,
      serviceName: 'TimelineService',
      failureThreshold: conf.circuitBreakerThreshold,
      timeout: conf.circuitBreakerResetTimeout,
    );

    return _unwrapToTimelineRepository(enhanced, baseRepository);
  }

  // Private wrapper methods to adapt specific repositories to BaseRepository
  static BaseRepository<Lead> _wrapWithBaseRepository(LeadsRepository repo) {
    return LeadsRepositoryWrapper(repo);
  }

  static BaseRepository<Job> _wrapWithJobBaseRepository(JobRepository repo) {
    return JobRepositoryWrapper(repo);
  }

  static BaseRepository<CallLog> _wrapWithCallLogBaseRepository(CallLogRepository repo) {
    return CallLogRepositoryWrapper(repo);
  }

  static BaseRepository<LeadTimelineEntry> _wrapWithTimelineBaseRepository(LeadTimelineRepository repo) {
    return TimelineRepositoryWrapper(repo);
  }

  // Private unwrapper methods to restore specific repository interfaces
  static LeadsRepository _unwrapToLeadsRepository(
    BaseRepository<Lead> enhanced, 
    LeadsRepository original,
  ) {
    return EnhancedLeadsRepository(enhanced, original);
  }

  static JobRepository _unwrapToJobRepository(
    BaseRepository<Job> enhanced, 
    JobRepository original,
  ) {
    return EnhancedJobRepository(enhanced, original);
  }

  static CallLogRepository _unwrapToCallLogRepository(
    BaseRepository<CallLog> enhanced, 
    CallLogRepository original,
  ) {
    return EnhancedCallLogRepository(enhanced, original);
  }

  static LeadTimelineRepository _unwrapToTimelineRepository(
    BaseRepository<LeadTimelineEntry> enhanced, 
    LeadTimelineRepository original,
  ) {
    return EnhancedTimelineRepository(enhanced, original);
  }
}