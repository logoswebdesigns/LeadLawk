import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'bottom_navigation.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  
  const MainScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    
    // Don't show bottom nav on detail pages or monitor pages
    final hideBottomNav = location.contains('/leads/') && 
                         location != '/leads' ||
                         location.contains('/monitor');

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: child,
      bottomNavigationBar: hideBottomNav 
          ? null 
          : AppBottomNavigationBar(currentPath: location),
    );
  }
}