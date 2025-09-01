import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import '../pages/leads_list_page.dart' show leadsProvider;

class LeadNavigationContext {
  final Lead currentLead;
  final Lead? previousLead;
  final Lead? nextLead;
  final int currentIndex;
  final int totalCount;

  const LeadNavigationContext({
    required this.currentLead,
    this.previousLead,
    this.nextLead,
    required this.currentIndex,
    required this.totalCount,
  });
}

final leadNavigationProvider = FutureProvider.family<LeadNavigationContext, String>(
  (ref, currentLeadId) async {
    final leads = await ref.watch(leadsProvider.future);
    
    final currentIndex = leads.indexWhere((lead) => lead.id == currentLeadId);
    if (currentIndex == -1) {
      throw Exception('Lead not found in current list');
    }
    
    return LeadNavigationContext(
      currentLead: leads[currentIndex],
      previousLead: currentIndex > 0 ? leads[currentIndex - 1] : null,
      nextLead: currentIndex < leads.length - 1 ? leads[currentIndex + 1] : null,
      currentIndex: currentIndex,
      totalCount: leads.length,
    );
  },
);