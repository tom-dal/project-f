import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/api_service.dart';
import '../../models/cases_summary.dart';

// Events
abstract class CasesSummaryEvent extends Equatable {
  const CasesSummaryEvent();
  @override
  List<Object?> get props => [];
}

class LoadCasesSummary extends CasesSummaryEvent {}
class RefreshCasesSummary extends CasesSummaryEvent {}

// States
abstract class CasesSummaryState extends Equatable {
  const CasesSummaryState();
  @override
  List<Object?> get props => [];
}

class CasesSummaryInitial extends CasesSummaryState {}
class CasesSummaryLoading extends CasesSummaryState {}
class CasesSummaryLoaded extends CasesSummaryState {
  final CasesSummary summary;
  const CasesSummaryLoaded(this.summary);
  @override
  List<Object?> get props => [summary];
}
class CasesSummaryError extends CasesSummaryState {
  final String message;
  const CasesSummaryError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class CasesSummaryBloc extends Bloc<CasesSummaryEvent, CasesSummaryState> {
  final ApiService apiService;
  CasesSummaryBloc(this.apiService) : super(CasesSummaryInitial()) {
    on<LoadCasesSummary>(_load);
    on<RefreshCasesSummary>(_load);
  }

  Future<void> _load(
    CasesSummaryEvent event,
    Emitter<CasesSummaryState> emit,
  ) async {
    emit(CasesSummaryLoading());
    try {
      final data = await apiService.fetchCasesSummary();
      emit(CasesSummaryLoaded(data));
    } catch (e) {
      emit(CasesSummaryError(e.toString()));
    }
  }
}

