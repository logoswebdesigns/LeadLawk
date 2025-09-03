import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/presentation/pages/leads_list_page.dart';

void main() {
  test('Sort provider changes should be detected', () {
    final container = ProviderContainer();
    
    // Initial values
    expect(container.read(sortOptionProvider), SortOption.newest);
    expect(container.read(sortAscendingProvider), false);
    
    // Change sort option
    container.read(sortOptionProvider.notifier).state = SortOption.rating;
    expect(container.read(sortOptionProvider), SortOption.rating);
    
    // Change sort direction
    container.read(sortAscendingProvider.notifier).state = true;
    expect(container.read(sortAscendingProvider), true);
    
    container.dispose();
  });
}