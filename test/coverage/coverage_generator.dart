// Test coverage report generator.
// Pattern: Test Coverage - coverage reporting and analysis.

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class CoverageGenerator {
  static const minCoveragePercent = 90.0;
  
  /// Generate coverage report
  static Future<void> generateReport({
    bool html = true,
    bool lcov = true,
    bool console = true,
  }) async {
    debugPrint('📊 Generating coverage report...\n');
    
    // Run tests with coverage
    debugPrint('🧪 Running tests with coverage...');
    final testResult = await Process.run(
      'flutter',
      ['test', '--coverage'],
      runInShell: true,
    );
    
    if (testResult.exitCode != 0) {
      debugPrint('❌ Tests failed!');
      debugPrint(testResult.stderr);
      exit(1);
    }
    
    debugPrint('✅ Tests passed!\n');
    
    // Generate LCOV report
    if (lcov) {
      debugPrint('📄 Generating LCOV report...');
      await _generateLcovReport();
    }
    
    // Generate HTML report
    if (html) {
      debugPrint('🌐 Generating HTML report...');
      await _generateHtmlReport();
    }
    
    // Print console summary
    if (console) {
      debugPrint('\n📊 Coverage Summary:');
      await _printCoverageSummary();
    }
    
    // Check minimum coverage
    final coverage = await _calculateCoverage();
    if (coverage < minCoveragePercent) {
      debugPrint('\n❌ Coverage below threshold!');
      debugPrint('   Required: ${minCoveragePercent.toStringAsFixed(0)}%');
      debugPrint('   Actual: ${coverage.toStringAsFixed(1)}%');
      exit(1);
    } else {
      debugPrint('\n✅ Coverage meets requirement: ${coverage.toStringAsFixed(1)}%');
    }
  }
  
  static Future<void> _generateLcovReport() async {
    final lcovFile = File('coverage/lcov.info');
    if (!await lcovFile.exists()) {
      debugPrint('⚠️  No coverage data found');
      return;
    }
    
    // Filter out generated files
    final lines = await lcovFile.readAsLines();
    final filtered = <String>[];
    var skip = false;
    
    for (final line in lines) {
      if (line.startsWith('SF:')) {
        skip = _shouldExcludeFile(line.substring(3));
      }
      if (!skip) {
        filtered.add(line);
      }
    }
    
    // Write filtered coverage
    final filteredFile = File('coverage/lcov_filtered.info');
    await filteredFile.writeAsString(filtered.join('\n'));
    
    debugPrint('   ✅ LCOV report: coverage/lcov_filtered.info');
  }
  
  static Future<void> _generateHtmlReport() async {
    // Check if genhtml is available
    final genHtmlCheck = await Process.run('which', ['genhtml']);
    if (genHtmlCheck.exitCode != 0) {
      debugPrint('   ⚠️  genhtml not found, skipping HTML report');
      debugPrint('   Install with: brew install lcov (macOS) or apt-get install lcov (Linux)');
      return;
    }
    
    final result = await Process.run(
      'genhtml',
      [
        'coverage/lcov_filtered.info',
        '-o', 'coverage/html',
        '--quiet',
      ],
    );
    
    if (result.exitCode == 0) {
      debugPrint('   ✅ HTML report: coverage/html/index.html');
    } else {
      debugPrint('   ⚠️  Failed to generate HTML report');
    }
  }
  
  static Future<void> _printCoverageSummary() async {
    final lcovFile = File('coverage/lcov_filtered.info');
    if (!await lcovFile.exists()) {
      debugPrint('   No coverage data available');
      return;
    }
    
    final lines = await lcovFile.readAsLines();
    final coverage = <String, CoverageData>{};
    String? currentFile;
    
    for (final line in lines) {
      if (line.startsWith('SF:')) {
        currentFile = line.substring(3);
        coverage[currentFile] = CoverageData();
      } else if (line.startsWith('DA:') && currentFile != null) {
        final parts = line.substring(3).split(',');
        final hits = int.parse(parts[1]);
        coverage[currentFile]!.lines++;
        if (hits > 0) coverage[currentFile]!.covered++;
      }
    }
    
    // Group by feature
    final featureCoverage = <String, CoverageData>{};
    for (final entry in coverage.entries) {
      final feature = _getFeatureName(entry.key);
      featureCoverage.putIfAbsent(feature, () => CoverageData());
      featureCoverage[feature]!.lines += entry.value.lines;
      featureCoverage[feature]!.covered += entry.value.covered;
    }
    
    // Print summary
    debugPrint('\n   Feature Coverage:');
    for (final entry in featureCoverage.entries) {
      final percent = entry.value.percentage;
      final status = percent >= 90 ? '✅' : percent >= 70 ? '⚠️ ' : '❌';
      debugPrint('   $status ${entry.key.padRight(25)} ${percent.toStringAsFixed(1).padLeft(5)}%');
    }
    
    // Overall coverage
    final totalLines = coverage.values.fold(0, (sum, c) => sum + c.lines);
    final totalCovered = coverage.values.fold(0, (sum, c) => sum + c.covered);
    final totalPercent = totalLines > 0 ? (totalCovered / totalLines * 100) : 0.0;
    
    debugPrint('\n   Overall Coverage: ${totalPercent.toStringAsFixed(1)}%');
    debugPrint('   Lines: $totalCovered / $totalLines');
  }
  
  static Future<double> _calculateCoverage() async {
    final lcovFile = File('coverage/lcov_filtered.info');
    if (!await lcovFile.exists()) return 0.0;
    
    final lines = await lcovFile.readAsLines();
    var totalLines = 0;
    var coveredLines = 0;
    
    for (final line in lines) {
      if (line.startsWith('DA:')) {
        final parts = line.substring(3).split(',');
        final hits = int.parse(parts[1]);
        totalLines++;
        if (hits > 0) coveredLines++;
      }
    }
    
    return totalLines > 0 ? (coveredLines / totalLines * 100) : 0.0;
  }
  
  static bool _shouldExcludeFile(String path) {
    return path.contains('.g.dart') ||
           path.contains('.freezed.dart') ||
           path.contains('generated/') ||
           path.contains('test/');
  }
  
  static String _getFeatureName(String path) {
    if (path.contains('features/leads')) return 'Leads Feature';
    if (path.contains('features/analytics')) return 'Analytics Feature';
    if (path.contains('core/cache')) return 'Cache System';
    if (path.contains('core/events')) return 'Event System';
    if (path.contains('core/performance')) return 'Performance';
    if (path.contains('core/responsive')) return 'Responsive Design';
    if (path.contains('core/components')) return 'Components';
    if (path.contains('core/')) return 'Core';
    return 'Other';
  }
}

class CoverageData {
  int lines = 0;
  int covered = 0;
  
  double get percentage => lines > 0 ? (covered / lines * 100) : 0.0;
}

/// Main entry point
void main(List<String> args) async {
  final html = !args.contains('--no-html');
  final lcov = !args.contains('--no-lcov');
  final console = !args.contains('--no-console');
  
  await CoverageGenerator.generateReport(
    html: html,
    lcov: lcov,
    console: console,
  );
}