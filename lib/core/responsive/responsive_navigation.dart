// Responsive navigation system.
// Pattern: Navigation Pattern - adaptive navigation.
// Single Responsibility: Screen-size aware navigation.

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'responsive_builder.dart';

/// Responsive app bar that adapts to screen size
class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double? elevation;
  final Color? backgroundColor;
  
  const ResponsiveAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation,
    this.backgroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    
    return AppBar(
      title: title,
      leading: leading,
      actions: _buildActions(context),
      centerTitle: isMobile ? true : centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor,
    );
  }
  
  List<Widget>? _buildActions(BuildContext context) {
    if (actions == null || actions!.isEmpty) return null;
    
    final isMobile = AppBreakpoints.isMobile(context);
    
    if (isMobile && actions!.length > 3) {
      // Show overflow menu on mobile for many actions
      return [
        PopupMenuButton<int>(
          icon: Icon(Icons.more_vert),
          onSelected: (index) {
            // Handle action selection
          },
          itemBuilder: (context) {
            return actions!.asMap().entries.map((entry) {
              return PopupMenuItem<int>(
                value: entry.key,
                child: entry.value,
              );
            }).toList();
          },
        ),
      ];
    }
    
    return actions;
  }
  
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

/// Responsive breadcrumb navigation
class ResponsiveBreadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final ValueChanged<int>? onTap;
  
  const ResponsiveBreadcrumbs({
    super.key,
    required this.items,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    
    if (isMobile && items.length > 2) {
      // Show condensed version on mobile
      return _buildCondensedBreadcrumbs(context);
    }
    
    return _buildFullBreadcrumbs(context);
  }
  
  Widget _buildCondensedBreadcrumbs(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // First item
        _buildBreadcrumbButton(context, items.first, 0),
        
        // Ellipsis
        if (items.length > 2) ...[
          Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const Text('...'),
        ],
        
        // Last item
        if (items.length > 1) ...[
          Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
          _buildBreadcrumbButton(context, items.last, items.length - 1),
        ],
      ],
    );
  }
  
  Widget _buildFullBreadcrumbs(BuildContext context) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    
    for (int i = 0; i < items.length; i++) {
      widgets.add(_buildBreadcrumbButton(context, items[i], i));
      
      if (i < items.length - 1) {
        widgets.add(Icon(
          Icons.chevron_right,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ));
      }
    }
    
    return Row(children: widgets);
  }
  
  Widget _buildBreadcrumbButton(BuildContext context, BreadcrumbItem item, int index) {
    final theme = Theme.of(context);
    final isLast = index == items.length - 1;
    
    return TextButton(
      onPressed: isLast ? null : () => onTap?.call(index),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        item.label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isLast 
            ? theme.colorScheme.onSurface 
            : theme.colorScheme.primary,
          fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Breadcrumb item
class BreadcrumbItem {
  final String label;
  final IconData? icon;
  final Object? data;
  
  const BreadcrumbItem({
    required this.label,
    this.icon,
    this.data,
  });
}

/// Responsive tab bar
class ResponsiveTabBar extends StatelessWidget {
  final List<Tab> tabs;
  final TabController? controller;
  final bool isScrollable;
  final ValueChanged<int>? onTap;
  
  const ResponsiveTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    
    return TabBar(
      tabs: tabs,
      controller: controller,
      isScrollable: isMobile ? true : isScrollable,
      onTap: onTap,
      tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
    );
  }
}

/// Responsive drawer that becomes permanent on desktop
class ResponsiveDrawer extends StatelessWidget {
  final Widget drawer;
  final Widget body;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  
  const ResponsiveDrawer({
    super.key,
    required this.drawer,
    required this.body,
    this.scaffoldKey,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: (context, constraints) => Scaffold(
        key: scaffoldKey,
        drawer: drawer,
        body: body,
      ),
      tablet: (context, constraints) => Scaffold(
        key: scaffoldKey,
        drawer: drawer,
        body: body,
      ),
      desktop: (context, constraints) => Scaffold(
        key: scaffoldKey,
        body: Row(
          children: [
            SizedBox(
        width: 280,
              child: drawer,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}