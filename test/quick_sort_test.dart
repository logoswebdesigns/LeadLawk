import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/presentation/pages/leads_list_page.dart';

void main() {
  test('Sort provider changes should be detected', () {
    final container = ProviderContainer();
    
    // Initial values
    final initialState = container.read(sortStateProvider);
    expect(initialState.option, SortOption.newest);
    expect(initialState.ascending, false);
    
    // Change sort option
    container.read(sortStateProvider.notifier).state = SortState(
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