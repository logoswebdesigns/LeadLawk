import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/leads_repository.dart';

class GetCallStatistics {
  final LeadsRepository repository;

  GetCallStatistics(this.repository);

  Future<Either<Failure, Map<DateTime, int>>> execute() async {
    return await repository.getCallStatistics();
  }
}