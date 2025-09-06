/// Command Bus for executing commands with history
/// Pattern: Command Pattern with Event Sourcing
/// SOLID: Open/Closed - new commands without modifying bus
library;

import 'dart:collection';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'command.dart';

class CommandBus {
  final _history = ListQueue<Command>();
  final _undoStack = ListQueue<Command>();
  final int maxHistorySize;
  
  CommandBus({this.maxHistorySize = 100});
  
  /// Execute a command
  Future<Either<CommandFailure, T>> execute<T>(Command<T> command) async {
    final result = await command.execute();
    
    if (result.isRight()) {
      // Add to history
      _history.add(command);
      if (_history.length > maxHistorySize) {
        _history.removeFirst();
      }
      
      // Clear redo stack on new command
      _undoStack.clear();
    }
    
    return result;
  }
  
  /// Undo last command
  Future<Either<CommandFailure, void>> undo() async {
    if (!canUndo) {
      return Left(CommandFailure('Nothing to undo'));
    }
    
    final command = _history.removeLast();
    if (!command.canUndo) {
      return Left(CommandFailure('Command cannot be undone: ${command.description}'));
    }
    
    final result = await command.undo();
    if (result.isRight()) {
      _undoStack.add(command);
    }
    
    return result;
  }
  
  /// Redo last undone command
  Future<Either<CommandFailure, void>> redo() async {
    if (!canRedo) {
      return Left(CommandFailure('Nothing to redo'));
    }
    
    final command = _undoStack.removeLast();
    final result = await command.execute();
    
    if (result.isRight()) {
      _history.add(command);
    }
    
    return result.fold(
      (failure) => Left(failure),
      (_) => const Right(null),
    );
  }
  
  /// Check if undo is available
  bool get canUndo => _history.isNotEmpty && _history.last.canUndo;
  
  /// Check if redo is available  
  bool get canRedo => _undoStack.isNotEmpty;
  
  /// Get command history
  List<Command> get history => List.unmodifiable(_history);
  
  /// Get command history descriptions
  List<String> get historyDescriptions => 
    _history.map((cmd) => cmd.description).toList();
  
  /// Clear history
  void clearHistory() {
    _history.clear();
    _undoStack.clear();
  }
}

/// Provider for command bus
final commandBusProvider = Provider<CommandBus>((ref) {
  return CommandBus();
});

/// State notifier for command history
class CommandHistoryNotifier extends StateNotifier<CommandHistoryState> {
  final CommandBus _bus;
  
  CommandHistoryNotifier(this._bus) : super(CommandHistoryState());
  
  Future<Either<CommandFailure, T>> execute<T>(Command<T> command) async {
    final result = await _bus.execute(command);
    _updateState();
    return result;
  }
  
  Future<void> undo() async {
    await _bus.undo();
    _updateState();
  }
  
  Future<void> redo() async {
    await _bus.redo();
    _updateState();
  }
  
  void _updateState() {
    state = CommandHistoryState(
      canUndo: _bus.canUndo,
      canRedo: _bus.canRedo,
      history: _bus.historyDescriptions,
    );
  }
}

/// Command history state
class CommandHistoryState {
  final bool canUndo;
  final bool canRedo;
  final List<String> history;
  
  CommandHistoryState({
    this.canUndo = false,
    this.canRedo = false,
    this.history = const [],
  });
}

/// Provider for command history
final commandHistoryProvider = 
  StateNotifierProvider<CommandHistoryNotifier, CommandHistoryState>((ref) {
    final bus = ref.watch(commandBusProvider);
    return CommandHistoryNotifier(bus);
  });