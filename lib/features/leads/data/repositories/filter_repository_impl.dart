import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/error/failures.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/repositories/filter_repository.dart';

class FilterRepositoryImpl implements FilterRepository {
  final SharedPreferences _preferences;
  
  // Storage keys
  static const String _filterStateKey = 'leads_filter_state';
  static const String _sortStateKey = 'leads_sort_state';
  static const String _uiStateKey = 'leads_ui_state';
  static const String _pageSizeKey = 'leads_page_size';
  static const String _scrollPositionKey = 'leads_list_scroll_position';

  FilterRepositoryImpl(this._preferences);

  @override
  Future<Either<Failure, LeadsFilterState>> getFilterState() async {
    try {
      final jsonString = _preferences.getString(_filterStateKey);
      if (jsonString == null) {
        return const Right(LeadsFilterState());
      }
      
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final filterState = LeadsFilterState.fromMap(jsonMap);
      return Right(filterState);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveFilterState(LeadsFilterState filterState) async {
    try {
      final jsonString = json.encode(filterState.toMap());
      await _preferences.setString(_filterStateKey, jsonString);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearFilterState() async {
    try {
      await _preferences.remove(_filterStateKey);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SortState>> getSortState() async {
    try {
      final jsonString = _preferences.getString(_sortStateKey);
      if (jsonString == null) {
        return const Right(SortState());
      }
      
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final sortState = SortState.fromMap(jsonMap);
      return Right(sortState);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveSortState(SortState sortState) async {
    try {
      final jsonString = json.encode(sortState.toMap());
      await _preferences.setString(_sortStateKey, jsonString);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearSortState() async {
    try {
      await _preferences.remove(_sortStateKey);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeadsUIState>> getUIState() async {
    try {
      final jsonString = _preferences.getString(_uiStateKey);
      if (jsonString == null) {
        return const Right(LeadsUIState());
      }
      
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final uiState = LeadsUIState.fromMap(jsonMap);
      return Right(uiState);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveUIState(LeadsUIState uiState) async {
    try {
      final jsonString = json.encode(uiState.toMap());
      await _preferences.setString(_uiStateKey, jsonString);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearUIState() async {
    try {
      await _preferences.remove(_uiStateKey);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // Convenience methods for common filter operations
  @override
  Future<Either<Failure, void>> updateStatusFilter(String? status) async {
    final currentFilterResult = await getFilterState();
    return currentFilterResult.fold(
      (failure) => Left(failure),
      (currentFilter) async {
        final updatedFilter = currentFilter.copyWith(statusFilter: status);
        return await saveFilterState(updatedFilter);
      },
    );
  }

  @override
  Future<Either<Failure, void>> updateSearchFilter(String search) async {
    final currentFilterResult = await getFilterState();
    return currentFilterResult.fold(
      (failure) => Left(failure),
      (currentFilter) async {
        final updatedFilter = currentFilter.copyWith(searchFilter: search);
        return await saveFilterState(updatedFilter);
      },
    );
  }

  @override
  Future<Either<Failure, void>> updateCandidatesOnlyFilter(bool candidatesOnly) async {
    final currentFilterResult = await getFilterState();
    return currentFilterResult.fold(
      (failure) => Left(failure),
      (currentFilter) async {
        final updatedFilter = currentFilter.copyWith(candidatesOnly: candidatesOnly);
        return await saveFilterState(updatedFilter);
      },
    );
  }

  @override
  Future<Either<Failure, void>> updateCalledTodayFilter(bool calledToday) async {
    final currentFilterResult = await getFilterState();
    return currentFilterResult.fold(
      (failure) => Left(failure),
      (currentFilter) async {
        final updatedFilter = currentFilter.copyWith(calledToday: calledToday);
        return await saveFilterState(updatedFilter);
      },
    );
  }

  @override
  Future<Either<Failure, void>> addHiddenStatus(String status) async {
    final currentFilterResult = await getFilterState();
    return currentFilterResult.fold(
      (failure) => Left(failure),
      (currentFilter) async {
        final updatedHiddenStatuses = Set<String>.from(currentFilter.hiddenStatuses)
          ..add(status);
        final updatedFilter = currentFilter.copyWith(hiddenStatuses: updatedHiddenStatuses);
        return await saveFilterState(updatedFilter);
      },
    );
  }

  @override
  Future<Either<Failure, void>> removeHiddenStatus(String status) async {
    final currentFilterResult = await getFilterState();
    return currentFilterResult.fold(
      (failure) => Left(failure),
      (currentFilter) async {
        final updatedHiddenStatuses = Set<String>.from(currentFilter.hiddenStatuses)
          ..remove(status);
        final updatedFilter = currentFilter.copyWith(hiddenStatuses: updatedHiddenStatuses);
        return await saveFilterState(updatedFilter);
      },
    );
  }

  @override
  Future<Either<Failure, void>> clearHiddenStatuses() async {
    final currentFilterResult = await getFilterState();
    return currentFilterResult.fold(
      (failure) => Left(failure),
      (currentFilter) async {
        final updatedFilter = currentFilter.copyWith(hiddenStatuses: <String>{});
        return await saveFilterState(updatedFilter);
      },
    );
  }

  @override
  Future<Either<Failure, void>> updatePageSize(int pageSize) async {
    try {
      await _preferences.setInt(_pageSizeKey, pageSize);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getPageSize() async {
    try {
      final pageSize = _preferences.getInt(_pageSizeKey) ?? 25;
      return Right(pageSize);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addSelectedLead(String leadId) async {
    final currentUIResult = await getUIState();
    return currentUIResult.fold(
      (failure) => Left(failure),
      (currentUI) async {
        final updatedSelectedLeads = Set<String>.from(currentUI.selectedLeads)
          ..add(leadId);
        final updatedUI = currentUI.copyWith(selectedLeads: updatedSelectedLeads);
        return await saveUIState(updatedUI);
      },
    );
  }

  @override
  Future<Either<Failure, void>> removeSelectedLead(String leadId) async {
    final currentUIResult = await getUIState();
    return currentUIResult.fold(
      (failure) => Left(failure),
      (currentUI) async {
        final updatedSelectedLeads = Set<String>.from(currentUI.selectedLeads)
          ..remove(leadId);
        final updatedUI = currentUI.copyWith(selectedLeads: updatedSelectedLeads);
        return await saveUIState(updatedUI);
      },
    );
  }

  @override
  Future<Either<Failure, void>> clearSelectedLeads() async {
    final currentUIResult = await getUIState();
    return currentUIResult.fold(
      (failure) => Left(failure),
      (currentUI) async {
        final updatedUI = currentUI.copyWith(selectedLeads: <String>{});
        return await saveUIState(updatedUI);
      },
    );
  }

  @override
  Future<Either<Failure, void>> toggleSelectionMode(bool enabled) async {
    final currentUIResult = await getUIState();
    return currentUIResult.fold(
      (failure) => Left(failure),
      (currentUI) async {
        final updatedUI = currentUI.copyWith(isSelectionMode: enabled);
        return await saveUIState(updatedUI);
      },
    );
  }

  @override
  Future<Either<Failure, void>> saveScrollPosition(double position) async {
    try {
      await _preferences.setDouble(_scrollPositionKey, position);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double?>> getScrollPosition() async {
    try {
      final position = _preferences.getDouble(_scrollPositionKey);
      return Right(position);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearScrollPosition() async {
    try {
      await _preferences.remove(_scrollPositionKey);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}