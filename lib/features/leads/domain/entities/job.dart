import 'package:equatable/equatable.dart';

enum JobStatus { running, done, error }

class Job extends Equatable {
  final String id;
  final JobStatus status;
  final int processed;
  final int total;
  final String? message;
  final String? industry;
  final String? location;
  final String? query;

  const Job({
    required this.id,
    required this.status,
    required this.processed,
    required this.total,
    this.message,
    this.industry,
    this.location,
    this.query,
  });

  @override
  List<Object?> get props => [id, status, processed, total, message, industry, location, query];
}