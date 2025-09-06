// Reusable card component with elevation and styles.
// Pattern: Decorator Pattern - different card decorations.
// Single Responsibility: Card container rendering.

import 'package:flutter/material.dart';
import '../base/base_component.dart';

enum CardVariant { elevated, outlined, filled, ghost }

class AppCard extends BaseComponent {
  final Widget child;
  final CardVariant variant;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  
  const AppCard({
    super.key,
    required this.child,
    this.variant = CardVariant.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius,
    super.semanticLabel,
    super.enabled = true,
  });
  
  @override
  Widget buildComponent(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = padding ?? EdgeInsets.all(16);
    final effectiveMargin = margin ?? EdgeInsets.zero;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12);
    
    Widget cardContent = Padding(
      padding: effectivePadding,
      child: child,
    );
    
    if (width != null || height != null) {
      cardContent = SizedBox(
        width: width,
        height: height,
        child: cardContent,
      );
    }
    
    Widget card = _buildCardVariant(
      context,
      theme,
      cardContent,
      effectiveBorderRadius,
    );
    
    if (onTap != null && enabled) {
      card = InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        child: card,
      );
    }
    
    return Padding(
      padding: effectiveMargin,
      child: card,
    );
  }
  
  Widget _buildCardVariant(
    BuildContext context,
    ThemeData theme,
    Widget content,
    BorderRadius borderRadius,
  ) {
    final bgColor = backgroundColor ?? theme.colorScheme.surface;
    
    switch (variant) {
      case CardVariant.elevated:
        return Material(
          elevation: 2,
          borderRadius: borderRadius,
          color: bgColor,
          shadowColor: theme.shadowColor.withValues(alpha: 0.1),
          child: content,
        );
        
      case CardVariant.outlined:
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: content,
        );
        
      case CardVariant.filled:
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: borderRadius,
          ),
          child: content,
        );
        
      case CardVariant.ghost:
        return content;
    }
  }
}