import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/job.dart';
import '../entities/lead.dart';
import '../entities/lead_timeline_entry.dart';
import '../usecases/browser_automation_usecase.dart';

abstract class LeadsRepository {
  Future<Either<Failure, List<Lead>>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  });
  
  Future<Either<Failure, Lead>> getLead(String id);
  
  Future<Either<Failure, Lead>> updateLead(Lead lead);

  Future<Either<Failure, Lead>> updateTimelineEntry(String leadId, LeadTimelineEntry entry);
  
  Future<Either<Failure, void>> addTimelineEntry(String leadId, Map<String, dynamic> entryData);
  
  Future<Either<Failure, String>> startAutomation(BrowserAutomationParams params);
  
  Stream<Job> watchJob(String jobId);
  
  Future<Either<Failure, int>> deleteMockLeads();
  
  Future<Either<Failure, Map<String, dynamic>>> recalculateConversionScores();
  
  Future<Either<Failure, void>> deleteLead(String id);
  
  Future<Either<Failure, void>> deleteLeads(List<String> ids);
}