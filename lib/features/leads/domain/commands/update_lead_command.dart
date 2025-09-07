// Update Lead Command
// Pattern: Command Pattern
// SOLID: Single Responsibility - only updates lead
library;

import 'package:dartz/dartz.dart';
import '../../../../core/patterns/command.dart';
import '../entities/lead.dart';
import '../repositories/leads_repository.dart';

class UpdateLeadCommand extends UndoableCommand<Lead> {
  final LeadsRepository repository;
  final Lead lead;
  final Map<String, dynamic> updates;
  Lead? _originalLead;
  
  UpdateLeadCommand({
    required this.repository,
    required this.lead,
    required this.updates,
  });
  
  @override
  String get description => 'Update ${lead.businessName}';
  
  @override
  Future<Either<CommandFailure, Lead>> execute() async {
    try {
      // Store original for undo
      final originalResult = await repository.getLead(lead.id);
      _originalLead = originalResult.fold(
        (_) => null,
        (lead) => lead,
      );
      
      // Apply updates
      final updatedLead = _applyUpdates(lead, updates);
      
      // Extract blacklist parameters if present
      final addToBlacklist = updates['addToBlacklist'] as bool?;
      final blacklistReason = updates['blacklistReason'] as String?;
      
      // Save to repository with blacklist parameters
      final result = await repository.updateLead(
        updatedLead,
        addToBlacklist: addToBlacklist,
        blacklistReason: blacklistReason,
      );
      
      return result.fold(
        (failure) => Left(CommandFailure(failure.toString())),
        (lead) => Right(lead),
      );
    } catch (e, stack) {
      return Left(CommandFailure(
        'Failed to update lead',
        error: e,
        stackTrace: stack,
      ));
    }
  }
  
  @override
  Future<Either<CommandFailure, void>> undo() async {
    if (_originalLead == null) {
      return Left(CommandFailure('No original state to restore'));
    }
    
    try {
      final result = await repository.updateLead(_originalLead!);
      return result.fold(
        (failure) => Left(CommandFailure(failure.toString())),
        (_) => const Right(null),
      );
    } catch (e, stack) {
      return Left(CommandFailure(
        'Failed to undo lead update',
        error: e,
        stackTrace: stack,
      ));
    }
  }
  
  Lead _applyUpdates(Lead lead, Map<String, dynamic> updates) {
    return lead.copyWith(
      businessName: updates['businessName'] ?? lead.businessName,
      phone: updates['phone'] ?? lead.phone,
      websiteUrl: updates['websiteUrl'] ?? lead.websiteUrl,
      notes: updates['notes'] ?? lead.notes,
      status: updates['status'] ?? lead.status,
      rating: updates['rating'] ?? lead.rating,
      reviewCount: updates['reviewCount'] ?? lead.reviewCount,
      industry: updates['industry'] ?? lead.industry,
      location: updates['location'] ?? lead.location,
      followUpDate: updates['followUpDate'] ?? lead.followUpDate,
    );
  }
}