import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_navigation_provider.dart';

class LeadNavigationBar extends ConsumerWidget {
  final LeadNavigationContext navigation;

  const LeadNavigationBar({
    super.key,
    required this.navigation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _NavigationButton(
              lead: navigation.previousLead,
              isNext: false,
              hasMore: false,
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
              hasMore: navigation.nextLead != null || navigation.totalCount > navigation.currentIndex,
              onTap: (navigation.nextLead != null || navigation.totalCount > navigation.currentIndex)
                ? () async {
                    final nextId = await ref.read(leadNavigationActionsProvider).navigateToNext(navigation.currentLead.id);
                    if (nextId != null && context.mounted) {
                      _navigateToLead(context, nextId);
                    }
                  }
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
          '${navigation.currentIndex} of ${navigation.totalCount}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
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
  final bool hasMore;
  final VoidCallback? onTap;

  const _NavigationButton({
    required this.lead,
    required this.isNext,
    this.hasMore = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If we have more leads to navigate to (even if not loaded), show button as enabled
    if (lead == null && hasMore && onTap != null) {
      return _buildLoadMoreButton(context);
    }
    if (lead == null) return _buildDisabledButton(context);
    return _buildActiveButton(context);
  }

  Widget _buildDisabledButton(BuildContext context) {
    // If there are more leads to load, show as enabled even without a lead
    if (hasMore && onTap != null) {
      return _buildLoadMoreButton(context);
    }
    
    return Container(
      height: 56,
      alignment: isNext ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          isNext ? Icons.chevron_right : Icons.chevron_left,
          color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
          size: 28,
        ),
      ),
    );
  }
  
  Widget _buildLoadMoreButton(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        alignment: isNext ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.primaryGold.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            isNext ? Icons.chevron_right : Icons.chevron_left,
            color: AppTheme.primaryGold,
            size: 28,
          ),
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
        padding: EdgeInsets.symmetric(horizontal: 8),
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

  Widget _buildArrowIcon(BuildContext) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withValues(alpha: 0.1),
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