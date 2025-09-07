import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/blacklist_provider.dart';

/// Badge widget to indicate if a business is blacklisted
/// SOLID: Single Responsibility - only displays blacklist status
class BlacklistBadge extends ConsumerWidget {
  final String businessName;
  final double iconSize;
  final double fontSize;
  
  const BlacklistBadge({
    super.key,
    required this.businessName,
    this.iconSize = 12,
    this.fontSize = 10,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlacklisted = ref.watch(isBusinessBlacklistedProvider(businessName));
    
    if (!isBlacklisted) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: iconSize,
            color: Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            'BLACKLISTED',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}