// Mutation testing configuration.
// Pattern: Mutation Testing - test quality verification.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Mutation testing configuration
class MutationTestConfig {
  /// Operators to apply for mutations
  static const mutationOperators = [
    ArithmeticOperatorMutation(),
    ConditionalOperatorMutation(),
    LogicalOperatorMutation(),
    ReturnValueMutation(),
    ConstantMutation(),
  ];
  
  /// Files to include in mutation testing
  static const includePaths = [
    'lib/features/leads/domain/',
    'lib/core/cache/',
    'lib/core/events/',
    'lib/core/performance/',
  ];
  
  /// Files to exclude from mutation testing
  static const excludePaths = [
    'lib/generated/',
    'lib/**/*.g.dart',
    'lib/**/*.freezed.dart',
  ];
  
  /// Minimum mutation score threshold
  static const double minimumScore = 0.7; // 70%
}

/// Base mutation operator
abstract class MutationOperator {
  const MutationOperator();
  
  String get name;
  List<Mutation> getMutations(String code);
}

/// Arithmetic operator mutations
class ArithmeticOperatorMutation extends MutationOperator {
  const ArithmeticOperatorMutation();
  
  @override
  String get name => 'Arithmetic';
  
  @override
  List<Mutation> getMutations(String code) {
    final mutations = <Mutation>[];
    
    // Replace + with -
    if (code.contains('+')) {
      mutations.add(Mutation(
        original: '+',
        mutated: '-',
        description: 'Replace addition with subtraction',
      ));
    }
    
    // Replace - with +
    if (code.contains('-')) {
      mutations.add(Mutation(
        original: '-',
        mutated: '+',
        description: 'Replace subtraction with addition',
      ));
    }
    
    // Replace * with /
    if (code.contains('*')) {
      mutations.add(Mutation(
        original: '*',
        mutated: '/',
        description: 'Replace multiplication with division',
      ));
    }
    
    // Replace / with *
    if (code.contains('/')) {
      mutations.add(Mutation(
        original: '/',
        mutated: '*',
        description: 'Replace division with multiplication',
      ));
    }
    
    return mutations;
  }
}

/// Conditional operator mutations
class ConditionalOperatorMutation extends MutationOperator {
  const ConditionalOperatorMutation();
  
  @override
  String get name => 'Conditional';
  
  @override
  List<Mutation> getMutations(String code) {
    final mutations = <Mutation>[];
    
    // Replace == with !=
    if (code.contains('==')) {
      mutations.add(Mutation(
        original: '==',
        mutated: '!=',
        description: 'Replace equality with inequality',
      ));
    }
    
    // Replace != with ==
    if (code.contains('!=')) {
      mutations.add(Mutation(
        original: '!=',
        mutated: '==',
        description: 'Replace inequality with equality',
      ));
    }
    
    // Replace < with <=
    if (code.contains('<') && !code.contains('<=')) {
      mutations.add(Mutation(
        original: '<',
        mutated: '<=',
        description: 'Replace less than with less than or equal',
      ));
    }
    
    // Replace > with >=
    if (code.contains('>') && !code.contains('>=')) {
      mutations.add(Mutation(
        original: '>',
        mutated: '>=',
        description: 'Replace greater than with greater than or equal',
      ));
    }
    
    return mutations;
  }
}

/// Logical operator mutations
class LogicalOperatorMutation extends MutationOperator {
  const LogicalOperatorMutation();
  
  @override
  String get name => 'Logical';
  
  @override
  List<Mutation> getMutations(String code) {
    final mutations = <Mutation>[];
    
    // Replace && with ||
    if (code.contains('&&')) {
      mutations.add(Mutation(
        original: '&&',
        mutated: '||',
        description: 'Replace AND with OR',
      ));
    }
    
    // Replace || with &&
    if (code.contains('||')) {
      mutations.add(Mutation(
        original: '||',
        mutated: '&&',
        description: 'Replace OR with AND',
      ));
    }
    
    // Replace ! with empty
    if (code.contains('!')) {
      mutations.add(Mutation(
        original: '!',
        mutated: '',
        description: 'Remove negation',
      ));
    }
    
    return mutations;
  }
}

/// Return value mutations
class ReturnValueMutation extends MutationOperator {
  const ReturnValueMutation();
  
  @override
  String get name => 'ReturnValue';
  
  @override
  List<Mutation> getMutations(String code) {
    final mutations = <Mutation>[];
    
    // Replace return true with false
    if (code.contains('return true')) {
      mutations.add(Mutation(
        original: 'return true',
        mutated: 'return false',
        description: 'Replace true return with false',
      ));
    }
    
    // Replace return false with true
    if (code.contains('return false')) {
      mutations.add(Mutation(
        original: 'return false',
        mutated: 'return true',
        description: 'Replace false return with true',
      ));
    }
    
    // Replace return null with non-null
    if (code.contains('return null')) {
      mutations.add(Mutation(
        original: 'return null',
        mutated: 'return {}',
        description: 'Replace null return with empty object',
      ));
    }
    
    return mutations;
  }
}

/// Constant mutations
class ConstantMutation extends MutationOperator {
  const ConstantMutation();
  
  @override
  String get name => 'Constant';
  
  @override
  List<Mutation> getMutations(String code) {
    final mutations = <Mutation>[];
    
    // Replace 0 with 1
    if (code.contains('0')) {
      mutations.add(Mutation(
        original: '0',
        mutated: '1',
        description: 'Replace 0 with 1',
      ));
    }
    
    // Replace empty string with non-empty
    if (code.contains("''")) {
      mutations.add(Mutation(
        original: "''",
        mutated: "'mutated'",
        description: 'Replace empty string with non-empty',
      ));
    }
    
    return mutations;
  }
}

/// Single mutation
class Mutation {
  final String original;
  final String mutated;
  final String description;
  
  const Mutation({
    required this.original,
    required this.mutated,
    required this.description,
  });
}

/// Mutation test runner
class MutationTestRunner {
  final List<MutationOperator> operators;
  final List<String> includePaths;
  final List<String> excludePaths;
  
  MutationTestRunner({
    required this.operators,
    required this.includePaths,
    required this.excludePaths,
  });
  
  /// Run mutation tests
  Future<MutationTestResult> run() async {
    final mutations = <MutationResult>[];
    
    for (final path in includePaths) {
      final files = await _getFiles(path);
      
      for (final file in files) {
        if (_shouldExclude(file.path)) continue;
        
        final code = await file.readAsString();
        
        for (final operator in operators) {
          final fileMutations = operator.getMutations(code);
          
          for (final mutation in fileMutations) {
            final result = await _testMutation(file, mutation);
            mutations.add(result);
          }
        }
      }
    }
    
    return MutationTestResult(mutations);
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
    return excludePaths.any((pattern) {
      if (pattern.contains('**')) {
        return path.contains(pattern.replaceAll('**/', ''));
      }
      return path.contains(pattern);
    });
  }
  
  Future<MutationResult> _testMutation(File file, Mutation mutation) async {
    // Apply mutation
    final originalCode = await file.readAsString();
    final mutatedCode = originalCode.replaceAll(mutation.original, mutation.mutated);
    
    await file.writeAsString(mutatedCode);
    
    // Run tests
    final testResult = await Process.run('flutter', ['test']);
    
    // Restore original
    await file.writeAsString(originalCode);
    
    return MutationResult(
      file: file.path,
      mutation: mutation,
      killed: testResult.exitCode != 0,
    );
  }
}

/// Mutation result
class MutationResult {
  final String file;
  final Mutation mutation;
  final bool killed;
  
  MutationResult({
    required this.file,
    required this.mutation,
    required this.killed,
  });
}

/// Mutation test result
class MutationTestResult {
  final List<MutationResult> mutations;
  
  MutationTestResult(this.mutations);
  
  int get totalMutations => mutations.length;
  int get killedMutations => mutations.where((m) => m.killed).length;
  int get survivedMutations => mutations.where((m) => !m.killed).length;
  
  double get mutationScore => 
    totalMutations > 0 ? killedMutations / totalMutations : 0;
  
  Map<String, dynamic> toJson() => {
    'totalMutations': totalMutations,
    'killedMutations': killedMutations,
    'survivedMutations': survivedMutations,
    'mutationScore': mutationScore,
    'details': mutations.map((m) => {
      'file': m.file,
      'mutation': m.mutation.description,
      'killed': m.killed,
    }).toList(),
  };
}