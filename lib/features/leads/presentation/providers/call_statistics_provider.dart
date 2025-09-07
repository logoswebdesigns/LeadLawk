import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/get_call_statistics.dart';
import '../../domain/repositories/leads_repository.dart';
import 'repository_providers.dart';

final getCallStatisticsProvider = Provider<GetCallStatistics>((ref) {
  final repository = ref.watch(leadsRepositoryProvider);
  return GetCallStatistics(repository);
});

final callStatisticsProvider = FutureProvider<Map<DateTime, int>>((ref) async {
  final getCallStatistics = ref.watch(getCallStatisticsProvider);
  final result = await getCallStatistics.execute();
  
  return result.fold(
    (failure) => throw Exception(failure.message),
    (stats) => stats,
  );
});