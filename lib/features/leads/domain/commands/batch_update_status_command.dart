/// Batch Update Status Command
/// Pattern: Command Pattern with Composite
/// SOLID: Open/Closed - extend without modification
library;

import 'package:dartz/dartz.dart';
import '../../../../core/patterns/command.dart';
import '../entities/lead.dart';
import '../repositories/leads_repository.dart';

class BatchUpdateStatusCommand extends UndoableCommand<List<Lead>> {
  final LeadsRepository repository;
  final List<String> leadIds;
  final LeadStatus newStatus;
  final Map<String, LeadStatus> _originalStatuses = {};
  
  BatchUpdateStatusCommand({
    required this.repository,
    required this.leadIds,
    required this.newStatus,
  });
  
  @override
  String get description => 'Update ${leadIds.length} leads to ${newStatus.name}';
  
  @override
  Future<Either<CommandFailure, List<Lead>>> execute() async {
    try {
      final updatedLeads = <Lead>[];
      
      // Store original statuses and update each lead
      for (final leadId in leadIds) {
        final leadResult = await repository.getLead(leadId);
        
        final lead = leadResult.fold(
          (_) => null,
          (lead) => lead,
        );
        
        if (lead == null) continue;
        
        // Store original status
        _originalStatuses[leadId] = lead.status;
        
        // Update status
        final updatedLead = lead.copyWith(status: newStatus);
        final updateResult = await repository.updateLead(updatedLead);
        
        updateResult.fold(
          (_) => {},
          (lead) => updatedLeads.add(lead),
        );
      }
      
      if (updatedLeads.isEmpty) {
        return Left(CommandFailure('No leads were updated'));
      }
      
      return Right(updatedLeads);
    } catch (e, stack) {
      return Left(CommandFailure(
        'Failed to batch update status',
        error: e,
        stackTrace: stack,
      ));
    }
  }
  
  @override
  Future<Either<CommandFailure, void>> undo() async {
    if (_originalStatuses.isEmpty) {
      return Left(CommandFailure('No original statuses to restore'));
    }
    
    try {
      // Restore original statuses
      for (final entry in _originalStatuses.entries) {
        final leadResult = await repository.getLead(entry.key);
        
        final lead = leadResult.fold(
          (_) => null,
          (lead) => lead,
        );
        
        if (lead != null) {
          final restoredLead = lead.copyWith(status: entry.value);
          await repository.updateLead(restoredLead);
        }
      }
      
      return const Right(null);
    } catch (e, stack) {
      return Left(CommandFailure(
        'Failed to undo batch status update',
        error: e,
        stackTrace: stack,
      ));
    }
  }
}