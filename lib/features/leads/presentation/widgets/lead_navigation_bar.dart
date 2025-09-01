import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_navigation_provider.dart';

class LeadNavigationBar extends StatelessWidget {
  final LeadNavigationContext navigation;

  const LeadNavigationBar({
    Key? key,
    required this.navigation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _NavigationButton(
              lead: navigation.previousLead,
              isNext: false,
              onTap: navigation.previousLead != null 
                ? () => _navigateToLead(context, navigation.previousLead!.id)
                : null,
            ),
          ),
          Expanded(
            flex: 2,
            child: _CurrentLeadInfo(navigation: navigation),
          ),
          Expanded(
            child: _NavigationButton(
              lead: navigation.nextLead,
              isNext: true,
              onTap: navigation.nextLead != null 
                ? () => _navigateToLead(context, navigation.nextLead!.id)
                : null,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLead(BuildContext context, String leadId) {
    context.go('/leads/$leadId');
  }
}

class _CurrentLeadInfo extends StatelessWidget {
  final LeadNavigationContext navigation;

  const _CurrentLeadInfo({required this.navigation});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          navigation.currentLead.businessName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${navigation.currentIndex + 1} of ${navigation.totalCount}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final Lead? lead;
  final bool isNext;
  final VoidCallback? onTap;

  const _NavigationButton({
    required this.lead,
    required this.isNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (lead == null) return _buildDisabledButton(context);
    return _buildActiveButton(context);
  }

  Widget _buildDisabledButton(BuildContext context) {
    return Container(
      height: 56,
      alignment: isNext ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).disabledColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          isNext ? Icons.chevron_right : Icons.chevron_left,
          color: Theme.of(context).disabledColor.withOpacity(0.3),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildActiveButton(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: isNext ? [
            Expanded(child: _buildLeadInfo(context)),
            const SizedBox(width: 8),
            _buildArrowIcon(context),
          ] : [
            _buildArrowIcon(context),
            const SizedBox(width: 8),
            Expanded(child: _buildLeadInfo(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadInfo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isNext ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          isNext ? 'Next' : 'Previous',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.accentPurple,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          lead!.businessName,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: isNext ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildArrowIcon(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(
        isNext ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
        size: 18,
        color: AppTheme.accentPurple,
      ),
    );
  }
}