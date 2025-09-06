// Comprehensive test runner for all test types.
// Pattern: Test Orchestration - unified test execution.

import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter/foundation.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('unit', defaultsTo: true, help: 'Run unit tests')
    ..addFlag('integration', defaultsTo: true, help: 'Run integration tests')
    ..addFlag('e2e', defaultsTo: false, help: 'Run E2E tests')
    ..addFlag('performance', defaultsTo: false, help: 'Run performance tests')
    ..addFlag('mutation', defaultsTo: false, help: 'Run mutation tests')
    ..addFlag('coverage', defaultsTo: true, help: 'Generate coverage report')
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output')
    ..addFlag('fail-fast', help: 'Stop on first failure')
    ..addFlag('help', abbr: 'h', help: 'Show help');
  
  final results = parser.parse(args);
  
  if (results['help'] as bool) {
    debugPrint('🧪 LeadLawk Test Runner');
    debugPrint(parser.usage);
    exit(0);
  }
  
  final verbose = results['verbose'] as bool;
  final failFast = results['fail-fast'] as bool;
  final testResults = <String, bool>{};
  
  debugPrint('🧪 LeadLawk Comprehensive Test Suite\n');
  debugPrint('=' * 50);
  
  // Run unit tests
  if (results['unit'] as bool) {
    debugPrint('\n📦 Running Unit Tests...');
    final success = await _runTests(
      'Unit Tests',
      ['test', '--exclude-tags=integration'],
      verbose: verbose,
    );
    testResults['Unit Tests'] = success;
    if (!success && failFast) _exitWithResults(testResults);
  }
  
  // Run integration tests
  if (results['integration'] as bool) {
    debugPrint('\n🔗 Running Integration Tests...');
    final success = await _runTests(
      'Integration Tests',
      ['test', '--tags=integration'],
      verbose: verbose,
    );
    testResults['Integration Tests'] = success;
    if (!success && failFast) _exitWithResults(testResults);
  }
  
  // Run E2E tests
  if (results['e2e'] as bool) {
    debugPrint('\n🌐 Running E2E Tests...');
    final success = await _runTests(
      'E2E Tests',
      ['test', 'test/e2e'],
      verbose: verbose,
    );
    testResults['E2E Tests'] = success;
    if (!success && failFast) _exitWithResults(testResults);
  }
  
  // Run performance tests
  if (results['performance'] as bool) {
    debugPrint('\n⚡ Running Performance Tests...');
    final success = await _runTests(
      'Performance Tests',
      ['test', 'test/performance'],
      verbose: verbose,
    );
    testResults['Performance Tests'] = success;
    if (!success && failFast) _exitWithResults(testResults);
  }
  
  // Run mutation tests
  if (results['mutation'] as bool) {
    debugPrint('\n🧬 Running Mutation Tests...');
    final success = await _runMutationTests(verbose: verbose);
    testResults['Mutation Tests'] = success;
    if (!success && failFast) _exitWithResults(testResults);
  }
  
  // Generate coverage report
  if (results['coverage'] as bool) {
    debugPrint('\n📊 Generating Coverage Report...');
    await _generateCoverage(verbose: verbose);
  }
  
  // Print final results
  _printFinalResults(testResults);
  
  // Exit with appropriate code
  final allPassed = testResults.values.every((success) => success);
  exit(allPassed ? 0 : 1);
}

Future<bool> _runTests(
  String name,
  List<String> args,
  {bool verbose = false}
) async {
  final stopwatch = Stopwatch()..start();
  
  final result = await Process.run(
    'flutter',
    args,
    runInShell: true,
  );
  
  stopwatch.stop();
  
  if (verbose) {
    debugPrint(result.stdout);
    if (result.stderr.toString().isNotEmpty) {
      debugPrint(result.stderr);
    }
  }
  
  final success = result.exitCode == 0;
  final status = success ? '✅' : '❌';
  debugPrint('$status $name completed in ${stopwatch.elapsed.inSeconds}s');
  
  if (!success && !verbose) {
    debugPrint('   Run with --verbose to see detailed output');
  }
  
  return success;
}

Future<bool> _runMutationTests({bool verbose = false}) async {
  final stopwatch = Stopwatch()..start();
  
  final result = await Process.run(
    'dart',
    ['run', 'test/mutation/mutation_test_runner.dart'],
    runInShell: true,
  );
  
  stopwatch.stop();
  
  if (verbose) {
    debugPrint(result.stdout);
  }
  
  final success = result.exitCode == 0;
  final status = success ? '✅' : '❌';
  debugPrint('$status Mutation Tests completed in ${stopwatch.elapsed.inSeconds}s');
  
  return success;
}

Future<void> _generateCoverage({bool verbose = false}) async {
  final result = await Process.run(
    'dart',
    ['run', 'test/coverage/coverage_generator.dart'],
    runInShell: true,
  );
  
  if (verbose || result.exitCode != 0) {
    debugPrint(result.stdout);
    if (result.stderr.toString().isNotEmpty) {
      debugPrint(result.stderr);
    }
  }
}

void _printFinalResults(Map<String, bool> results) {
  debugPrint('\n' + '=' * 50);
  debugPrint('📊 Test Results Summary:\n');
  
  for (final entry in results.entries) {
    final status = entry.value ? '✅ PASS' : '❌ FAIL';
    debugPrint('   ${entry.key.padRight(20)} $status');
  }
  
  final passed = results.values.where((v) => v).length;
  final total = results.length;
  final percentage = total > 0 ? (passed / total * 100) : 0;
  
  debugPrint('\n   Overall: $passed/$total (${percentage.toStringAsFixed(0)}%)');
  
  if (percentage == 100) {
    debugPrint('\n🎉 All tests passed!');
  } else {
    debugPrint('\n⚠️  Some tests failed');
  }
}

void _exitWithResults(Map<String, bool> results) {
  debugPrint('\n⛔ Fail-fast enabled, stopping test execution');
  _printFinalResults(results);
  exit(1);
}