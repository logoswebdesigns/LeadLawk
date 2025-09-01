import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';

class EnhancedLeadCard extends ConsumerWidget {
  final Lead lead;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool?> onSelectionChanged;
  final VoidCallback? onQuickCall;
  final VoidCallback? onQuickDNC;

  const EnhancedLeadCard({
    super.key,
    required this.lead,
    required this.isSelected,
    required this.onTap,
    required this.onSelectionChanged,
    this.onQuickCall,
    this.onQuickDNC,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew = lead.status == LeadStatus.new_;
    final hasScreenshot = lead.screenshotPath != null;
    final hasPageSpeed = lead.pagespeedMobileScore != null || lead.pagespeedDesktopScore != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? AppTheme.primaryGold.withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            children: [
              // Main content row
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection checkbox
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: onSelectionChanged,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        activeColor: AppTheme.primaryGold,
                        checkColor: Colors.black,
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryGold : AppTheme.mediumGray.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Screenshot thumbnail (high priority visual)
                    if (hasScreenshot) ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: 'http://localhost:8000/screenshots/${lead.screenshotPath}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppTheme.darkGray,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppTheme.darkGray,
                              child: Icon(
                                Icons.image_not_supported,
                                color: AppTheme.mediumGray,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    
                    // Business information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Business name with badges
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lead.businessName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Status badges
                              if (isNew) _buildNewBadge(),
                              if (lead.isCandidate) _buildCandidateBadge(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Key metrics row
                          Row(
                            children: [
                              // PageSpeed score (high priority)
                              if (hasPageSpeed) ...[
                                _buildPageSpeedIndicator(lead),
                                const SizedBox(width: 12),
                              ],
                              
                              // Website status
                              _buildWebsiteIndicator(lead.hasWebsite),
                              const SizedBox(width: 12),
                              
                              // Rating
                              if (lead.rating != null && lead.rating! > 0) ...[
                                _buildRatingIndicator(lead.rating!, lead.reviewCount),
                                const SizedBox(width: 12),
                              ],
                              
                              // Phone
                              if (lead.phone != 'No phone') ...[
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: AppTheme.successGreen.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    lead.phone,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.lightGray,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          
                          // Location and industry
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: AppTheme.mediumGray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lead.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGray,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.business,
                                size: 12,
                                color: AppTheme.mediumGray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lead.industry,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Quick actions column
                    Column(
                      children: [
                        // Status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(lead.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusLabel(lead.status),
                            style: TextStyle(
                              color: _getStatusColor(lead.status),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Quick action buttons
                        Row(
                          children: [
                            if (lead.status != LeadStatus.doNotCall && onQuickCall != null)
                              _buildQuickActionButton(
                                icon: Icons.phone,
                                color: AppTheme.successGreen,
                                onTap: onQuickCall!,
                              ),
                            const SizedBox(width: 4),
                            if (lead.status != LeadStatus.doNotCall && onQuickDNC != null)
                              _buildQuickActionButton(
                                icon: Icons.block,
                                color: AppTheme.errorRed,
                                onTap: onQuickDNC!,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Timeline indicator (if has recent activity)
              if (_hasRecentActivity(lead))
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGold.withOpacity(0.8),
                        AppTheme.primaryGold.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGold.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCandidateBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.accentCyan.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            size: 10,
            color: AppTheme.accentCyan,
          ),
          const SizedBox(width: 2),
          Text(
            'CANDIDATE',
            style: TextStyle(
              color: AppTheme.accentCyan,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSpeedIndicator(Lead lead) {
    final score = lead.pagespeedMobileScore ?? lead.pagespeedDesktopScore ?? 0;
    final color = score >= 90 ? AppTheme.successGreen
        : score >= 50 ? AppTheme.warningOrange
        : AppTheme.errorRed;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteIndicator(bool hasWebsite) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasWebsite ? Icons.language : Icons.language_outlined,
          size: 14,
          color: hasWebsite ? AppTheme.primaryBlue : AppTheme.mediumGray,
        ),
        const SizedBox(width: 2),
        Text(
          hasWebsite ? 'Website' : 'No Site',
          style: TextStyle(
            fontSize: 11,
            color: hasWebsite ? AppTheme.primaryBlue : AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingIndicator(double rating, int? reviewCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: 14,
          color: AppTheme.warningOrange,
        ),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.warningOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (reviewCount != null) ...[
          Text(
            ' ($reviewCount)',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }

  bool _hasRecentActivity(Lead lead) {
    // Check if there's been activity in the last 24 hours
    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(hours: 24));
    return lead.updatedAt.isAfter(dayAgo);
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.primaryGold;
      case LeadStatus.viewed:
        return AppTheme.primaryBlue;
      case LeadStatus.called:
        return AppTheme.primaryIndigo;
      case LeadStatus.interested:
        return AppTheme.successGreen;
      case LeadStatus.converted:
        return AppTheme.accentCyan;
      case LeadStatus.doNotCall:
        return AppTheme.errorRed;
      case LeadStatus.callbackScheduled:
        return AppTheme.warningOrange;
      case LeadStatus.didNotConvert:
        return Colors.grey;
    }
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
      case LeadStatus.viewed:
        return 'VIEWED';
      case LeadStatus.called:
        return 'CALLED';
      case LeadStatus.interested:
        return 'INTERESTED';
      case LeadStatus.converted:
        return 'CONVERTED';
      case LeadStatus.doNotCall:
        return 'DNC';
      case LeadStatus.callbackScheduled:
        return 'CALLBACK';
      case LeadStatus.didNotConvert:
        return 'NO CONVERT';
    }
  }
}