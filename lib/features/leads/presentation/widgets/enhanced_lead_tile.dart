import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/pagespeed_websocket_provider.dart';
import '../pages/leads_list_page.dart';

class EnhancedLeadTile extends ConsumerStatefulWidget {
  final Lead lead;
  
  const EnhancedLeadTile({super.key, required this.lead});
  
  @override
  ConsumerState<EnhancedLeadTile> createState() => _EnhancedLeadTileState();
}

class _EnhancedLeadTileState extends ConsumerState<EnhancedLeadTile> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _goldenEffectAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _goldenEffectAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final wsNotifier = ref.read(pageSpeedWebSocketProvider.notifier);
    final isPendingDeletion = wsNotifier.isLeadPendingDeletion(widget.lead.id);
    final isNewlyAdded = wsNotifier.isNewLead(widget.lead.id);
    final selectedLeads = ref.watch(selectedLeadsProvider);
    final isSelected = selectedLeads.contains(widget.lead.id);
    
    if (isNewlyAdded && !_animationController.isAnimating) {
      _animationController.forward();
    }
    
    return AnimatedBuilder(
      animation: _goldenEffectAnimation,
      builder: (context, child) {
        final goldenEffect = isNewlyAdded ? _goldenEffectAnimation.value : 0.0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isPendingDeletion 
                ? Colors.red.withValues(alpha: 0.1)
                : AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPendingDeletion
                  ? Colors.red.withValues(alpha: 0.5)
                  : Color.lerp(
                      isSelected 
                          ? AppTheme.primaryGold.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.05),
                      AppTheme.primaryGold.withValues(alpha: 0.5),
                      goldenEffect,
                    )!,
              width: isPendingDeletion ? 1.5 : 1.0,
            ),
            boxShadow: goldenEffect > 0
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGold.withValues(alpha: 0.2 * goldenEffect),
                      blurRadius: 16 * goldenEffect,
                      spreadRadius: 2 * goldenEffect,
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go('/leads/${widget.lead.id}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Checkbox
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          final current = ref.read(selectedLeadsProvider);
                          final updated = Set<String>.from(current);
                          if (value == true) {
                            updated.add(widget.lead.id);
                          } else {
                            updated.remove(widget.lead.id);
                          }
                          ref.read(selectedLeadsProvider.notifier).state = updated;
                        },
                        activeColor: AppTheme.primaryGold,
                        checkColor: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lead.businessName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.lead.location,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildMetricsRow(),
                        ],
                      ),
                    ),
                    // Status badge
                    _buildStatusBadge(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildMetricsRow() {
    return Row(
      children: [
        // Website indicator
        _buildMetric(
          widget.lead.hasWebsite 
              ? CupertinoIcons.globe 
              : CupertinoIcons.xmark_circle,
          widget.lead.hasWebsite ? 'Site' : 'No Site',
          widget.lead.hasWebsite 
              ? Colors.green.withValues(alpha: 0.8)
              : Colors.red.withValues(alpha: 0.8),
        ),
        // PageSpeed score
        if (widget.lead.pagespeedMobileScore != null) ...[
          const SizedBox(width: 12),
          _buildPageSpeedMetric(widget.lead.pagespeedMobileScore!),
        ],
        // Rating
        if (widget.lead.rating != null) ...[
          const SizedBox(width: 12),
          _buildMetric(
            Icons.star,
            widget.lead.rating!.toStringAsFixed(1),
            AppTheme.warningOrange,
          ),
        ],
        // Review count
        if (widget.lead.reviewCount != null) ...[
          const SizedBox(width: 12),
          _buildMetric(
            CupertinoIcons.chat_bubble_2,
            widget.lead.reviewCount.toString(),
            Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ],
    );
  }
  
  Widget _buildMetric(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPageSpeedMetric(int score) {
    final color = score >= 90 
        ? const Color(0xFF0CCE6B)  // Green
        : score >= 50 
            ? const Color(0xFFFFA400)  // Orange
            : const Color(0xFFFF4E42); // Red
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PageSpeed icon (lighthouse-style)
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Icon(
            CupertinoIcons.speedometer,
            size: 10,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          score.toString(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (widget.lead.status) {
      case LeadStatus.new_: return const Color(0xFF007AFF);
      case LeadStatus.viewed: return const Color(0xFF5856D6);
      case LeadStatus.called: return const Color(0xFFFF9500);
      case LeadStatus.interested: return const Color(0xFF34C759);
      case LeadStatus.converted: return const Color(0xFF30D158);
      case LeadStatus.didNotConvert: return const Color(0xFFFF3B30);
      case LeadStatus.callbackScheduled: return const Color(0xFF5AC8FA);
      case LeadStatus.doNotCall: return const Color(0xFF8E8E93);
    }
  }
  
  String _getStatusLabel() {
    switch (widget.lead.status) {
      case LeadStatus.new_: return 'NEW';
      case LeadStatus.viewed: return 'VIEWED';
      case LeadStatus.called: return 'CALLED';
      case LeadStatus.interested: return 'INTERESTED';
      case LeadStatus.converted: return 'WON';
      case LeadStatus.didNotConvert: return 'LOST';
      case LeadStatus.callbackScheduled: return 'CALLBACK';
      case LeadStatus.doNotCall: return 'DNC';
    }
  }
}