import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/job.dart';
import '../entities/lead.dart';
import '../usecases/run_scrape_usecase.dart';

abstract class LeadsRepository {
  Future<Either<Failure, List<Lead>>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  });
  
  Future<Either<Failure, Lead>> getLead(String id);
  
  Future<Either<Failure, Lead>> updateLead(Lead lead);
  
  Future<Either<Failure, String>> startScrape(RunScrapeParams params);
  
  Stream<Job> watchJob(String jobId);
}