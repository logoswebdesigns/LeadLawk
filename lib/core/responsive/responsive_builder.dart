// Responsive builder for adaptive layouts.
// Pattern: Builder Pattern - builds different layouts per breakpoint.
// Single Responsibility: Breakpoint-based layout building.

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Builder that provides different widgets based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)? mobile;
  final Widget Function(BuildContext context, BoxConstraints constraints)? tablet;
  final Widget Function(BuildContext context, BoxConstraints constraints)? desktop;
  final Widget Function(BuildContext context, BoxConstraints constraints)? wide;
  
  const ResponsiveBuilder({
    super.key,
    this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isWide(context) && wide != null) {
          return wide!(context, constraints);
        }
        if (AppBreakpoints.isDesktop(context) && desktop != null) {
          return desktop!(context, constraints);
        }
        if (AppBreakpoints.isTablet(context) && tablet != null) {
          return tablet!(context, constraints);
        }
        if (mobile != null) {
          return mobile!(context, constraints);
        }
        
        // Fallback to largest available layout
        final fallback = desktop ?? tablet ?? mobile;
        if (fallback != null) {
          return fallback(context, constraints);
        }
        return SizedBox.shrink();
      },
    );
  }
}

/// Simpler responsive widget selector
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? wide;
  
  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });
  
  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isWide(context) && wide != null) {
      return wide!;
    }
    if (AppBreakpoints.isDesktop(context) && desktop != null) {
      return desktop!;
    }
    if (AppBreakpoints.isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// Responsive value selector
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;
  final T? wide;
  
  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });
  
  T get(BuildContext context) {
    if (AppBreakpoints.isWide(context) && wide != null) {
      return wide!;
    }
    if (AppBreakpoints.isDesktop(context) && desktop != null) {
      return desktop!;
    }
    if (AppBreakpoints.isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// Responsive padding
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets mobile;
  final EdgeInsets? tablet;
  final EdgeInsets? desktop;
  final EdgeInsets? wide;
  
  const ResponsivePadding({
    super.key,
    required this.child,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });
  
  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveValue(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      wide: wide,
    ).get(context);
    
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

/// Responsive container with max width constraints
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final Alignment alignment;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });
  
  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? _getMaxWidth(context);
    
    return Container(
      alignment: alignment,
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: child,
      ),
    );
  }
  
  double _getMaxWidth(BuildContext context) {
    if (AppBreakpoints.isWide(context)) return 1440;
    if (AppBreakpoints.isDesktop(context)) return 1200;
    if (AppBreakpoints.isTablet(context)) return 768;
    return double.infinity;
  }
}

/// Hide widget on certain breakpoints
class ResponsiveVisibility extends StatelessWidget {
  final Widget child;
  final bool hiddenOnMobile;
  final bool hiddenOnTablet;
  final bool hiddenOnDesktop;
  final bool hiddenOnWide;
  final Widget replacement;
  
  const ResponsiveVisibility({
    super.key,
    required this.child,
    this.hiddenOnMobile = false,
    this.hiddenOnTablet = false,
    this.hiddenOnDesktop = false,
    this.hiddenOnWide = false,
    this.replacement = const SizedBox.shrink(),
  });
  
  @override
  Widget build(BuildContext context) {
    bool shouldHide = false;
    
    if (AppBreakpoints.isMobile(context) && hiddenOnMobile) {
      shouldHide = true;
    } else if (AppBreakpoints.isTablet(context) && hiddenOnTablet) {
      shouldHide = true;
    } else if (AppBreakpoints.isDesktop(context) && !AppBreakpoints.isWide(context) && hiddenOnDesktop) {
      shouldHide = true;
    } else if (AppBreakpoints.isWide(context) && hiddenOnWide) {
      shouldHide = true;
    }
    
    return shouldHide ? replacement : child;
  }
}