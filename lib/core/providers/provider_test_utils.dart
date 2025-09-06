// Testing utilities for Riverpod providers.
// Pattern: Test Helper Pattern - simplifies provider testing.
// Single Responsibility: Provider test utilities.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'provider_observer.dart';

/// Test container with automatic cleanup
class TestProviderContainer {
  late ProviderContainer container;
  final List<Override> overrides;
  final AppProviderObserver? observer;
  
  TestProviderContainer({
    this.overrides = const [],
    bool enableObserver = false,
  }) : observer = enableObserver ? AppProviderObserver(enableLogging: false) : null {
    container = ProviderContainer(
      overrides: overrides,
      observers: observer != null ? [observer!] : [],
    );
  }
  
  /// Read a provider value
  T read<T>(ProviderListenable<T> provider) {
    return container.read(provider);
  }
  
  /// Listen to a provider
  ProviderSubscription<T> listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    bool fireImmediately = false,
  }) {
    return container.listen(provider, listener, fireImmediately: fireImmediately);
  }
  
  /// Update provider overrides
  void updateOverrides(List<Override> newOverrides) {
    container.updateOverrides(newOverrides);
  }
  
  /// Get provider metrics if observer is enabled
  Map<String, ProviderMetrics>? getMetrics() {
    return observer?.getMetrics();
  }
  
  /// Dispose the container
  void dispose() {
    container.dispose();
  }
}

/// Provider test harness for easy setup and teardown
class ProviderTestHarness {
  late TestProviderContainer container;
  final List<Override> overrides;
  
  ProviderTestHarness({this.overrides = const []});
  
  /// Setup the test harness
  void setUp() {
    container = TestProviderContainer(
      overrides: overrides,
      enableObserver: true,
    );
  }
  
  /// Tear down the test harness
  void tearDown() {
    container.dispose();
  }
  
  /// Run a test with automatic setup and teardown
  Future<void> runTest(Future<void> Function(TestProviderContainer) test) async {
    setUp();
    try {
      await test(container);
    } finally {
      tearDown();
    }
  }
}

/// Extension methods for testing async providers
extension AsyncValueTestExtensions<T> on AsyncValue<T> {
  /// Assert that the async value is loading
  void expectLoading() {
    expect(isLoading, true);
    expect(hasValue, false);
    expect(hasError, false);
  }
  
  /// Assert that the async value has data
  void expectData(T expected) {
    expect(hasValue, true);
    expect(value, expected);
    expect(hasError, false);
  }
  
  /// Assert that the async value has an error
  void expectError([String? message]) {
    expect(hasError, true);
    expect(hasValue, false);
    if (message != null) {
      expect(error.toString(), contains(message));
    }
  }
}


/// Test helper for state notifier providers
class StateNotifierTestHelper<Notifier extends StateNotifier<State>, State> {
  final StateNotifierProvider<Notifier, State> provider;
  final TestProviderContainer container;
  final List<State> stateHistory = [];
  ProviderSubscription<State>? _subscription;
  
  StateNotifierTestHelper({
    required this.provider,
    required this.container,
  }) {
    _startRecording();
  }
  
  void _startRecording() {
    _subscription = container.listen(provider, (previous, next) {
      stateHistory.add(next);
    }, fireImmediately: true);
  }
  
  /// Get the current state
  State get state => container.read(provider);
  
  /// Get the notifier
  Notifier get notifier => container.read(provider.notifier);
  
  /// Assert state changes
  void expectStateSequence(List<State> expected) {
    expect(stateHistory, expected);
  }
  
  /// Clear state history
  void clearHistory() {
    stateHistory.clear();
  }
  
  /// Dispose resources
  void dispose() {
    _subscription?.close();
  }
}

/// Provider dependency graph analyzer
class ProviderDependencyAnalyzer {
  final Map<String, Set<String>> _dependencies = {};
  
  /// Add a dependency relationship
  void addDependency(String provider, String dependsOn) {
    _dependencies.putIfAbsent(provider, () => {}).add(dependsOn);
  }
  
  /// Check for circular dependencies
  bool hasCircularDependency() {
    final visited = <String>{};
    final recursionStack = <String>{};
    
    for (final provider in _dependencies.keys) {
      if (_hasCycle(provider, visited, recursionStack)) {
        return true;
      }
    }
    
    return false;
  }
  
  bool _hasCycle(String provider, Set<String> visited, Set<String> recursionStack) {
    visited.add(provider);
    recursionStack.add(provider);
    
    final dependencies = _dependencies[provider] ?? {};
    for (final dep in dependencies) {
      if (!visited.contains(dep)) {
        if (_hasCycle(dep, visited, recursionStack)) {
          return true;
        }
      } else if (recursionStack.contains(dep)) {
        return true;
      }
    }
    
    recursionStack.remove(provider);
    return false;
  }
  
  /// Get dependency graph
  Map<String, Set<String>> getDependencies() => Map.from(_dependencies);
  
  /// Get providers with no dependencies
  List<String> getRootProviders() {
    final allProviders = _dependencies.keys.toSet();
    final dependentProviders = _dependencies.values.expand((deps) => deps).toSet();
    return allProviders.difference(dependentProviders).toList();
  }
}