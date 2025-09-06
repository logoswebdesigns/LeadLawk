import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/repositories/filter_repository.dart';
import 'package:leadloq/features/leads/domain/usecases/manage_filter_state.dart';
import 'package:leadloq/core/usecases/usecase.dart';
import 'package:leadloq/core/error/failures.dart';

@GenerateMocks([FilterRepository])
import 'bulk_selection_test.mocks.dart';

void main() {
  group('Bulk Selection Domain Logic', () {
    late MockFilterRepository mockFilterRepository;
    late UpdateUIState updateUIState;
    late GetUIState getUIState;
    
    setUp(() {
      mockFilterRepository = MockFilterRepository();
      updateUIState = UpdateUIState(mockFilterRepository);
      getUIState = GetUIState(mockFilterRepository);
    });
    
    test('should get initial UI state with selection disabled', () async {
      // Setup
      const expectedState = LeadsUIState(isSelectionMode: false);
      when(mockFilterRepository.getUIState()).thenAnswer(
        (_) async => const Right(expectedState),
      );
      
      // Execute
      final result = await getUIState(NoParams());
      
      // Verify
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not fail'),
        (uiState) {
          expect(uiState.isSelectionMode, false);
          expect(uiState.selectedLeads, isEmpty);
        },
      );
    });

    test('should enable selection mode through use case', () async {
      // Setup
      const newState = LeadsUIState(isSelectionMode: true);
      when(mockFilterRepository.saveUIState(any)).thenAnswer(
        (_) async => const Right(null),
      );
      
      // Execute
      final result = await updateUIState(UpdateUIStateParams(uiState: newState));
      
      // Verify
      expect(result.isRight(), true);
      verify(mockFilterRepository.saveUIState(
        argThat(predicate<LeadsUIState>((state) => state.isSelectionMode)),
      )).called(1);
    });

    test('should get UI state with selection mode enabled', () async {
      // Setup
      const expectedState = LeadsUIState(isSelectionMode: true, selectedLeads: {});
      when(mockFilterRepository.getUIState()).thenAnswer(
        (_) async => const Right(expectedState),
      );
      
      // Execute
      final result = await getUIState(NoParams());
      
      // Verify
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not fail'),
        (uiState) {
          expect(uiState.isSelectionMode, true);
          expect(uiState.selectedLeads, isEmpty);
        },
      );
    });

    test('should disable selection mode through use case', () async {
      // Setup
      const newState = LeadsUIState(isSelectionMode: false, selectedLeads: {});
      when(mockFilterRepository.saveUIState(any)).thenAnswer(
        (_) async => const Right(null),
      );
      
      // Execute
      final result = await updateUIState(UpdateUIStateParams(uiState: newState));
      
      // Verify
      expect(result.isRight(), true);
      verify(mockFilterRepository.saveUIState(
        argThat(predicate<LeadsUIState>((state) => !state.isSelectionMode)),
      )).called(1);
    });

    test('should manage multiple selected leads', () async {
      // Setup
      const selectedLeads = {'lead1', 'lead2', 'lead3'};
      const stateWithSelections = LeadsUIState(
        isSelectionMode: true,
        selectedLeads: selectedLeads,
      );
      
      when(mockFilterRepository.getUIState()).thenAnswer(
        (_) async => const Right(stateWithSelections),
      );
      
      // Execute
      final result = await getUIState(NoParams());
      
      // Verify
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not fail'),
        (uiState) {
          expect(uiState.isSelectionMode, true);
          expect(uiState.selectedLeads.length, 3);
          expect(uiState.selectedLeads, contains('lead1'));
          expect(uiState.selectedLeads, contains('lead2'));
          expect(uiState.selectedLeads, contains('lead3'));
        },
      );
    });
    
    test('should handle selection mode toggle failure', () async {
      // Setup
      final failure = CacheFailure('Failed to toggle selection mode');
      when(mockFilterRepository.saveUIState(any)).thenAnswer(
        (_) async => Left(failure),
      );
      
      // Execute
      const newState = LeadsUIState(isSelectionMode: true);
      final result = await updateUIState(UpdateUIStateParams(uiState: newState));
      
      // Verify
      expect(result.isLeft(), true);
      result.fold(
        (error) => expect(error, isA<CacheFailure>()),
        (_) => fail('Should have failed'),
      );
    });
  });
}