import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/server_status_provider.dart' show dioProvider;

class LeadActionsService {
  final WidgetRef ref;
  final BuildContext context;

  LeadActionsService({required this.ref, required this.context});

  Future<void> deleteLead(Lead lead) async {
    final confirmed = await _showDeleteConfirmation(lead);

    if (confirmed == true && context.mounted) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('http://localhost:8000/leads/${lead.id}');
        
        ref.invalidate(leadDetailProvider);
        
        if (context.mounted) {
          _showSuccessMessage('${lead.businessName} deleted');
          context.go('/leads');
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorMessage('Failed to delete: $e');
        }
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(Lead lead) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lead?'),
        content: Text(
          'Are you sure you want to delete "${lead.businessName}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}