import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';
import '../../models/state_transition_config.dart';

// Events
abstract class StateTransitionsEvent extends Equatable { @override List<Object?> get props => []; }
class LoadStateTransitions extends StateTransitionsEvent {}
class EditStateTransitionDays extends StateTransitionsEvent { final String fromState; final int days; EditStateTransitionDays(this.fromState,this.days); @override List<Object?> get props => [fromState,days]; }
class ResetStateTransitions extends StateTransitionsEvent {}
class SaveStateTransitions extends StateTransitionsEvent {}
class RefreshStateTransitions extends StateTransitionsEvent {}

// States
abstract class StateTransitionsState extends Equatable { @override List<Object?> get props => []; }
class StateTransitionsInitial extends StateTransitionsState {}
class StateTransitionsLoading extends StateTransitionsState {}
class StateTransitionsLoaded extends StateTransitionsState { final List<StateTransitionConfigModel> current; final List<StateTransitionConfigModel> original; final bool saving; final String? error; StateTransitionsLoaded({required this.current, required this.original, this.saving=false, this.error}); bool get dirty => !_sameLists(original,current); @override List<Object?> get props => [current, original, saving, error]; StateTransitionsLoaded copy({List<StateTransitionConfigModel>? current, List<StateTransitionConfigModel>? original, bool? saving, String? error})=> StateTransitionsLoaded(current: current??this.current, original: original??this.original, saving: saving??this.saving, error: error); static bool _sameLists(List<StateTransitionConfigModel> a, List<StateTransitionConfigModel> b){ if(a.length!=b.length) return false; for(int i=0;i<a.length;i++){ if(a[i].fromStateString!=b[i].fromStateString || a[i].daysToTransition!=b[i].daysToTransition) return false; } return true; }}
class StateTransitionsError extends StateTransitionsState { final String message; StateTransitionsError(this.message); @override List<Object?> get props => [message]; }

class StateTransitionsBloc extends Bloc<StateTransitionsEvent, StateTransitionsState> {
  final ApiService apiService;
  StateTransitionsBloc(this.apiService): super(StateTransitionsInitial()){
    on<LoadStateTransitions>(_onLoad);
    on<RefreshStateTransitions>(_onLoad);
    on<EditStateTransitionDays>(_onEdit);
    on<ResetStateTransitions>(_onReset);
    on<SaveStateTransitions>(_onSave);
  }

  Future<void> _onLoad(StateTransitionsEvent event, Emitter<StateTransitionsState> emit) async {
    emit(StateTransitionsLoading());
    try {
      final list = await apiService.getStateTransitions();
      final originals = list.map((e)=>e.copy()).toList();
      emit(StateTransitionsLoaded(current: list, original: originals));
    } catch (e) {
      emit(StateTransitionsError(e.toString()));
    }
  }

  void _onEdit(EditStateTransitionDays event, Emitter<StateTransitionsState> emit){
    final s = state; if(s is! StateTransitionsLoaded) return;
    final updated = s.current.map((c){ if(c.fromStateString==event.fromState){ final copy = c.copy(); copy.daysToTransition = event.days; return copy; } return c; }).toList();
    emit(s.copy(current: updated));
  }

  void _onReset(ResetStateTransitions event, Emitter<StateTransitionsState> emit){
    final s = state; if(s is! StateTransitionsLoaded) return;
    final originals = s.original.map((e)=>e.copy()).toList();
    emit(StateTransitionsLoaded(current: originals.map((e)=>e.copy()).toList(), original: originals));
  }

  Future<void> _onSave(SaveStateTransitions event, Emitter<StateTransitionsState> emit) async {
    final s = state; if(s is! StateTransitionsLoaded) return;
    emit(s.copy(saving: true, error: null));
    try {
      final saved = await apiService.updateStateTransitions(s.current);
      final originals = saved.map((e)=>e.copy()).toList();
      emit(StateTransitionsLoaded(current: saved, original: originals));
    } catch (e) {
      emit(s.copy(saving:false, error: e.toString()));
    }
  }
}

