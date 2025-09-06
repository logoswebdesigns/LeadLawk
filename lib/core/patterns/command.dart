// Command Pattern Implementation
// Provides undo/redo capability for all user actions
// SOLID: Single Responsibility - each command does one thing
library;

import 'package:dartz/dartz.dart';

/// Base command interface
abstract class Command<T> {
  /// Execute the command
  Future<Either<CommandFailure, T>> execute();
  
  /// Undo the command (optional)
  Future<Either<CommandFailure, void>> undo() async {
    return Left(CommandFailure('Undo not supported for this command'));
  }
  
  /// Whether this command can be undone
  bool get canUndo => false;
  
  /// Command description for history/logging
  String get description;
}

/// Command failure
class CommandFailure {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;
  
  CommandFailure(this.message, {this.error, this.stackTrace});
  
  @override
  String toString() => 'CommandFailure: $message';
}

/// Command that modifies state and can be undone
abstract class UndoableCommand<T> extends Command<T> {
  @override
  bool get canUndo => true;
  
  /// Store state for undo
  dynamic _previousState;
  
  /// Save state before execution
  void saveState(dynamic state) {
    _previousState = state;
  }
  
  /// Get saved state for undo
  dynamic get previousState => _previousState;
}

/// Composite command that executes multiple commands
class CompositeCommand<T> extends UndoableCommand<List<T>> {
  final List<Command<T>> commands;
  final String name;
  
  CompositeCommand({
    required this.commands,
    required this.name,
  });
  
  @override
  String get description => name;
  
  @override
  Future<Either<CommandFailure, List<T>>> execute() async {
    final results = <T>[];
    
    for (final command in commands) {
      final result = await command.execute();
      if (result.isLeft()) {
        // Rollback on failure
        for (int i = results.length - 1; i >= 0; i--) {
          if (commands[i].canUndo) {
            await commands[i].undo();
          }
        }
        return result.fold(
          (failure) => Left(failure),
          (_) => throw Exception('Unexpected right value'),
        );
      }
      result.fold(
        (_) => {},
        (value) => results.add(value),
      );
    }
    
    return Right(results);
  }
  
  @override
  Future<Either<CommandFailure, void>> undo() async {
    // Undo in reverse order
    for (int i = commands.length - 1; i >= 0; i--) {
      if (commands[i].canUndo) {
        final result = await commands[i].undo();
        if (result.isLeft()) {
          return result;
        }
      }
    }
    return const Right(null);
  }
}