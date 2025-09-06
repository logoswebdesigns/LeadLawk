import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../data/datasources/parallel_search_datasource.dart';

final parallelSearchDataSourceProvider = Provider<ParallelSearchDataSource>((ref) {
  final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  ));
  
  return ParallelSearchDataSource(dio);
});

final parallelSearchProvider = StateNotifierProvider<ParallelSearchNotifier, ParallelSearchState>((ref) {
  return ParallelSearchNotifier(ref.watch(parallelSearchDataSourceProvider));
});

class ParallelSearchState {
  final bool isLoading;
  final String? parentJobId;
  final String? error;
  final Map<String, dynamic>? jobStatus;
  
  ParallelSearchState({
    this.isLoading = false,
    this.parentJobId,
    this.error,
    this.jobStatus,
  });
  
  ParallelSearchState copyWith({
    bool? isLoading,
    String? parentJobId,
    String? error,
    Map<String, dynamic>? jobStatus,
  }) {
    return ParallelSearchState(
      isLoading: isLoading ?? this.isLoading,
      parentJobId: parentJobId ?? this.parentJobId,
      error: error,
      jobStatus: jobStatus ?? this.jobStatus,
    );
  }
}

class ParallelSearchNotifier extends StateNotifier<ParallelSearchState> {
  final ParallelSearchDataSource _dataSource;
  
  ParallelSearchNotifier(this._dataSource) : super(ParallelSearchState());
  
  Future<void> startParallelSearch({
    required List<Map<String, String>> searches,
    required int limit,
    required bool requiresNoWebsite,
    required int recentReviewMonths,
    bool enablePagespeed = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Extract unique industries and locations
      final industries = searches.map((s) => s['industry']!).toSet().toList();
      final locations = searches.map((s) => s['location']!).toSet().toList();
      
      final result = await _dataSource.startParallelSearch(
        industries: industries,
        locations: locations,
        limit: limit,
        requiresWebsite: !requiresNoWebsite,
        recentReviewMonths: recentReviewMonths,
        enablePagespeed: enablePagespeed,
      );
      
      state = state.copyWith(
        isLoading: false,
        parentJobId: result['parent_job_id'],
        jobStatus: result,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> checkJobStatus() async {
    if (state.parentJobId == null) return;
    
    try {
      final status = await _dataSource.getParallelJobStatus(state.parentJobId!);
      state = state.copyWith(jobStatus: status);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> cancelJob() async {
    if (state.parentJobId == null) return;
    
    try {
      await _dataSource.cancelParallelJob(state.parentJobId!);
      state = state.copyWith(parentJobId: null, jobStatus: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}