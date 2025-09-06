/// Delete Lead Command
/// Pattern: Command Pattern
/// SOLID: Single Responsibility - only deletes lead
library;

import 'package:dartz/dartz.dart';
import '../../../../core/patterns/command.dart';
import '../repositories/leads_repository.dart';

class DeleteLeadCommand extends Command<void> {
  final LeadsRepository repository;
  final String leadId;
  
  DeleteLeadCommand({
    required this.repository,
    required this.leadId,
  });
  
  @override
  String get description => 'Delete lead';
  
  @override
  Future<Either<CommandFailure, void>> execute() async {
    try {
      // Delete the lead
      final result = await repository.deleteLead(leadId);
      
      return result.fold(
        (failure) => Left(CommandFailure(failure.toString())),
        (_) => const Right(null),
      );
    } catch (e, stack) {
      return Left(CommandFailure(
        'Failed to delete lead',
        error: e,
        stackTrace: stack,
      ));
    }
  }
}