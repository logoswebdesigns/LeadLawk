// Organized provider module for leads feature.
// Pattern: Module Pattern - groups related providers.
// Single Responsibility: Provider organization and dependency management.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/leads_repository.dart';
import '../../data/repositories/leads_repository_impl.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/events/domain_events.dart';
import '../../../../core/events/event_provider_integration.dart';

/// Lead feature provider module
class LeadProviderModule {
  LeadProviderModule._();
  
  // Data sources
  static final remoteDataSourceProvider = Provider<LeadsRemoteDataSource>((ref) {
    final dio = ref.watch(dioProvider);
    return LeadsRemoteDataSourceImpl(dio: dio);
  });
  
  // Repositories  
  static final repositoryProvider = Provider<LeadsRepository>((ref) {
    final remoteDataSource = ref.watch(remoteDataSourceProvider);
    return LeadsRepositoryImpl(remoteDataSource: remoteDataSource);
  });
  
  // State providers with families for parameterized access
  static final leadProvider = FutureProvider.family<Lead?, String>((ref, leadId) async {
    final repository = ref.watch(repositoryProvider);
    final result = await repository.getLead(leadId);
    
    return result.fold(
      (failure) => null,
      (lead) {
        // Fire event when lead is loaded
        ref.read(eventBusProvider).fire(PageViewedEvent(
          pageName: 'LeadDetail',
          parameters: {'leadId': leadId},
        ));
        return lead;
      },
    );
  });
  
  static final leadsProvider = FutureProvider.family<List<Lead>, LeadFilters>((ref, filters) async {
    final repository = ref.watch(repositoryProvider);
    final result = await repository.getLeads(
      status: filters.status?.toString(),
      search: filters.search,
    );
    
    return result.fold(
      (failure) => [],
      (leads) => leads,
    );
  });
  
  // Computed providers
  static final activeLeadsCountProvider = Provider<AsyncValue<int>>((ref) {
    final leads = ref.watch(leadsProvider(const LeadFilters()));
    return leads.whenData((list) => 
      list.where((l) => l.status != LeadStatus.converted && 
                       l.status != LeadStatus.doNotCall).length
    );
  });
  
  static final conversionRateProvider = Provider<AsyncValue<double>>((ref) {
    final leads = ref.watch(leadsProvider(const LeadFilters()));
    return leads.whenData((list) {
      if (list.isEmpty) return 0.0;
      final converted = list.where((l) => l.status == LeadStatus.converted).length;
      return converted / list.length;
    });
  });
}

/// Filter parameters for leads
class LeadFilters {
  final LeadStatus? status;
  final String? search;
  final String? sortBy;
  final bool sortAscending;
  
  const LeadFilters({
    this.status,
    this.search,
    this.sortBy,
    this.sortAscending = true,
  });
  
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is LeadFilters &&
    runtimeType == other.runtimeType &&
    status == other.status &&
    search == other.search &&
    sortBy == other.sortBy &&
    sortAscending == other.sortAscending;
  
  @override
  int get hashCode =>
    status.hashCode ^
    search.hashCode ^
    sortBy.hashCode ^
    sortAscending.hashCode;
}

/// Provider shortcuts for easy access
final leadRepositoryProvider = LeadProviderModule.repositoryProvider;
final leadProvider = LeadProviderModule.leadProvider;
final leadsProvider = LeadProviderModule.leadsProvider;
final activeLeadsCountProvider = LeadProviderModule.activeLeadsCountProvider;
final conversionRateProvider = LeadProviderModule.conversionRateProvider;