/// Command Provider for Lead Actions
/// Pattern: Provider Pattern with Command Pattern
/// SOLID: Dependency Inversion - providers depend on abstractions
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/patterns/command_bus.dart';
import '../../domain/commands/update_lead_command.dart';
import '../../domain/commands/delete_lead_command.dart';
import '../../domain/commands/batch_update_status_command.dart';
import '../../domain/entities/lead.dart';
import 'job_provider.dart';

/// Global command bus instance
final commandBusProvider = Provider<CommandBus>((ref) {
  return CommandBus();
});

/// Execute update lead command
final updateLeadCommandProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  final repository = ref.watch(leadsRepositoryProvider);
  
  return (Lead lead, Map<String, dynamic> updates) async {
    final command = UpdateLeadCommand(
      repository: repository,
      lead: lead,
      updates: updates,
    );
    
    return await commandBus.execute(command);
  };
});

/// Execute delete lead command
final deleteLeadCommandProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  final repository = ref.watch(leadsRepositoryProvider);
  
  return (String leadId) async {
    final command = DeleteLeadCommand(
      repository: repository,
      leadId: leadId,
    );
    
    return await commandBus.execute(command);
  };
});

/// Execute batch status update command
final batchUpdateStatusCommandProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  final repository = ref.watch(leadsRepositoryProvider);
  
  return (List<String> leadIds, LeadStatus newStatus) async {
    final command = BatchUpdateStatusCommand(
      repository: repository,
      leadIds: leadIds,
      newStatus: newStatus,
    );
    
    return await commandBus.execute(command);
  };
});

/// Undo last command
final undoCommandProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  
  return () async {
    return await commandBus.undo();
  };
});

/// Redo last undone command
final redoCommandProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  
  return () async {
    return await commandBus.redo();
  };
});

/// Command history provider
final commandHistoryProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  return commandBus.history;
});

/// Can undo provider
final canUndoProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  return commandBus.canUndo;
});

/// Can redo provider
final canRedoProvider = Provider((ref) {
  final commandBus = ref.watch(commandBusProvider);
  return commandBus.canRedo;
});