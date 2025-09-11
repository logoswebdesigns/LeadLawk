import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/providers/filter_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Sort provider initial state', () async {
    // Set up SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    
    final container = ProviderContainer();
    
    // Wait for async initialization
    await Future.delayed(Duration(milliseconds: 100));
    
    // Initial values - should default to newest/descending
    final initialState = container.read(sortStateProvider);
    expect(initialState.option, SortOption.newest);
    expect(initialState.ascending, false);
    
    container.dispose();
  });
}