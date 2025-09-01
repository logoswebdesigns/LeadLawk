import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LeadFlagRow extends StatelessWidget {
  final String label;
  final bool value;
  final String? description;

  const LeadFlagRow({
    Key? key,
    required this.label,
    required this.value,
    this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${value ? "Yes" : "No"}${description != null ? " - $description" : ""}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: value ? AppTheme.successGreen : AppTheme.errorRed,
              semanticLabel: null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                    ),
                  ),
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value ? 'Yes' : 'No',
              style: TextStyle(
                color: value ? AppTheme.successGreen : AppTheme.errorRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}