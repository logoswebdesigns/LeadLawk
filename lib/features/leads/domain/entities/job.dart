import 'package:equatable/equatable.dart';

enum JobStatus { running, done, error }

class Job extends Equatable {
  final String id;
  final JobStatus status;
  final int processed;
  final int total;
  final String? message;

  const Job({
    required this.id,
    required this.status,
    required this.processed,
    required this.total,
    this.message,
  });

  @override
  List<Object?> get props => [id, status, processed, total, message];
}