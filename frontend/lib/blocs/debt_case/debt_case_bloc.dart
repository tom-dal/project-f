import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/debt_case.dart';
import '../../services/api_service.dart';
import '../../models/case_state.dart';

// Events
abstract class DebtCaseEvent extends Equatable {
  const DebtCaseEvent();

  @override
  List<Object?> get props => [];
}

class LoadCasesPaginated extends DebtCaseEvent {
  final int page;
  final int size;
  final String? sort;
  final String? debtorName;
  final CaseState? state;

  const LoadCasesPaginated({
    this.page = 0,
    this.size = 20,
    this.sort,
    this.debtorName,
    this.state,
  });

  @override
  List<Object?> get props => [page, size, sort, debtorName, state];
}

class CreateDebtCase extends DebtCaseEvent {
  final String debtorName;
  final CaseState initialState;
  final DateTime lastStateDate;
  final double amount;

  const CreateDebtCase({
    required this.debtorName,
    required this.initialState,
    required this.lastStateDate,
    required this.amount,
  });

  @override
  List<Object?> get props => [debtorName, initialState, lastStateDate, amount];
}

class UpdateDebtCaseState extends DebtCaseEvent {
  final String id; // Changed from int to String for MongoDB ObjectId compatibility
  final DateTime completionDate;
  final String? notes;

  const UpdateDebtCaseState({
    required this.id,
    required this.completionDate,
    this.notes,
  });

  @override
  List<Object?> get props => [id, completionDate, notes];
}

class UpdateDebtCase extends DebtCaseEvent {
  final String id; // Changed from int to String for MongoDB ObjectId compatibility
  final String? debtorName;
  final double? amount;
  final CaseState? state;
  final String? notes;

  const UpdateDebtCase({
    required this.id,
    this.debtorName,
    this.amount,
    this.state,
    this.notes,
  });

  @override
  List<Object?> get props => [id, debtorName, amount, state, notes];
}

class DeleteDebtCase extends DebtCaseEvent {
  final String id; // Changed from int to String for MongoDB ObjectId compatibility

  const DeleteDebtCase(this.id);

  @override
  List<Object?> get props => [id];
}

// States
abstract class DebtCaseState extends Equatable {
  const DebtCaseState();

  @override
  List<Object?> get props => [];
}

class DebtCaseInitial extends DebtCaseState {}

class DebtCaseLoading extends DebtCaseState {}

class DebtCasePaginatedLoaded extends DebtCaseState {
  final List<DebtCase> cases;
  final int currentPage;
  final int totalPages;
  final int totalElements;
  final bool hasNext;
  final bool hasPrevious;

  const DebtCasePaginatedLoaded({
    required this.cases,
    required this.currentPage,
    required this.totalPages,
    required this.totalElements,
    required this.hasNext,
    required this.hasPrevious,
  });

  @override
  List<Object?> get props => [cases, currentPage, totalPages, totalElements, hasNext, hasPrevious];
}

class DebtCaseError extends DebtCaseState {
  final String message;

  const DebtCaseError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class DebtCaseBloc extends Bloc<DebtCaseEvent, DebtCaseState> {
  final ApiService _apiService;

  DebtCaseBloc(this._apiService) : super(DebtCaseInitial()) {
    on<LoadCasesPaginated>(_onLoadCasesPaginated);
    on<CreateDebtCase>(_onCreateDebtCase);
    on<UpdateDebtCaseState>(_onUpdateDebtCaseState);
    on<UpdateDebtCase>(_onUpdateDebtCase);
    on<DeleteDebtCase>(_onDeleteDebtCase);
  }

  Future<void> _onLoadCasesPaginated(
    LoadCasesPaginated event,
    Emitter<DebtCaseState> emit,
  ) async {
    emit(DebtCaseLoading());
    try {
      final paginatedResponse = await _apiService.getAllCasesPaginated(
        page: event.page,
        size: event.size,
        sort: event.sort,
        debtorName: event.debtorName,
        state: event.state,
      );

      final cases = paginatedResponse.getItems('cases', (json) => DebtCase.fromJson(json));

      emit(DebtCasePaginatedLoaded(
        cases: cases,
        currentPage: paginatedResponse.page.number,
        totalPages: paginatedResponse.page.totalPages,
        totalElements: paginatedResponse.page.totalElements,
        hasNext: !paginatedResponse.page.last,
        hasPrevious: !paginatedResponse.page.first,
      ));
    } catch (e) {
      emit(DebtCaseError('Failed to load cases: ${e.toString()}'));
    }
  }

  Future<void> _onCreateDebtCase(
    CreateDebtCase event,
    Emitter<DebtCaseState> emit,
  ) async {
    emit(DebtCaseLoading());
    try {
      await _apiService.createDebtCase(
        debtorName: event.debtorName,
        initialState: event.initialState,
        lastStateDate: event.lastStateDate,
        amount: event.amount,
      );
      // Ricarica tutti i casi invece di solo quelli con il nuovo stato
      add(const LoadCasesPaginated());
    } catch (e) {
      emit(DebtCaseError('Failed to create case: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateDebtCaseState(
    UpdateDebtCaseState event,
    Emitter<DebtCaseState> emit,
  ) async {
    emit(DebtCaseLoading());
    try {
      await _apiService.updateState(
        id: event.id,
        completionDate: event.completionDate,
        notes: event.notes,
      );
      // Ricarica tutti i casi invece di solo quelli con il nuovo stato
      add(const LoadCasesPaginated());
    } catch (e) {
      emit(DebtCaseError('Failed to update case: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateDebtCase(
    UpdateDebtCase event,
    Emitter<DebtCaseState> emit,
  ) async {
    // Don't emit loading state for updates to avoid UI flickering
    try {
      // Find the current debt case to pass the complete object with HATEOAS links
      DebtCase? currentCase;
      if (state is DebtCasePaginatedLoaded) {
        final currentCases = (state as DebtCasePaginatedLoaded).cases;
        currentCase = currentCases.firstWhere(
          (debtCase) => debtCase.id == event.id,
          orElse: () => throw 'Case not found for update',
        );
      }

      if (currentCase == null) {
        throw 'Case not found for update';
      }

      await _apiService.updateDebtCase(
        debtCase: currentCase, // Pass the complete DebtCase object with HATEOAS links
        currentState: event.state,
        notes: event.notes,
      );
      // Ricarica tutti i casi
      add(const LoadCasesPaginated());
    } catch (e) {
      emit(DebtCaseError('Failed to update case: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteDebtCase(
    DeleteDebtCase event,
    Emitter<DebtCaseState> emit,
  ) async {
    try {
      // Find the current debt case to pass the complete object with HATEOAS links
      DebtCase? currentCase;
      if (state is DebtCasePaginatedLoaded) {
        final currentCases = (state as DebtCasePaginatedLoaded).cases;
        currentCase = currentCases.firstWhere(
          (debtCase) => debtCase.id == event.id,
          orElse: () => throw 'Case not found for deletion',
        );
      }

      if (currentCase == null) {
        throw 'Case not found for deletion';
      }

      await _apiService.deleteDebtCase(currentCase); // Pass the complete DebtCase object
      // Ricarica tutti i casi
      add(const LoadCasesPaginated());
    } catch (e) {
      emit(DebtCaseError('Failed to delete case: ${e.toString()}'));
    }
  }
}