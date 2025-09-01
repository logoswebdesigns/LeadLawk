import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/leads_list_page.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;

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
    final leadsAsync = ref.watch(leadsProvider);
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    
    if (!isSelectionMode) {
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryGold.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Cancel button
            GestureDetector(
              onTap: () {
                ref.read(isSelectionModeProvider.notifier).state = false;
                ref.read(selectedLeadsProvider.notifier).state = {};
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryGold,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Selected count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${selectedLeads.length} selected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGold,
                ),
              ),
            ),
            const Spacer(),
            // Select all button
            if (leadsAsync.hasValue)
              GestureDetector(
                onTap: () {
                  final allLeadIds = leadsAsync.value!.map((lead) => lead.id).toSet();
                  if (selectedLeads.length == allLeadIds.length) {
                    // Deselect all
                    ref.read(selectedLeadsProvider.notifier).state = {};
                  } else {
                    // Select all
                    ref.read(selectedLeadsProvider.notifier).state = allLeadIds;
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedLeads.length == leadsAsync.value!.length
                            ? CupertinoIcons.checkmark_square
                            : CupertinoIcons.square,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedLeads.length == leadsAsync.value!.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // Delete button
            GestureDetector(
              onTap: selectedLeads.isEmpty || _isDeleting
                  ? null
                  : () => _showDeleteConfirmation(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectedLeads.isEmpty || _isDeleting
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppTheme.errorRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isDeleting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : Icon(
                        CupertinoIcons.trash,
                        size: 18,
                        color: selectedLeads.isEmpty
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppTheme.errorRed,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final selectedLeads = ref.read(selectedLeadsProvider);
    
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('Delete ${selectedLeads.length} Lead${selectedLeads.length > 1 ? 's' : ''}?'),
        content: const Text(
          'This action cannot be undone. All selected leads will be permanently deleted.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteSelectedLeads();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedLeads() async {
    if (!mounted) return;
    
    setState(() {
      _isDeleting = true;
    });
    
    final selectedLeads = ref.read(selectedLeadsProvider);
    final selectedCount = selectedLeads.length;
    final repository = ref.read(leadsRepositoryProvider);
    
    try {
      // Delete all selected leads
      final result = await repository.deleteLeads(selectedLeads.toList());
      
      if (!mounted) return;
      
      result.fold(
        (failure) {
          // Handle error
          print('❌ Failed to delete leads: ${failure.message}');
          if (mounted) {
            setState(() {
              _isDeleting = false;
            });
            
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete leads: ${failure.message}'),
                backgroundColor: AppTheme.errorRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        },
        (_) {
          print('✅ Successfully deleted $selectedCount leads');
          
          // Clear selection and exit selection mode
          ref.read(selectedLeadsProvider.notifier).state = {};
          ref.read(isSelectionModeProvider.notifier).state = false;
          
          // Force refresh the leads list using refresh trigger
          ref.read(refreshTriggerProvider.notifier).state++;
          ref.invalidate(leadsProvider);
          
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
        },
      );
    } catch (e) {
      print('❌ Error during deletion: $e');
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
}