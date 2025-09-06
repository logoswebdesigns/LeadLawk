import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/presentation/widgets/sort_bar.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/repositories/filter_repository.dart';
import 'package:leadloq/features/leads/domain/providers/filter_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';

@GenerateMocks([FilterRepository])
import 'refresh_button_test.mocks.dart';

void main() {
  group('Refresh Button Tests', () {
    late MockFilterRepository mockFilterRepository;
    
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      
      mockFilterRepository = MockFilterRepository();
      
      // Setup mock filter repository responses
      when(mockFilterRepository.getFilterState()).thenAnswer((_) async => const Right(LeadsFilterState()));
      when(mockFilterRepository.getSortState()).thenAnswer((_) async => const Right(SortState()));
      when(mockFilterRepository.getUIState()).thenAnswer((_) async => const Right(LeadsUIState()));
      when(mockFilterRepository.saveFilterState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveSortState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveUIState(any)).thenAnswer((_) async => const Right(null));
    });
    
    testWidgets('Refresh button is visible in sort bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
            filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SortBar(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Check if Refresh text is present
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('Select and Sort buttons remain visible with Refresh button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
            filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SortBar(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Check all buttons are present
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget); // Auto-refresh toggle (default off)
      // Sort button contains "Newest" text
      final sortButtonText = find.byWidgetPredicate((widget) {
        if (widget is Text && widget.data == 'Newest') {
          return true;
        }
        return false;
      });
      expect(sortButtonText, findsOneWidget);
    });
  });
}