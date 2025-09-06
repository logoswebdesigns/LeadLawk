import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/pagespeed_websocket_provider.dart';
import '../providers/filter_providers.dart';

class LeadTile extends ConsumerStatefulWidget {
  final Lead lead;
  
  const LeadTile({super.key, required this.lead});
  
  @override
  ConsumerState<LeadTile> createState() => _LeadTileState();
}

class _LeadTileState extends ConsumerState<LeadTile> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _goldenEffectAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 3),
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
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Get the absolute difference to handle timezone issues
    final absDifference = difference.abs();
    
    if (absDifference.inDays == 0) {
      if (absDifference.inHours == 0) {
        if (absDifference.inMinutes < 2) {
          return 'Just now';
        }
        return '${absDifference.inMinutes}m ago';
      }
      return '${absDifference.inHours}h ago';
    } else if (absDifference.inDays == 1) {
      return 'Yesterday';
    } else if (absDifference.inDays < 7) {
      return '${absDifference.inDays}d ago';
    } else if (absDifference.inDays < 30) {
      final weeks = (absDifference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final wsNotifier = ref.read(pageSpeedWebSocketProvider.notifier);
    final isPendingDeletion = wsNotifier.isLeadPendingDeletion(widget.lead.id);
    final isNewlyAdded = wsNotifier.isNewLead(widget.lead.id);
    final selectedLeads = ref.watch(selectedLeadsProvider);
    final isSelected = selectedLeads.contains(widget.lead.id);
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    
    if (isNewlyAdded && !_animationController.isAnimating) {
      _animationController.forward();
    }
    
    return AnimatedBuilder(
      animation: _goldenEffectAnimation,
      builder: (context, child) {
        final goldenEffect = isNewlyAdded ? _goldenEffectAnimation.value : 0.0;
        
        return Container(
          margin: EdgeInsets.only(bottom: 8),
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
              onTap: () {
                if (isSelectionMode) {
                  // Toggle selection
                  final current = ref.read(selectedLeadsProvider);
                  final updated = Set<String>.from(current);
                  if (isSelected) {
                    updated.remove(widget.lead.id);
                  } else {
                    updated.add(widget.lead.id);
                  }
                  ref.read(selectedLeadsProvider.notifier).state = updated;
                  
                  // Enter selection mode if not already
                  if (!isSelectionMode) {
                    ref.read(isSelectionModeProvider.notifier).state = true;
                  }
                } else {
                  // Navigate to detail
                  context.go('/leads/${widget.lead.id}');
                }
              },
              onLongPress: () {
                // Enter selection mode on long press
                if (!isSelectionMode) {
                  ref.read(isSelectionModeProvider.notifier).state = true;
                  ref.read(selectedLeadsProvider.notifier).state = {widget.lead.id};
                }
              },
              child: Padding(padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Checkbox (only show in selection mode)
                    if (isSelectionMode) ...[
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
                    ],
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
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.lead.location.isNotEmpty 
                                      ? '${widget.lead.location} • ${_formatDate(widget.lead.createdAt)}'
                                      : _formatDate(widget.lead.createdAt),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
        // PageSpeed score or error indicator
        if (widget.lead.hasWebsite) ...[
          const SizedBox(width: 12),
          if (widget.lead.pagespeedMobileScore != null)
            _buildPageSpeedMetric(widget.lead.pagespeedMobileScore!)
          else if (widget.lead.pagespeedTestError != null)
            _buildPageSpeedError()
          else
            _buildPageSpeedPending(),
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
  
  Widget _buildPageSpeedError() {
    return Tooltip(
      message: 'PageSpeed test failed: ${widget.lead.pagespeedTestError ?? "Unknown error"}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withValues(alpha: 0.3),
              border: Border.all(
                color: Colors.orange,
                width: 1,
              ),
            ),
            child: Icon(
              CupertinoIcons.exclamationmark,
              size: 10,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            '!',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPageSpeedPending() {
    return Tooltip(
      message: 'PageSpeed test not run yet',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Icon(
              CupertinoIcons.minus,
              size: 10,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            '-',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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