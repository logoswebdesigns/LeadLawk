// Tests for responsive design system.
// Pattern: Visual Regression Testing.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/responsive/responsive_grid.dart';
import 'package:leadloq/core/responsive/responsive_builder.dart';
import 'package:leadloq/core/responsive/adaptive_scaffold.dart';
import 'package:leadloq/core/responsive/platform_adaptive.dart';
import 'package:leadloq/core/theme/design_tokens.dart';

void main() {
  group('Responsive Grid Tests', () {
    testWidgets('grid adapts to mobile breakpoint', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveGrid(
              children: [
                ResponsiveGridItem(
                  mobile: 4,
                  tablet: 4,
                  desktop: 3,
                  child: Container(color: Colors.red),
                ),
                ResponsiveGridItem(
                  mobile: 4,
                  tablet: 4,
                  desktop: 3,
                  child: Container(color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      );
      
      // Set mobile size
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpAndSettle();
      
      expect(find.byType(Container), findsNWidgets(2));
    });
    
    testWidgets('grid adapts to tablet breakpoint', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveGrid(
              children: [
                ResponsiveGridItem(
                  mobile: 4,
                  tablet: 4,
                  desktop: 3,
                  child: Container(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      );
      
      // Set tablet size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpAndSettle();
      
      expect(find.byType(Container), findsOneWidget);
    });
  });
  
  group('Responsive Builder Tests', () {
    testWidgets('shows mobile widget on small screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWidget(
            mobile: const Text('Mobile'),
            tablet: const Text('Tablet'),
            desktop: const Text('Desktop'),
          ),
        ),
      );
      
      // Set mobile size
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpAndSettle();
      
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Tablet'), findsNothing);
      expect(find.text('Desktop'), findsNothing);
    });
    
    testWidgets('shows tablet widget on medium screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWidget(
            mobile: const Text('Mobile'),
            tablet: const Text('Tablet'),
            desktop: const Text('Desktop'),
          ),
        ),
      );
      
      // Set tablet size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpAndSettle();
      
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('Desktop'), findsNothing);
    });
    
    testWidgets('shows desktop widget on large screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWidget(
            mobile: const Text('Mobile'),
            tablet: const Text('Tablet'),
            desktop: const Text('Desktop'),
          ),
        ),
      );
      
      // Set desktop size
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      await tester.pumpAndSettle();
      
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Tablet'), findsNothing);
      expect(find.text('Desktop'), findsOneWidget);
    });
  });
  
  group('Adaptive Scaffold Tests', () {
    testWidgets('shows bottom navigation on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            destinations: [
              AdaptiveNavigationItem(
                icon: Icons.home,
                label: 'Home',
                page: const Text('Home Page'),
              ),
              AdaptiveNavigationItem(
                icon: Icons.search,
                label: 'Search',
                page: const Text('Search Page'),
              ),
            ],
          ),
        ),
      );
      
      // Set mobile size
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpAndSettle();
      
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
    
    testWidgets('shows navigation rail on tablet', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            destinations: [
              AdaptiveNavigationItem(
                icon: Icons.home,
                label: 'Home',
                page: const Text('Home Page'),
              ),
              AdaptiveNavigationItem(
                icon: Icons.search,
                label: 'Search',
                page: const Text('Search Page'),
              ),
            ],
          ),
        ),
      );
      
      // Set tablet size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpAndSettle();
      
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });
  
  group('Platform Adaptive Tests', () {
    testWidgets('shows material button on Android', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveButton(
              label: 'Test Button',
              filled: true,
            ),
          ),
        ),
      );
      
      expect(find.byType(ElevatedButton), findsOneWidget);
      
      debugDefaultTargetPlatformOverride = null;
    });
    
    testWidgets('shows cupertino button on iOS', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveButton(
              label: 'Test Button',
              filled: true,
            ),
          ),
        ),
      );
      
      expect(find.byType(CupertinoButton), findsOneWidget);
      
      debugDefaultTargetPlatformOverride = null;
    });
  });
  
  group('Responsive Visibility Tests', () {
    testWidgets('hides widget on mobile when specified', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveVisibility(
              hiddenOnMobile: true,
              child: Text('Hidden on Mobile'),
            ),
          ),
        ),
      );
      
      // Set mobile size
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpAndSettle();
      
      expect(find.text('Hidden on Mobile'), findsNothing);
    });
    
    testWidgets('shows widget on tablet when not hidden', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveVisibility(
              hiddenOnMobile: true,
              child: Text('Visible on Tablet'),
            ),
          ),
        ),
      );
      
      // Set tablet size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpAndSettle();
      
      expect(find.text('Visible on Tablet'), findsOneWidget);
    });
  });
}