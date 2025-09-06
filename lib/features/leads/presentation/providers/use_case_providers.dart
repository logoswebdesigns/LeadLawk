// Use Case Providers for Business Logic
// Pattern: Provider Pattern with Use Case Pattern
// SOLID: Single Responsibility - each provider wraps one use case
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/validate_lead_data.dart';
import '../../domain/usecases/calculate_lead_score.dart';
import '../../domain/usecases/schedule_callback.dart';
import '../../domain/usecases/manage_lead_pipeline.dart';
import '../../domain/usecases/generate_sales_pitch.dart';
import '../../domain/entities/lead.dart';

/// Lead data validation use case
final validateLeadDataProvider = Provider<ValidateLeadData>((ref) {
  return ValidateLeadData();
});

/// Lead score calculation use case
final calculateLeadScoreProvider = Provider<CalculateLeadScore>((ref) {
  return CalculateLeadScore();
});

/// Callback scheduling use case
final scheduleCallbackProvider = Provider<ScheduleCallback>((ref) {
  return ScheduleCallback();
});

/// Lead pipeline management use case
final manageLeadPipelineProvider = Provider<ManageLeadPipeline>((ref) {
  return ManageLeadPipeline();
});

/// Sales pitch generation use case
final generateSalesPitchProvider = Provider<GenerateSalesPitch>((ref) {
  return GenerateSalesPitch();
});

/// Calculate score for a specific lead
final leadScoreProvider = Provider.family<int?, Lead>((ref, lead) {
  final calculator = ref.watch(calculateLeadScoreProvider);
  final result = calculator.calculate(lead);
  
  return result.fold(
    (_) => null,
    (score) => score,
  );
});

/// Get quality tier for a lead
final leadQualityTierProvider = Provider.family<String, Lead>((ref, lead) {
  final calculator = ref.watch(calculateLeadScoreProvider);
  final score = ref.watch(leadScoreProvider(lead));
  
  if (score == null) return 'Unknown';
  return calculator.getQualityTier(score);
});

/// Get recommended action for a lead
final leadRecommendedActionProvider = Provider.family<String, Lead>((ref, lead) {
  final calculator = ref.watch(calculateLeadScoreProvider);
  final score = ref.watch(leadScoreProvider(lead));
  
  if (score == null) return 'Unable to determine action';
  return calculator.getRecommendedAction(lead, score);
});

/// Validate phone number
final validatePhoneProvider = Provider((ref) {
  final validator = ref.watch(validateLeadDataProvider);
  
  return (String phone) {
    return validator.validatePhone(phone);
  };
});

/// Validate email
final validateEmailProvider = Provider((ref) {
  final validator = ref.watch(validateLeadDataProvider);
  
  return (String email) {
    return validator.validateEmail(email);
  };
});

/// Validate website URL
final validateWebsiteProvider = Provider((ref) {
  final validator = ref.watch(validateLeadDataProvider);
  
  return (String url) {
    return validator.validateWebsite(url);
  };
});

/// Get available pipeline transitions for a status
final availableTransitionsProvider = Provider.family<List<LeadStatus>, LeadStatus>((ref, status) {
  final pipeline = ref.watch(manageLeadPipelineProvider);
  return pipeline.getAvailableTransitions(status);
});

/// Check if transition is valid
final canTransitionProvider = Provider((ref) {
  final pipeline = ref.watch(manageLeadPipelineProvider);
  
  return (LeadStatus from, LeadStatus to) {
    return pipeline.canTransition(from, to);
  };
});

/// Get pipeline progress for a status
final pipelineProgressProvider = Provider.family<int, LeadStatus>((ref, status) {
  final pipeline = ref.watch(manageLeadPipelineProvider);
  return pipeline.calculateProgress(status);
});

/// Generate pitch for a lead
final generatePitchProvider = Provider((ref) {
  final generator = ref.watch(generateSalesPitchProvider);
  
  return (Lead lead, {String template = 'website'}) {
    return generator.generate(lead, template: template);
  };
});