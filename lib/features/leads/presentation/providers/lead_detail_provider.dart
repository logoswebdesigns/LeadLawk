import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import 'job_provider.dart' show leadsRemoteDataSourceProvider;

final leadDetailProvider = FutureProvider.family<Lead, String>(
  (ref, id) async {
    final dataSource = ref.watch(leadsRemoteDataSourceProvider);
    final leadModel = await dataSource.getLead(id);
    return leadModel.toEntity();
  },
);