import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import '../pages/leads_list_page.dart' show leadsProvider;
import 'job_provider.dart' show leadsRepositoryProvider;

final leadDetailProvider = FutureProvider.family<Lead, String>(
  (ref, id) async {
    final repository = ref.watch(leadsRepositoryProvider);
    final result = await repository.getLead(id);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (lead) => lead,
    );
  },
);