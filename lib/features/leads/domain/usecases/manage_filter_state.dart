import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/filter_state.dart';
import '../repositories/filter_repository.dart';

// Use case for getting the current filter state
class GetFilterState implements UseCase<LeadsFilterState, NoParams> {
  final FilterRepository repository;

  GetFilterState(this.repository);

  @override
  Future<Either<Failure, LeadsFilterState>> call(NoParams params) async {
    return await repository.getFilterState();
  }
}

// Use case for updating filter state
class UpdateFilterState implements UseCase<void, UpdateFilterStateParams> {
  final FilterRepository repository;

  UpdateFilterState(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateFilterStateParams params) async {
    return await repository.saveFilterState(params.filterState);
  }
}

class UpdateFilterStateParams extends Equatable {
  final LeadsFilterState filterState;

  const UpdateFilterStateParams({required this.filterState});

  @override
  List<Object?> get props => [filterState];
}

// Use case for clearing filter state
class ClearFilterState implements UseCase<void, NoParams> {
  final FilterRepository repository;

  ClearFilterState(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.clearFilterState();
  }
}

// Use case for getting sort state
class GetSortState implements UseCase<SortState, NoParams> {
  final FilterRepository repository;

  GetSortState(this.repository);

  @override
  Future<Either<Failure, SortState>> call(NoParams params) async {
    return await repository.getSortState();
  }
}

// Use case for updating sort state
class UpdateSortState implements UseCase<void, UpdateSortStateParams> {
  final FilterRepository repository;

  UpdateSortState(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateSortStateParams params) async {
    return await repository.saveSortState(params.sortState);
  }
}

class UpdateSortStateParams extends Equatable {
  final SortState sortState;

  const UpdateSortStateParams({required this.sortState});

  @override
  List<Object?> get props => [sortState];
}

// Use case for getting UI state
class GetUIState implements UseCase<LeadsUIState, NoParams> {
  final FilterRepository repository;

  GetUIState(this.repository);

  @override
  Future<Either<Failure, LeadsUIState>> call(NoParams params) async {
    return await repository.getUIState();
  }
}

// Use case for updating UI state
class UpdateUIState implements UseCase<void, UpdateUIStateParams> {
  final FilterRepository repository;

  UpdateUIState(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateUIStateParams params) async {
    return await repository.saveUIState(params.uiState);
  }
}

class UpdateUIStateParams extends Equatable {
  final LeadsUIState uiState;

  const UpdateUIStateParams({required this.uiState});

  @override
  List<Object?> get props => [uiState];
}

// Use case for updating specific filter
class UpdateStatusFilter implements UseCase<void, UpdateStatusFilterParams> {
  final FilterRepository repository;

  UpdateStatusFilter(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateStatusFilterParams params) async {
    return await repository.updateStatusFilter(params.status);
  }
}

class UpdateStatusFilterParams extends Equatable {
  final String? status;

  const UpdateStatusFilterParams({this.status});

  @override
  List<Object?> get props => [status];
}

// Use case for updating search filter
class UpdateSearchFilter implements UseCase<void, UpdateSearchFilterParams> {
  final FilterRepository repository;

  UpdateSearchFilter(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateSearchFilterParams params) async {
    return await repository.updateSearchFilter(params.search);
  }
}

class UpdateSearchFilterParams extends Equatable {
  final String search;

  const UpdateSearchFilterParams({required this.search});

  @override
  List<Object?> get props => [search];
}

// Use case for toggling candidates only filter
class ToggleCandidatesOnlyFilter implements UseCase<void, ToggleCandidatesOnlyParams> {
  final FilterRepository repository;

  ToggleCandidatesOnlyFilter(this.repository);

  @override
  Future<Either<Failure, void>> call(ToggleCandidatesOnlyParams params) async {
    return await repository.updateCandidatesOnlyFilter(params.candidatesOnly);
  }
}

class ToggleCandidatesOnlyParams extends Equatable {
  final bool candidatesOnly;

  const ToggleCandidatesOnlyParams({required this.candidatesOnly});

  @override
  List<Object?> get props => [candidatesOnly];
}

// Use case for toggling called today filter
class ToggleCalledTodayFilter implements UseCase<void, ToggleCalledTodayParams> {
  final FilterRepository repository;

  ToggleCalledTodayFilter(this.repository);

  @override
  Future<Either<Failure, void>> call(ToggleCalledTodayParams params) async {
    return await repository.updateCalledTodayFilter(params.calledToday);
  }
}

class ToggleCalledTodayParams extends Equatable {
  final bool calledToday;

  const ToggleCalledTodayParams({required this.calledToday});

  @override
  List<Object?> get props => [calledToday];
}

// Use case for managing hidden statuses
class ToggleHiddenStatus implements UseCase<void, ToggleHiddenStatusParams> {
  final FilterRepository repository;

  ToggleHiddenStatus(this.repository);

  @override
  Future<Either<Failure, void>> call(ToggleHiddenStatusParams params) async {
    if (params.hide) {
      return await repository.addHiddenStatus(params.status);
    } else {
      return await repository.removeHiddenStatus(params.status);
    }
  }
}

class ToggleHiddenStatusParams extends Equatable {
  final String status;
  final bool hide;

  const ToggleHiddenStatusParams({
    required this.status,
    required this.hide,
  });

  @override
  List<Object?> get props => [status, hide];
}

// Use case for managing lead selections
class ToggleLeadSelection implements UseCase<void, ToggleLeadSelectionParams> {
  final FilterRepository repository;

  ToggleLeadSelection(this.repository);

  @override
  Future<Either<Failure, void>> call(ToggleLeadSelectionParams params) async {
    if (params.selected) {
      return await repository.addSelectedLead(params.leadId);
    } else {
      return await repository.removeSelectedLead(params.leadId);
    }
  }
}

class ToggleLeadSelectionParams extends Equatable {
  final String leadId;
  final bool selected;

  const ToggleLeadSelectionParams({
    required this.leadId,
    required this.selected,
  });

  @override
  List<Object?> get props => [leadId, selected];
}

// Use case for clearing all selections
class ClearLeadSelections implements UseCase<void, NoParams> {
  final FilterRepository repository;

  ClearLeadSelections(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.clearSelectedLeads();
  }
}

