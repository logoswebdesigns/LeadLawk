import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/repositories/repository_factory.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/repositories/cache_manager.dart';
import '../../domain/repositories/leads_repository.dart';
import '../../domain/repositories/job_repository.dart';
import '../../domain/repositories/call_log_repository.dart';
import '../../domain/repositories/lead_timeline_repository.dart';
import '../../data/repositories/leads_repository_impl.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../data/repositories/call_log_repository_impl.dart';
import '../../data/repositories/lead_timeline_repository_impl.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../../data/datasources/job_remote_datasource.dart';
import '../../data/datasources/call_log_remote_datasource.dart';
import '../../data/datasources/lead_timeline_remote_datasource.dart';

/// Dio client provider
final dioProvider = Provider<Dio>((ref) {
  return Dio()
    ..options = BaseOptions(
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      sendTimeout: Duration(seconds: 30),
    );
});

/// Cache manager provider
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager.instance;
});

/// Repository configuration provider
final repositoryConfigProvider = Provider<RepositoryConfig>((ref) {
  return const RepositoryConfig(
    cacheTimeout: Duration(minutes: 5),
    maxRetries: 5,
    initialRetryDelay: Duration(seconds: 1),
    circuitBreakerThreshold: 5,
    circuitBreakerResetTimeout: Duration(seconds: 30),
    enablePersistentCache: true,
    enableNetworkCache: true,
  );
});

// Data source providers
final leadsRemoteDataSourceProvider = Provider<LeadsRemoteDataSource>((ref) {
  return LeadsRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final jobRemoteDataSourceProvider = Provider<JobRemoteDataSource>((ref) {
  return JobRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final callLogRemoteDataSourceProvider = Provider<CallLogRemoteDataSource>((ref) {
  return CallLogRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final timelineRemoteDataSourceProvider = Provider<LeadTimelineRemoteDataSource>((ref) {
  return LeadTimelineRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

// Base repository implementations (before enhancement)
final _baseLeadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  return LeadsRepositoryImpl(
    remoteDataSource: ref.watch(leadsRemoteDataSourceProvider),
  );
});

final _baseJobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepositoryImpl(
    remoteDataSource: ref.watch(jobRemoteDataSourceProvider),
  );
});

final _baseCallLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  return CallLogRepositoryImpl(
    remoteDataSource: ref.watch(callLogRemoteDataSourceProvider),
  );
});

final _baseTimelineRepositoryProvider = Provider<LeadTimelineRepository>((ref) {
  return LeadTimelineRepositoryImpl(
    remoteDataSource: ref.watch(timelineRemoteDataSourceProvider),
  );
});

// Enhanced repository providers (with caching, retry, circuit breaker)
final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  final baseRepository = ref.watch(_baseLeadsRepositoryProvider);
  final config = ref.watch(repositoryConfigProvider);
  
  return RepositoryFactory.createLeadsRepository(
    baseRepository,
    config: config,
  );
});

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final baseRepository = ref.watch(_baseJobRepositoryProvider);
  final config = ref.watch(repositoryConfigProvider);
  
  return RepositoryFactory.createJobRepository(
    baseRepository,
    config: config,
  );
});

final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  final baseRepository = ref.watch(_baseCallLogRepositoryProvider);
  final config = ref.watch(repositoryConfigProvider);
  
  return RepositoryFactory.createCallLogRepository(
    baseRepository,
    config: config,
  );
});

final timelineRepositoryProvider = Provider<LeadTimelineRepository>((ref) {
  final baseRepository = ref.watch(_baseTimelineRepositoryProvider);
  final config = ref.watch(repositoryConfigProvider);
  
  return RepositoryFactory.createLeadTimelineRepository(
    baseRepository,
    config: config,
  );
});

/// Repository health check provider
final repositoryHealthProvider = FutureProvider<Map<String, bool>>((ref) async {
  final leads = ref.watch(leadsRepositoryProvider);
  final jobs = ref.watch(jobRepositoryProvider);
  final callLogs = ref.watch(callLogRepositoryProvider);
  final timeline = ref.watch(timelineRepositoryProvider);

  return {
    'leads': (await leads.getLeads()).isRight(),
    'jobs': (await jobs.count()).isRight(),
    'callLogs': (await callLogs.count()).isRight(),
    'timeline': (await timeline.count()).isRight(),
  };
});

/// Initialize all repositories and cache
final repositoryInitProvider = FutureProvider<void>((ref) async {
  // Initialize cache manager
  await ref.watch(cacheManagerProvider).init();
  
  // Warm up cache with frequently accessed data if needed
  // This could be implemented based on specific needs
});