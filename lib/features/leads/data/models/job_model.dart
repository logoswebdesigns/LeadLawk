import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/job.dart';

part 'job_model.g.dart';

@JsonSerializable()
class JobModel {
  final String id;
  final String status;
  final int processed;
  final int total;
  final String? message;
  final String? industry;
  final String? location;
  final String? query;
  final DateTime? timestamp;
  final String? type;
  @JsonKey(name: 'total_combinations')
  final int? totalCombinations;
  @JsonKey(name: 'completed_combinations')
  final int? completedCombinations;
  @JsonKey(name: 'child_jobs')
  final List<String>? childJobs;
  @JsonKey(name: 'parent_id')
  final String? parentId;
  @JsonKey(name: 'leads_found')
  final int? leadsFound;

  JobModel({
    required this.id,
    required this.status,
    required this.processed,
    required this.total,
    this.message,
    this.industry,
    this.location,
    this.query,
    this.timestamp,
    this.type,
    this.totalCombinations,
    this.completedCombinations,
    this.childJobs,
    this.parentId,
    this.leadsFound,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) => _$JobModelFromJson(json);
  Map<String, dynamic> toJson() => _$JobModelToJson(this);

  Job toEntity() {
    return Job(
      id: id,
      status: _parseJobStatus(status),
      processed: processed,
      total: total,
      message: message,
      industry: industry,
      location: location,
      query: query,
      timestamp: timestamp,
      type: type,
      totalCombinations: totalCombinations,
      completedCombinations: completedCombinations,
      childJobs: childJobs,
      parentId: parentId,
      leadsFound: leadsFound,
    );
  }

  factory JobModel.fromEntity(Job job) {
    return JobModel(
      id: job.id,
      status: job.status.toString().split('.').last,
      processed: job.processed,
      total: job.total,
      message: job.message,
      industry: job.industry,
      location: job.location,
      query: job.query,
      timestamp: job.timestamp,
      type: job.type,
      totalCombinations: job.totalCombinations,
      completedCombinations: job.completedCombinations,
      childJobs: job.childJobs,
      parentId: job.parentId,
      leadsFound: job.leadsFound,
    );
  }

  JobStatus _parseJobStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return JobStatus.pending;
      case 'running':
        return JobStatus.running;
      case 'done':
        return JobStatus.done;
      case 'error':
        return JobStatus.error;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.pending;
    }
  }
}