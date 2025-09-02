import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/presentation/widgets/callback_scheduling_dialog.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:leadloq/features/leads/data/repositories/leads_repository_impl.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';
import 'package:leadloq/features/leads/presentation/providers/job_provider.dart';
import 'package:leadloq/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:dartz/dartz.dart';
import 'package:leadloq/core/error/failures.dart';

class MockDio extends Mock implements Dio {}
class MockLeadsRemoteDataSource extends Mock implements LeadsRemoteDataSource {}

// Test data factory
class TestDataFactory {
  static Lead createTestLead({
    String? id,
    String? businessName,
    LeadStatus? status,
    DateTime? followUpDate,
  }) {
    return Lead(
      id: id ?? 'test-lead-${DateTime.now().millisecondsSinceEpoch}',
      businessName: businessName ?? 'Test Business',
      phone: '555-${DateTime.now().millisecond.toString().padLeft(4, '0')}',
      industry: 'Test Industry',
      location: 'Test City',
      source: 'test',
      hasWebsite: false,
      meetsRatingThreshold: true,
      hasRecentReviews: true,
      isCandidate: true,
      status: status ?? LeadStatus.new_,
      followUpDate: followUpDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      timeline: [],
    );
  }
}

void main() {
  late MockDio mockDio;
  late MockLeadsRemoteDataSource mockDataSource;
  late LeadsRepositoryImpl repository;
  
  setUpAll(() {
    registerFallbackValue(LeadModel(
      id: 'fallback',
      businessName: 'Fallback',
      phone: '555-0000',
      industry: 'Test',
      location: 'Test',
      source: 'test',
      hasWebsite: false,
      meetsRatingThreshold: true,
      hasRecentReviews: true,
      isCandidate: true,
      status: 'new',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  });

  setUp(() {
    mockDio = MockDio();
    mockDataSource = MockLeadsRemoteDataSource();
    repository = LeadsRepositoryImpl(remoteDataSource: mockDataSource);
  });

  tearDown(() {
    // Clean up any test data
    reset(mockDio);
    reset(mockDataSource);
  });

  group('Callback Scheduling Integration Tests', () {
    testWidgets('Should successfully schedule callback with all UI updates', 
      (WidgetTester tester) async {
      // Arrange - Create test data
      final testLead = TestDataFactory.createTestLead();
      final futureDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
      
      // Mock successful lead update
      when(() => mockDataSource.updateLead(any())).thenAnswer(
        (_) async => LeadModel.fromEntity(
          testLead.copyWith(
            status: LeadStatus.callbackScheduled,
            followUpDate: futureDateTime,
          ),
        ),
      );
      
      // Mock successful timeline entry creation
      when(() => mockDataSource.addTimelineEntry(any(), any())).thenAnswer(
        (_) async => Future.value(),
      );

      // Build widget with mocked providers
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CallbackSchedulingDialog(lead: testLead),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Verify initial state
      expect(find.widgetWithText(Row, 'Schedule Callback'), findsOneWidget); // Title
      expect(find.byIcon(CupertinoIcons.calendar), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.clock), findsOneWidget);
      
      // Enter notes
      final notesField = find.byType(TextField).last;
      await tester.enterText(notesField, 'Test callback notes');
      await tester.pumpAndSettle();

      // Schedule callback
      final scheduleButton = find.widgetWithText(ElevatedButton, 'Schedule Callback');
      await tester.tap(scheduleButton);
      
      // Wait for the operation to complete
      await tester.pumpAndSettle();

      // Assert - Verify API calls were made
      verify(() => mockDataSource.updateLead(any())).called(1);
      verify(() => mockDataSource.addTimelineEntry(
        testLead.id,
        any(),
      )).called(1);
      
      // Verify dialog closed (success case)
      await tester.pumpAndSettle();
      expect(find.byType(CallbackSchedulingDialog), findsNothing);
    });

    testWidgets('Should handle update failure gracefully', 
      (WidgetTester tester) async {
      // Arrange
      final testLead = TestDataFactory.createTestLead();
      
      // Mock failed lead update
      when(() => mockDataSource.updateLead(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          message: 'Network error',
          type: DioExceptionType.connectionTimeout,
        ),
      );
      
      // Mock timeline entry - will still be called even on error (bug in implementation)
      when(() => mockDataSource.addTimelineEntry(any(), any())).thenAnswer(
        (_) async => Future.value(),
      );

      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CallbackSchedulingDialog(lead: testLead),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Try to schedule
      final scheduleButton = find.widgetWithText(ElevatedButton, 'Schedule Callback');
      await tester.tap(scheduleButton);
      await tester.pumpAndSettle();

      // Assert - Dialog stays open on error (fixed behavior)
      expect(find.byType(CallbackSchedulingDialog), findsOneWidget);
      
      // Error is shown via SnackBar
      
      // Verify update was attempted
      verify(() => mockDataSource.updateLead(any())).called(1);
      
      // Timeline entry should NOT be attempted after update failure (fixed behavior)
      verifyNever(() => mockDataSource.addTimelineEntry(any(), any()));
    });

    testWidgets('Should handle timeline entry failure gracefully', 
      (WidgetTester tester) async {
      // Arrange
      final testLead = TestDataFactory.createTestLead();
      final futureDateTime = DateTime.now().add(const Duration(days: 1));
      
      // Mock successful lead update
      when(() => mockDataSource.updateLead(any())).thenAnswer(
        (_) async => LeadModel.fromEntity(
          testLead.copyWith(
            status: LeadStatus.callbackScheduled,
            followUpDate: futureDateTime,
          ),
        ),
      );
      
      // Mock failed timeline entry creation
      when(() => mockDataSource.addTimelineEntry(any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 500,
            data: {'detail': 'Internal server error'},
          ),
        ),
      );

      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CallbackSchedulingDialog(lead: testLead),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      final scheduleButton = find.widgetWithText(ElevatedButton, 'Schedule Callback');
      await tester.tap(scheduleButton);
      await tester.pumpAndSettle();

      // Assert - Dialog closes after operation completes
      expect(find.byType(CallbackSchedulingDialog), findsNothing);
      
      // Note: Error is logged but dialog still closes in current implementation
      
      // Verify both calls were made
      verify(() => mockDataSource.updateLead(any())).called(1);
      verify(() => mockDataSource.addTimelineEntry(any(), any())).called(1);
    });

    testWidgets('Should validate and display selected date and time', 
      (WidgetTester tester) async {
      // Arrange
      final testLead = TestDataFactory.createTestLead();
      
      // Mock the repository so we don't need actual network calls
      when(() => mockDataSource.updateLead(any())).thenAnswer(
        (_) async => LeadModel.fromEntity(testLead),
      );
      
      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CallbackSchedulingDialog(lead: testLead),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Verify default values
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final expectedDateText = '${tomorrow.month}/${tomorrow.day}/${tomorrow.year}';
      
      expect(find.text(expectedDateText), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget); // Default time with AM/PM
      
      // Verify preview shows correct format
      expect(find.textContaining('Callback:'), findsOneWidget);
    });

    testWidgets('Should properly handle notes input', 
      (WidgetTester tester) async {
      // Arrange
      final testLead = TestDataFactory.createTestLead();
      const testNotes = 'Important: Call between 2-4 PM. Discuss pricing options.';
      
      // Mock successful operations
      when(() => mockDataSource.updateLead(any())).thenAnswer(
        (_) async => LeadModel.fromEntity(
          testLead.copyWith(status: LeadStatus.callbackScheduled),
        ),
      );
      
      when(() => mockDataSource.addTimelineEntry(any(), any())).thenAnswer(
        (_) async => Future.value(),
      );

      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CallbackSchedulingDialog(lead: testLead),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Enter notes
      final notesField = find.byType(TextField).last;
      await tester.enterText(notesField, testNotes);
      await tester.pumpAndSettle();

      // Schedule callback
      final scheduleButton = find.widgetWithText(ElevatedButton, 'Schedule Callback');
      await tester.tap(scheduleButton);
      await tester.pumpAndSettle();

      // Assert - Verify notes were included in timeline entry
      final capturedCall = verify(() => mockDataSource.addTimelineEntry(
        testLead.id,
        captureAny(),
      )).captured.single as Map<String, dynamic>;
      
      expect(capturedCall['type'], equals('follow_up'));
      expect(capturedCall['description'], contains(testNotes));
    });

    testWidgets('Should disable button while processing', 
      (WidgetTester tester) async {
      // Arrange
      final testLead = TestDataFactory.createTestLead();
      
      // Mock with a small delay to see loading state
      when(() => mockDataSource.updateLead(any())).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return LeadModel.fromEntity(
            testLead.copyWith(status: LeadStatus.callbackScheduled),
          );
        },
      );
      
      when(() => mockDataSource.addTimelineEntry(any(), any())).thenAnswer(
        (_) async => Future.value(),
      );

      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CallbackSchedulingDialog(lead: testLead),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      final scheduleButton = find.widgetWithText(ElevatedButton, 'Schedule Callback');
      
      // Ensure button exists
      expect(scheduleButton, findsOneWidget);
      
      // Verify button is enabled initially
      final initialButton = tester.widget<ElevatedButton>(scheduleButton);
      expect(initialButton.onPressed, isNotNull);
      
      // Tap button but don't wait for completion
      await tester.tap(scheduleButton);
      await tester.pump(); // Start processing
      
      // During processing, button should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the operation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      
      // Dialog should be closed after successful operation
      expect(find.byType(CallbackSchedulingDialog), findsNothing);
    });
  });
}