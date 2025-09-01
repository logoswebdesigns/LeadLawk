import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/presentation/providers/automation_form_provider.dart';
import 'package:leadloq/features/leads/presentation/providers/job_provider.dart';
import 'package:leadloq/features/leads/presentation/pages/lead_search_page.dart';
import 'package:leadloq/features/leads/data/repositories/leads_repository_impl.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

class MockLeadsRemoteDataSource extends Mock implements LeadsRemoteDataSource {}

void main() {
  group('LeadSearchPage Widget Tests', () {
    late SharedPreferences prefs;
    late MockLeadsRemoteDataSource mockDataSource;
    late LeadsRepositoryImpl repository;
    
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockDataSource = MockLeadsRemoteDataSource();
      repository = LeadsRepositoryImpl(remoteDataSource: mockDataSource);
    });

    testWidgets('Form displays and loads correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
            jobProvider.overrideWith(
              (ref) => JobNotifier(repository, ref),
            ),
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: LeadSearchPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Verify the page loaded
      expect(find.byType(LeadSearchPage), findsOneWidget);
      
      // Check for key UI elements - they may be in tabs or scrollable
      expect(find.byType(TextField), findsWidgets); // Location field
      expect(find.byType(FilterChip), findsWidgets); // Industry chips
    });

    testWidgets('Industry chips exist on page', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
            jobProvider.overrideWith(
              (ref) => JobNotifier(repository, ref),
            ),
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: LeadSearchPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Find chips
      final chips = find.byType(FilterChip);
      expect(chips, findsWidgets);
    });

    testWidgets('Page renders without errors', (WidgetTester tester) async {
      // Use a larger test viewport to avoid overflow errors
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
            jobProvider.overrideWith(
              (ref) => JobNotifier(repository, ref),
            ),
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: LeadSearchPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Verify the page loaded
      expect(find.byType(LeadSearchPage), findsOneWidget);
      
      // Reset viewport
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}