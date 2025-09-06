// Repository adapter to bridge different repository interfaces.
// Pattern: Adapter Pattern - adapt between interfaces.
// Single Responsibility: Adapt repository interfaces.

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../../domain/repositories/leads_repository.dart';
import '../../domain/usecases/browser_automation_usecase.dart';

/// Simple repository interface for internal use
abstract class SimpleLeadsRepository {
  Future<List<Lead>> getAllLeads();
  Future<Lead> getLeadById(String id);
  Future<List<Lead>> getLeadsByStatus(LeadStatus status);
  Future<Lead> createLead(Lead lead);
  Future<Lead> updateLead(Lead lead);
  Future<void> deleteLead(String id);
  Future<List<Lead>> searchLeads(String query);
  Future<List<Lead>> getLeadsWithPagination({
    required int page,
    required int pageSize,
  });
}

/// Adapter to convert SimpleLeadsRepository to LeadsRepository
class RepositoryAdapter implements LeadsRepository {
  final SimpleLeadsRepository _simpleRepo;
  
  RepositoryAdapter(this._simpleRepo);
  
  @override
  Future<Either<Failure, List<Lead>>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  }) async {
    try {
      List<Lead> leads = await _simpleRepo.getAllLeads();
      
      // Apply filters
      if (status != null) {
        final leadStatus = LeadStatus.values.firstWhere(
          (s) => s.toString().split('.').last == status,
          orElse: () => LeadStatus.new_,
        );
        leads = leads.where((l) => l.status == leadStatus).toList();
      }
      
      if (search != null && search.isNotEmpty) {
        leads = await _simpleRepo.searchLeads(search);
      }
      
      if (candidatesOnly == true) {
        leads = leads.where((l) => l.isCandidate).toList();
      }
      
      return Right(leads);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Lead>> getLead(String id) async {
    try {
      final lead = await _simpleRepo.getLeadById(id);
      return Right(lead);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Lead>> updateLead(Lead lead) async {
    try {
      final updated = await _simpleRepo.updateLead(lead);
      return Right(updated);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Lead>> updateTimelineEntry(
    String leadId,
    LeadTimelineEntry entry,
  ) async {
    try {
      // Update lead with new timeline entry
      final lead = await _simpleRepo.getLeadById(leadId);
      // Note: Timeline updates would be handled at data source level
      return Right(lead);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> addTimelineEntry(
    String leadId,
    Map<String, dynamic> entryData,
  ) async {
    try {
      // Timeline entries would be handled at data source level
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, String>> startAutomation(
    BrowserAutomationParams params,
  ) async {
    // This would be handled by a separate automation service
    return Left(ServerFailure('Automation not implemented in adapter'));
  }
  
  @override
  Stream<Job> watchJob(String jobId) {
    // This would be handled by a separate job service
    return Stream.empty();
  }
  
  @override
  Future<Either<Failure, int>> deleteMockLeads() async {
    try {
      // Delete all leads with mock flag
      // Would need a mock flag in Lead entity
      final mockLeads = <Lead>[];
      
      for (final lead in mockLeads) {
        await _simpleRepo.deleteLead(lead.id);
      }
      
      return Right(mockLeads.length);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Map<String, dynamic>>> recalculateConversionScores() async {
    try {
      // This would be handled at data source level
      return Right({'updated': 0});
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteLead(String id) async {
    try {
      await _simpleRepo.deleteLead(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteLeads(List<String> ids) async {
    try {
      for (final id in ids) {
        await _simpleRepo.deleteLead(id);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}