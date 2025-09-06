import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/paginated_leads_provider.dart';
import '../providers/job_provider.dart' show leadsRemoteDataSourceProvider;
import '../../../../core/utils/debug_logger.dart';
import '../providers/filter_providers.dart';
import '../providers/auto_refresh_provider.dart';

class SelectionActionBar extends ConsumerStatefulWidget {
  const SelectionActionBar({super.key});

  @override
  ConsumerState<SelectionActionBar> createState() => _SelectionActionBarState();
}

class _SelectionActionBarState extends ConsumerState<SelectionActionBar> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final selectedLeads = ref.watch(selectedLeadsProvider);
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final paginatedState = ref.watch(filteredPaginatedLeadsProvider);
    final hasSelection = selectedLeads.isNotEmpty;
    
    // Calculate selected leads data
    // final selectedData = paginatedState.leads.where((lead) => selectedLeads.contains(lead.id)).toList();
    
    if (!isSelectionMode) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Exit selection mode button
          IconButton(
            onPressed: () {
              ref.read(selectedLeadsProvider.notifier).state = {};
              ref.read(isSelectionModeProvider.notifier).state = false;
            },
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            tooltip: 'Exit selection mode',
          ),
          
          const SizedBox(width: 8),
          
          // Selection count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasSelection 
                ? AppTheme.primaryGold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              hasSelection 
                ? '${selectedLeads.length} selected'
                : 'Select items',
              style: TextStyle(
                color: hasSelection 
                  ? AppTheme.primaryGold
                  : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Select All button
          TextButton.icon(
            onPressed: () {
              final allLeadIds = paginatedState.leads.map((lead) => lead.id).toSet();
              ref.read(selectedLeadsProvider.notifier).state = allLeadIds;
            },
            icon: Icon(
              selectedLeads.length == paginatedState.leads.length 
                ? Icons.check_box
                : Icons.check_box_outline_blank, 
              size: 18
            ),
            label: Text(
              selectedLeads.length == paginatedState.leads.length 
                ? 'All Selected'
                : 'Select All'
            ),
            style: TextButton.styleFrom(
              foregroundColor: selectedLeads.length == paginatedState.leads.length
                ? AppTheme.primaryGold
                : Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
          
          // Clear Selection button (only show if items selected)
          if (hasSelection)
            TextButton.icon(
              onPressed: () {
                ref.read(selectedLeadsProvider.notifier).state = {};
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          
          const Spacer(),
          
          // Action buttons (only show if items are selected)
          if (hasSelection && !_isDeleting) ...[
            // Status update button
            PopupMenuButton<String>(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 16, color: AppTheme.primaryBlue),
                    SizedBox(width: 4),
                    Text(
                      'Status',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'new', child: Text('New')),
                const PopupMenuItem(value: 'viewed', child: Text('Viewed')),
                const PopupMenuItem(value: 'called', child: Text('Called')),
                const PopupMenuItem(value: 'interested', child: Text('Interested')),
                const PopupMenuItem(value: 'converted', child: Text('Converted')),
                const PopupMenuItem(value: 'did_not_convert', child: Text('Did Not Convert')),
                const PopupMenuItem(value: 'callback_scheduled', child: Text('Callback Scheduled')),
                const PopupMenuItem(value: 'do_not_call', child: Text('Do Not Call')),
              ],
              onSelected: (status) => _updateSelectedStatus(status),
            ),
            
            const SizedBox(width: 8),
            
            // Delete button
            GestureDetector(
              onTap: _showDeleteConfirmation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16, color: AppTheme.errorRed),
                    SizedBox(width: 4),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Deleting indicator
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.errorRed),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Deleting...',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _showDeleteConfirmation() {
    final selectedCount = ref.read(selectedLeadsProvider).length;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Leads'),
        content: Text('Are you sure you want to delete $selectedCount lead${selectedCount > 1 ? 's' : ''}? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSelected();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteSelected() async {
    setState(() {
      _isDeleting = true;
    });
    
    final selectedLeads = ref.read(selectedLeadsProvider);
    final selectedCount = selectedLeads.length;
    final dataSource = ref.read(leadsRemoteDataSourceProvider);
    
    try {
      // Delete all selected leads
      await dataSource.deleteLeads(selectedLeads.toList());
      
      if (!mounted) return;
      
      DebugLogger.log('✅ Successfully deleted $selectedCount leads');
      
      // Clear selection and exit selection mode
      ref.read(selectedLeadsProvider.notifier).state = {};
      ref.read(isSelectionModeProvider.notifier).state = false;
      
      // Force refresh the leads list
      ref.read(refreshTriggerProvider.notifier).state++;
      ref.read(paginatedLeadsProvider.notifier).refreshLeads();
      
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $selectedCount lead${selectedCount > 1 ? 's' : ''}'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      DebugLogger.error('❌ Error during deletion: $e');
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An error occurred while deleting leads'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
  
  Future<void> _updateSelectedStatus(String status) async {
    // TODO: Implement batch status update
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status update coming soon'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}