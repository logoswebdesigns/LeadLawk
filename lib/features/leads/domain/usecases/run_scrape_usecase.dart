import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../repositories/leads_repository.dart';

class RunScrapeParams extends Equatable {
  final String industry;
  final String location;
  final int limit;
  final double minRating;
  final int minReviews;
  final int recentDays;

  const RunScrapeParams({
    required this.industry,
    required this.location,
    required this.limit,
    required this.minRating,
    required this.minReviews,
    required this.recentDays,
  });

  @override
  List<Object> get props => [
        industry,
        location,
        limit,
        minRating,
        minReviews,
        recentDays,
      ];
}

class RunScrapeUseCase {
  final LeadsRepository repository;

  RunScrapeUseCase(this.repository);

  Future<Either<Failure, String>> call(RunScrapeParams params) async {
    return await repository.startScrape(params);
  }
}