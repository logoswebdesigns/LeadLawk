import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/presentation/providers/filter_providers.dart';

void main() {
  test('Sort provider changes should be detected', () {
    final container = ProviderContainer();
    
    // Initial values
    final initialState = container.read(sortStateProvider);
    expect(initialState.option, SortOption.newest);
    expect(initialState.ascending, false);
    
    // Change sort option
    container.read(sortStateProvider.notifier).state = const SortState(
      option: SortOption.rating,
      ascending: false,
    );
    expect(container.read(sortStateProvider).option, SortOption.rating);
    
    // Change sort direction
    container.read(sortStateProvider.notifier).state = container.read(sortStateProvider).copyWith(
      ascending: true,
    );
    expect(container.read(sortStateProvider).ascending, true);
    
    container.dispose();
  });
}