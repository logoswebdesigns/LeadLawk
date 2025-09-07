import 'package:equatable/equatable.dart';

enum JobStatus { pending, running, done, error, cancelled }

class Job extends Equatable {
  final String id;
  final JobStatus status;
  final int processed;
  final int total;
  final String? message;
  final String? industry;
  final String? location;
  final String? query;
  final DateTime? timestamp;
  final String? type; // 'parent' or 'child' for parallel jobs
  final int? totalCombinations; // For parent jobs
  final int? completedCombinations; // For parent jobs
  final List<String>? childJobs; // For parent jobs
  final String? parentId; // For child jobs
  final int? leadsFound; // Number of leads found in this job
  final int? totalRequested; // Total number of leads requested for this job
  final int? elapsedSeconds; // Server-calculated elapsed time in seconds

  const Job({
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
    this.totalRequested,
    this.elapsedSeconds,
  });

  @override
  List<Object?> get props => [
    id, status, processed, total, message, industry, location, query, 
    timestamp, type, totalCombinations, completedCombinations, 
    childJobs, parentId, leadsFound, totalRequested, elapsedSeconds
  ];
  
  // Helper methods
  bool get isParentJob => type == 'parent';
  bool get isChildJob => type == 'child';
  
  double get progress {
    if (isParentJob && totalCombinations != null && totalCombinations! > 0) {
      return (completedCombinations ?? 0) / totalCombinations!;
    }
    if (total > 0) {
      return processed / total;
    }
    return 0.0;
  }
  
  String get progressText {
    if (isParentJob) {
      return '${completedCombinations ?? 0}/${totalCombinations ?? 0} searches';
    }
    return '$processed/$total businesses';
  }
}