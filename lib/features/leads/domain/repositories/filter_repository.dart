import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/filter_state.dart';

// Repository interface for filter state management
abstract class FilterRepository {
  // Filter state management
  Future<Either<Failure, LeadsFilterState>> getFilterState();
  Future<Either<Failure, void>> saveFilterState(LeadsFilterState filterState);
  Future<Either<Failure, void>> clearFilterState();
  
  // Sort state management
  Future<Either<Failure, SortState>> getSortState();
  Future<Either<Failure, void>> saveSortState(SortState sortState);
  Future<Either<Failure, void>> clearSortState();
  
  // UI state management
  Future<Either<Failure, LeadsUIState>> getUIState();
  Future<Either<Failure, void>> saveUIState(LeadsUIState uiState);
  Future<Either<Failure, void>> clearUIState();
  
  // Convenience methods for common filter operations
  Future<Either<Failure, void>> updateStatusFilter(String? status);
  Future<Either<Failure, void>> updateSearchFilter(String search);
  Future<Either<Failure, void>> updateCandidatesOnlyFilter(bool candidatesOnly);
  Future<Either<Failure, void>> updateCalledTodayFilter(bool calledToday);
  Future<Either<Failure, void>> addHiddenStatus(String status);
  Future<Either<Failure, void>> removeHiddenStatus(String status);
  Future<Either<Failure, void>> clearHiddenStatuses();
  
  // Page size management
  Future<Either<Failure, void>> updatePageSize(int pageSize);
  Future<Either<Failure, int>> getPageSize();
  
  // Selection management  
  Future<Either<Failure, void>> addSelectedLead(String leadId);
  Future<Either<Failure, void>> removeSelectedLead(String leadId);
  Future<Either<Failure, void>> clearSelectedLeads();
  Future<Either<Failure, void>> toggleSelectionMode(bool enabled);
  
  // Scroll position persistence
  Future<Either<Failure, void>> saveScrollPosition(double position);
  Future<Either<Failure, double?>> getScrollPosition();
  Future<Either<Failure, void>> clearScrollPosition();
}