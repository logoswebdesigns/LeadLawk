// Mutation test runner executable.
// Pattern: Mutation Testing - test quality verification runner.

import 'dart:io';
import 'package:args/args.dart';
import 'mutation_test_config.dart';
import 'package:flutter/foundation.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('verbose', abbr: 'v', help: 'Show detailed output')
    ..addFlag('dry-run', help: 'Show mutations without applying')
    ..addOption('path', help: 'Specific path to test')
    ..addOption('operator', help: 'Specific mutation operator to use')
    ..addFlag('help', abbr: 'h', help: 'Show help');
  
  final results = parser.parse(args);
  
  if (results['help'] as bool) {
    debugPrint('Mutation Testing for LeadLawk');
    debugPrint(parser.usage);
    exit(0);
  }
  
  final verbose = results['verbose'] as bool;
  final dryRun = results['dry-run'] as bool;
  final specificPath = results['path'] as String?;
  final specificOperator = results['operator'] as String?;
  
  debugPrint('🧬 Starting Mutation Testing...\n');
  
  // Configure paths
  final paths = specificPath != null 
    ? [specificPath]
    : MutationTestConfig.includePaths;
  
  // Configure operators
  final operators = specificOperator != null
    ? MutationTestConfig.mutationOperators
        .where((op) => op.name == specificOperator)
        .toList()
    : MutationTestConfig.mutationOperators;
  
  if (operators.isEmpty && specificOperator != null) {
    debugPrint('❌ Unknown operator: $specificOperator');
    debugPrint('Available operators: ${MutationTestConfig.mutationOperators.map((o) => o.name).join(', ')}');
    exit(1);
  }
  
  if (dryRun) {
    debugPrint('🔍 DRY RUN MODE - No mutations will be applied\n');
    await _performDryRun(paths, operators, verbose);
  } else {
    final runner = MutationTestRunner(
      operators: operators,
      includePaths: paths,
      excludePaths: MutationTestConfig.excludePaths,
    );
    
    debugPrint('📊 Configuration:');
    debugPrint('  • Paths: ${paths.join(', ')}');
    debugPrint('  • Operators: ${operators.map((o) => o.name).join(', ')}');
    debugPrint('  • Minimum Score: ${(MutationTestConfig.minimumScore * 100).toStringAsFixed(0)}%\n');
    
    final result = await runner.run();
    
    _printResults(result, verbose);
    
    // Check if minimum score met
    if (result.mutationScore < MutationTestConfig.minimumScore) {
      debugPrint('\n❌ Mutation score below threshold!');
      debugPrint('   Required: ${(MutationTestConfig.minimumScore * 100).toStringAsFixed(0)}%');
      debugPrint('   Actual: ${(result.mutationScore * 100).toStringAsFixed(1)}%');
      exit(1);
    } else {
      debugPrint('\n✅ Mutation testing passed!');
      exit(0);
    }
  }
}

Future<void> _performDryRun(
  List<String> paths,
  List<MutationOperator> operators,
  bool verbose,
) async {
  var totalMutations = 0;
  final mutationsByFile = <String, List<Mutation>>{};
  
  for (final path in paths) {
    final files = await _getFiles(path);
    
    for (final file in files) {
      if (_shouldExclude(file.path)) continue;
      
      final code = await file.readAsString();
      final mutations = <Mutation>[];
      
      for (final operator in operators) {
        mutations.addAll(operator.getMutations(code));
      }
      
      if (mutations.isNotEmpty) {
        mutationsByFile[file.path] = mutations;
        totalMutations += mutations.length;
      }
    }
  }
  
  debugPrint('📋 Mutation Analysis:');
  debugPrint('  • Files to mutate: ${mutationsByFile.length}');
  debugPrint('  • Total mutations: $totalMutations\n');
  
  if (verbose) {
    for (final entry in mutationsByFile.entries) {
      debugPrint('📄 ${entry.key}');
      for (final mutation in entry.value) {
        debugPrint('   • ${mutation.description}');
        debugPrint('     ${mutation.original} → ${mutation.mutated}');
      }
      debugPrint('');
    }
  }
}

void _printResults(MutationTestResult result, bool verbose) {
  debugPrint('\n📊 Results:');
  debugPrint('  • Total Mutations: ${result.totalMutations}');
  debugPrint('  • Killed: ${result.killedMutations} ✅');
  debugPrint('  • Survived: ${result.survivedMutations} ❌');
  debugPrint('  • Score: ${(result.mutationScore * 100).toStringAsFixed(1)}%');
  
  if (verbose && result.survivedMutations > 0) {
    debugPrint('\n⚠️  Survived Mutations:');
    for (final mutation in result.mutations.where((m) => !m.killed)) {
      debugPrint('  • ${mutation.file}');
      debugPrint('    ${mutation.mutation.description}');
    }
  }
  
  // Save JSON report
  final reportFile = File('mutation_report.json');
  reportFile.writeAsStringSync(
    result.toJson().toString(),
  );
  debugPrint('\n📝 Report saved to: mutation_report.json');
}

Future<List<File>> _getFiles(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return [];
  
  return dir
      .list(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.dart'))
      .cast<File>()
      .toList();
}

bool _shouldExclude(String path) {
  return MutationTestConfig.excludePaths.any((pattern) {
    if (pattern.contains('**')) {
      return path.contains(pattern.replaceAll('**/', ''));
    }
    return path.contains(pattern);
  });
}