import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LeadInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const LeadInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null;
    final iconColor = _getIconColor(icon);
    
    return Semantics(
      button: isClickable,
      label: isClickable ? 'Open $text' : text,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  icon, 
                  size: 20, 
                  color: iconColor,
                  semanticLabel: null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      decoration: isClickable ? TextDecoration.underline : null,
                      color: isClickable 
                          ? AppTheme.primaryGold 
                          : Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isClickable)
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: AppTheme.primaryGold.withValues(alpha: 0.7),
                    semanticLabel: null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getIconColor(IconData icon) {
    if (icon == Icons.phone) return AppTheme.successGreen;
    if (icon == Icons.language) return AppTheme.primaryBlue;
    if (icon == Icons.link) return AppTheme.primaryBlue;
    if (icon == Icons.search) return AppTheme.primaryGold;
    if (icon == Icons.location_on) return AppTheme.accentCyan;
    if (icon == Icons.business) return AppTheme.primaryIndigo;
    if (icon == Icons.star) return AppTheme.warningOrange;
    if (icon == Icons.schedule) return AppTheme.accentPurple;
    if (icon == Icons.info_outline) return AppTheme.mediumGray;
    if (icon == Icons.source) return AppTheme.accentCyan;
    return AppTheme.mediumGray;
  }
}