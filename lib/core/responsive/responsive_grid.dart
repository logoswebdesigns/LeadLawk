// Responsive grid system for layouts.
// Pattern: Responsive Grid Pattern - 12-column grid system.
// Single Responsibility: Grid-based responsive layouts.

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Responsive grid container
class ResponsiveGrid extends StatelessWidget {
  final List<ResponsiveGridItem> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsets? padding;
  final int maxColumns;
  
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
    this.padding,
    this.maxColumns = 12,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _getColumns(context);
        final columnWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        
        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: children.map((item) {
              final itemColumns = item.getColumns(context);
              final itemWidth = (columnWidth * itemColumns) + (spacing * (itemColumns - 1));
              
              return SizedBox(
        width: itemWidth,
                child: item.child,
              );
            }).toList(),
          ),
        );
      },
    );
  }
  
  int _getColumns(BuildContext context) {
    if (AppBreakpoints.isMobile(context)) return 4;
    if (AppBreakpoints.isTablet(context)) return 8;
    return maxColumns;
  }
}

/// Individual grid item with responsive column spans
class ResponsiveGridItem {
  final Widget child;
  final int mobile;
  final int? tablet;
  final int? desktop;
  final int? wide;
  
  const ResponsiveGridItem({
    required this.child,
    this.mobile = 4,
    this.tablet,
    this.desktop,
    this.wide,
  });
  
  int getColumns(BuildContext context) {
    if (AppBreakpoints.isWide(context) && wide != null) return wide!;
    if (AppBreakpoints.isDesktop(context) && desktop != null) return desktop!;
    if (AppBreakpoints.isTablet(context) && tablet != null) return tablet!;
    return mobile;
  }
}

/// Responsive row with flexible children
class ResponsiveRow extends StatelessWidget {
  final List<ResponsiveRowChild> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  
  const ResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = AppSpacing.md,
  });
  
  @override
  Widget build(BuildContext context) {
    final shouldWrap = AppBreakpoints.isMobile(context);
    
    if (shouldWrap) {
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        alignment: WrapAlignment.start,
        children: children.map((child) => child.child).toList(),
      );
    }
    
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _buildChildren(),
    );
  }
  
  List<Widget> _buildChildren() {
    final widgets = <Widget>[];
    
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      
      if (child.flex != null) {
        widgets.add(Flexible(
          flex: child.flex!,
          fit: child.fit,
          child: child.child,
        ));
      } else {
        widgets.add(child.child);
      }
      
      if (i < children.length - 1) {
        widgets.add(SizedBox(
        width: spacing));
      }
    }
    
    return widgets;
  }
}

/// Child for ResponsiveRow
class ResponsiveRowChild {
  final Widget child;
  final int? flex;
  final FlexFit fit;
  
  const ResponsiveRowChild({
    required this.child,
    this.flex,
    this.fit = FlexFit.loose,
  });
}

/// Responsive column with automatic stacking on mobile
class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final bool reverseOnMobile;
  
  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = AppSpacing.md,
    this.reverseOnMobile = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final effectiveChildren = (isMobile && reverseOnMobile) 
      ? children.reversed.toList() 
      : children;
    
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _buildChildren(effectiveChildren),
    );
  }
  
  List<Widget> _buildChildren(List<Widget> children) {
    final widgets = <Widget>[];
    
    for (int i = 0; i < children.length; i++) {
      widgets.add(children[i]);
      
      if (i < children.length - 1) {
        widgets.add(SizedBox(
        height: spacing));
      }
    }
    
    return widgets;
  }
}