import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../../data/repositories/leads_repository_impl.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/leads_repository.dart';
import '../../domain/usecases/run_scrape_usecase.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

final leadsRemoteDataSourceProvider = Provider<LeadsRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return LeadsRemoteDataSourceImpl(dio: dio);
});

final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  final remoteDataSource = ref.watch(leadsRemoteDataSourceProvider);
  return LeadsRepositoryImpl(remoteDataSource: remoteDataSource);
});

final runScrapeUseCaseProvider = Provider<RunScrapeUseCase>((ref) {
  final repository = ref.watch(leadsRepositoryProvider);
  return RunScrapeUseCase(repository);
});

class JobState {
  final String? jobId;
  final bool isRunning;
  final Job? currentJob;
  final String? error;

  JobState({
    this.jobId,
    this.isRunning = false,
    this.currentJob,
    this.error,
  });

  JobState copyWith({
    String? jobId,
    bool? isRunning,
    Job? currentJob,
    String? error,
  }) {
    return JobState(
      jobId: jobId ?? this.jobId,
      isRunning: isRunning ?? this.isRunning,
      currentJob: currentJob ?? this.currentJob,
      error: error,
    );
  }
}

class JobNotifier extends StateNotifier<JobState> {
  final LeadsRepository repository;
  final Ref ref;

  JobNotifier(this.repository, this.ref) : super(JobState());
  
  void clearJob() {
    state = JobState();
  }

  Future<void> startScrape(RunScrapeParams params) async {
    state = state.copyWith(isRunning: true, error: null);

    final result = await repository.startScrape(params);

    result.fold(
      (failure) {
        state = state.copyWith(
          isRunning: false,
          error: failure.message,
        );
      },
      (jobId) {
        state = state.copyWith(jobId: jobId);
        _watchJob(jobId);
      },
    );
  }

  void _watchJob(String jobId) async {
    await for (final job in repository.watchJob(jobId)) {
      if (!mounted) break;
      
      state = state.copyWith(currentJob: job);

      if (job.status == JobStatus.done) {
        state = state.copyWith(isRunning: false);
        break;
      } else if (job.status == JobStatus.error) {
        state = state.copyWith(
          isRunning: false,
          error: job.message ?? 'Job failed',
        );
        break;
      }
    }
  }
}

final jobProvider = StateNotifierProvider.autoDispose<JobNotifier, JobState>((ref) {
  final repository = ref.watch(leadsRepositoryProvider);
  return JobNotifier(repository, ref);
});