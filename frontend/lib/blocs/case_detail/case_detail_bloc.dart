import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/debt_case.dart';
import '../../models/case_state.dart';
import '../../models/installment.dart';
import '../../services/api_service.dart';

// EVENTS
abstract class CaseDetailEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCaseDetail extends CaseDetailEvent {
  final String caseId;
  LoadCaseDetail(this.caseId);
  @override
  List<Object?> get props => [caseId];
}

class EditDebtorName extends CaseDetailEvent { final String value; EditDebtorName(this.value); }
class EditOwedAmount extends CaseDetailEvent { final double value; EditOwedAmount(this.value); }
class EditState extends CaseDetailEvent { final CaseState value; EditState(this.value); }
class EditNextDeadline extends CaseDetailEvent { final DateTime? value; EditNextDeadline(this.value); }
class EditNotes extends CaseDetailEvent { final String? value; EditNotes(this.value); }
class EditOngoingNegotiations extends CaseDetailEvent { final bool value; EditOngoingNegotiations(this.value); }

class SaveCaseEdits extends CaseDetailEvent {}

class CreateInstallmentPlanEvent extends CaseDetailEvent {
  final int numberOfInstallments;
  final DateTime firstDueDate;
  final double installmentAmount;
  final int frequencyDays;
  CreateInstallmentPlanEvent({required this.numberOfInstallments, required this.firstDueDate, required this.installmentAmount, required this.frequencyDays});
}

class UpdateInstallmentLocal extends CaseDetailEvent {
  final String installmentId;
  final double? amount;
  final DateTime? dueDate;
  UpdateInstallmentLocal({required this.installmentId, this.amount, this.dueDate});
}

class SaveSingleInstallment extends CaseDetailEvent {
  final String installmentId;
  SaveSingleInstallment(this.installmentId);
}

class AddNewInstallmentPlaceholder extends CaseDetailEvent {}
class RemoveNewInstallmentPlaceholder extends CaseDetailEvent { final String tempId; RemoveNewInstallmentPlaceholder(this.tempId); }
class ApplyNewInstallmentsReplacePlan extends CaseDetailEvent {}
class DeleteInstallmentPlanEvent extends CaseDetailEvent {}
class DeleteCaseEvent extends CaseDetailEvent {}
class RegisterCasePayment extends CaseDetailEvent {
  final double amount;
  final DateTime paymentDate;
  RegisterCasePayment({required this.amount, required this.paymentDate});
  @override
  List<Object?> get props => [amount, paymentDate];
}

class RegisterInstallmentPayment extends CaseDetailEvent {
  final String installmentId;
  final double amount;
  final DateTime paymentDate;
  RegisterInstallmentPayment({required this.installmentId, required this.amount, required this.paymentDate});
  @override
  List<Object?> get props => [installmentId, amount, paymentDate];
}

// Nuovi eventi pagamenti per modalità modifica
class UpdatePaymentEvent extends CaseDetailEvent {
  final String paymentId;
  final double? amount;
  final DateTime? paymentDate;
  UpdatePaymentEvent({required this.paymentId, this.amount, this.paymentDate});
  @override
  List<Object?> get props => [paymentId, amount, paymentDate];
}
class DeletePaymentEvent extends CaseDetailEvent {
  final String paymentId;
  DeletePaymentEvent(this.paymentId);
  @override
  List<Object?> get props => [paymentId];
}

class ReplaceInstallmentPlanSimple extends CaseDetailEvent {
  final int numberOfInstallments;
  final DateTime firstDueDate;
  final double perInstallmentAmountFloor; // amount for each (remainder added to last)
  final int frequencyDays;
  final double total; // residuo totale
  ReplaceInstallmentPlanSimple({required this.numberOfInstallments, required this.firstDueDate, required this.perInstallmentAmountFloor, required this.frequencyDays, required this.total});
  @override
  List<Object?> get props => [numberOfInstallments, firstDueDate, perInstallmentAmountFloor, frequencyDays, total];
}

class ResetCaseEdits extends CaseDetailEvent {}

// STATES
abstract class CaseDetailState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CaseDetailLoading extends CaseDetailState {}
class CaseDetailDeleted extends CaseDetailState {}
class CaseDetailError extends CaseDetailState { final String message; CaseDetailError(this.message); @override List<Object?> get props => [message]; }

class CaseDetailLoaded extends CaseDetailState {
  final DebtCase caseData;
  final String debtorName;
  final double owedAmount;
  final CaseState state;
  final DateTime? nextDeadline;
  final String? notes;
  final bool ongoingNegotiations;
  final bool dirty;
  final bool saving;
  final Map<String, Installment> localInstallments; // keyed by id or temp
  final Set<String> installmentDirty; // ids dirty
  final bool replacingPlan;
  final String? error;
  final String? successMessage;

  CaseDetailLoaded({
    required this.caseData,
    required this.debtorName,
    required this.owedAmount,
    required this.state,
    required this.nextDeadline,
    required this.notes,
    required this.ongoingNegotiations,
    required this.dirty,
    required this.saving,
    required this.localInstallments,
    required this.installmentDirty,
    required this.replacingPlan,
    this.error,
    this.successMessage,
  });

  CaseDetailLoaded copyWith({
    DebtCase? caseData,
    String? debtorName,
    double? owedAmount,
    CaseState? state,
    DateTime? nextDeadline,
    String? notes,
    bool? ongoingNegotiations,
    bool? dirty,
    bool? saving,
    Map<String, Installment>? localInstallments,
    Set<String>? installmentDirty,
    bool? replacingPlan,
    String? error,
    String? successMessage,
  }) => CaseDetailLoaded(
    caseData: caseData ?? this.caseData,
    debtorName: debtorName ?? this.debtorName,
    owedAmount: owedAmount ?? this.owedAmount,
    state: state ?? this.state,
    nextDeadline: nextDeadline ?? this.nextDeadline,
    notes: notes == null ? this.notes : notes,
    ongoingNegotiations: ongoingNegotiations ?? this.ongoingNegotiations,
    dirty: dirty ?? this.dirty,
    saving: saving ?? this.saving,
    localInstallments: localInstallments ?? this.localInstallments,
    installmentDirty: installmentDirty ?? this.installmentDirty,
    replacingPlan: replacingPlan ?? this.replacingPlan,
    error: error,
    successMessage: successMessage,
  );

  @override
  List<Object?> get props => [caseData.id, debtorName, owedAmount, state, nextDeadline, notes, ongoingNegotiations, dirty, saving, localInstallments, installmentDirty, replacingPlan, error, successMessage];
}

class CaseDetailBloc extends Bloc<CaseDetailEvent, CaseDetailState> {
  final ApiService api;
  CaseDetailBloc(this.api) : super(CaseDetailLoading()) {
    on<LoadCaseDetail>(_onLoad);
    on<EditDebtorName>((e, emit)=>_editField(emit, debtorName: e.value));
    on<EditOwedAmount>((e, emit)=>_editField(emit, owedAmount: e.value));
    on<EditState>((e, emit)=>_editField(emit, state: e.value));
    on<EditNextDeadline>((e, emit)=>_editField(emit, nextDeadline: e.value));
    on<EditNotes>((e, emit)=>_editField(emit, notes: e.value));
    on<EditOngoingNegotiations>((e, emit)=>_editField(emit, ongoingNegotiations: e.value));
    on<SaveCaseEdits>(_onSaveCase);
    on<CreateInstallmentPlanEvent>(_onCreatePlan);
    on<UpdateInstallmentLocal>(_onUpdateInstallmentLocal);
    on<SaveSingleInstallment>(_onSaveSingleInstallment);
    on<AddNewInstallmentPlaceholder>(_onAddNewPlaceholder);
    on<RemoveNewInstallmentPlaceholder>(_onRemovePlaceholder);
    on<ApplyNewInstallmentsReplacePlan>(_onReplacePlan);
    on<DeleteInstallmentPlanEvent>(_onDeletePlan);
    on<DeleteCaseEvent>(_onDeleteCase);
    on<RegisterCasePayment>(_onRegisterPayment);
    on<RegisterInstallmentPayment>(_onRegisterInstallmentPayment);
    on<ResetCaseEdits>(_onResetCaseEdits);
    on<UpdatePaymentEvent>(_onUpdatePayment);
    on<DeletePaymentEvent>(_onDeletePayment);
    on<ReplaceInstallmentPlanSimple>(_onReplacePlanSimple);
  }

  Future<void> _onLoad(LoadCaseDetail e, Emitter<CaseDetailState> emit) async {
    emit(CaseDetailLoading());
    try {
      final data = await api.getCaseById(e.caseId);
      final map = <String, Installment>{ for (final inst in (data.installments ?? [])) inst.id : inst };
      emit(CaseDetailLoaded(
        caseData: data,
        debtorName: data.debtorName,
        owedAmount: data.owedAmount,
        state: data.state,
        nextDeadline: data.nextDeadlineDate,
        notes: data.notes,
        ongoingNegotiations: data.ongoingNegotiations ?? false,
        dirty: false,
        saving: false,
        localInstallments: map,
        installmentDirty: {},
        replacingPlan: false,
        successMessage: null,
      ));
    } catch (ex) {
      emit(CaseDetailError(ex.toString()));
    }
  }

  void _editField(Emitter<CaseDetailState> emit,{String? debtorName,double? owedAmount,CaseState? state,DateTime? nextDeadline,String? notes,bool? ongoingNegotiations}){
    final s = this.state;
    if (s is! CaseDetailLoaded) return;
    final newDebtor = debtorName ?? s.debtorName;
    final newOwed = owedAmount ?? s.owedAmount;
    final newState = state ?? s.state;
    final newDeadline = nextDeadline ?? s.nextDeadline;
    final newNotes = (notes == null) ? s.notes : notes; // permette null esplicito
    final newNegotiations = ongoingNegotiations ?? s.ongoingNegotiations;
    final dirty = newDebtor != s.caseData.debtorName ||
      newOwed != s.caseData.owedAmount ||
      newState != s.caseData.state ||
      newDeadline != s.caseData.nextDeadlineDate ||
      (newNotes ?? '') != (s.caseData.notes ?? '') ||
      newNegotiations != (s.caseData.ongoingNegotiations ?? false);
    print('[DEBUG] Edit field: dirty=$dirty, debtor=$newDebtor, owed=$newOwed, state=$newState, deadline=$newDeadline, notes=$newNotes, negotiations=$newNegotiations');
    emit(s.copyWith(
      debtorName: newDebtor,
      owedAmount: newOwed,
      state: newState,
      nextDeadline: newDeadline,
      notes: newNotes,
      ongoingNegotiations: newNegotiations,
      dirty: dirty,
    ));
  }

  Future<void> _onSaveCase(SaveCaseEdits e, Emitter<CaseDetailState> emit) async {
    final s = state;
    if (s is! CaseDetailLoaded) return;
    print('[DEBUG] SaveCaseEdits received. dirty=${s.dirty}');
    emit(s.copyWith(saving: true, error: null));
    try {
      final bool notesChanged = s.notes != s.caseData.notes;
      final bool clearingNotes = notesChanged && (s.notes == null || s.notes!.isEmpty);
      final updated = await api.updateDebtCase(
        debtCase: s.caseData,
        debtorName: s.debtorName != s.caseData.debtorName ? s.debtorName : null,
        owedAmount: s.owedAmount != s.caseData.owedAmount ? s.owedAmount : null,
        currentState: s.state != s.caseData.state ? s.state : null,
        nextDeadlineDate: s.nextDeadline != s.caseData.nextDeadlineDate ? s.nextDeadline : null,
        ongoingNegotiations: s.ongoingNegotiations != (s.caseData.ongoingNegotiations ?? false) ? s.ongoingNegotiations : null,
        notes: (notesChanged && !clearingNotes) ? s.notes : null,
        clearNotes: clearingNotes ? true : null,
      );
      final map = <String, Installment>{ for (final inst in (updated.installments ?? [])) inst.id : inst };
      print('[DEBUG] SaveCaseEdits success.');
      emit(CaseDetailLoaded(
        caseData: updated,
        debtorName: updated.debtorName,
        owedAmount: updated.owedAmount,
        state: updated.state,
        nextDeadline: updated.nextDeadlineDate,
        notes: updated.notes,
        ongoingNegotiations: updated.ongoingNegotiations ?? false,
        dirty: false,
        saving: false,
        localInstallments: map,
        installmentDirty: {},
        replacingPlan: false,
        successMessage: 'Modifiche salvate',
      ));
    } catch (ex) {
      print('[DEBUG] SaveCaseEdits error: $ex');
      emit(s.copyWith(saving:false,error: ex.toString()));
    }
  }

  Future<void> _onCreatePlan(CreateInstallmentPlanEvent e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving:true,error:null));
    try {
      await api.createInstallmentPlan(
        caseId: s.caseData.id,
        numberOfInstallments: e.numberOfInstallments,
        firstInstallmentDueDate: e.firstDueDate,
        installmentAmount: e.installmentAmount,
        frequencyDays: e.frequencyDays,
      );
      add(LoadCaseDetail(s.caseData.id));
    } catch(ex){
      emit(s.copyWith(saving:false,error: ex.toString()));
    }
  }

  void _onUpdateInstallmentLocal(UpdateInstallmentLocal e, Emitter<CaseDetailState> emit){
    final s = state; if (s is! CaseDetailLoaded) return;
    final map = Map<String,Installment>.from(s.localInstallments);
    final inst = map[e.installmentId];
    if (inst == null) return;
    map[e.installmentId] = Installment(
      id: inst.id,
      debtCaseId: inst.debtCaseId,
      installmentNumber: inst.installmentNumber,
      amount: e.amount ?? inst.amount,
      dueDate: e.dueDate ?? inst.dueDate,
      paid: inst.paid,
      paidDate: inst.paidDate,
      paidAmount: inst.paidAmount,
      createdDate: inst.createdDate,
      lastModifiedDate: inst.lastModifiedDate,
    );
    final dirtySet = Set<String>.from(s.installmentDirty)..add(e.installmentId);
    emit(s.copyWith(localInstallments: map, installmentDirty: dirtySet));
  }

  Future<void> _onSaveSingleInstallment(SaveSingleInstallment e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    final inst = s.localInstallments[e.installmentId]; if (inst == null) return;
    emit(s.copyWith(saving:true,error:null));
    try {
      await api.updateSingleInstallment(caseId: s.caseData.id, installmentId: inst.id, amount: inst.amount, dueDate: inst.dueDate);
      add(LoadCaseDetail(s.caseData.id));
    } catch(ex){
      emit(s.copyWith(saving:false,error: ex.toString()));
    }
  }

  void _onAddNewPlaceholder(AddNewInstallmentPlaceholder e, Emitter<CaseDetailState> emit){
    final s = state; if (s is! CaseDetailLoaded) return;
    // Placeholder handled by replacing plan: add temp id starting with 'tmp-'
    final map = Map<String,Installment>.from(s.localInstallments);
    final tempId = 'tmp-${DateTime.now().microsecondsSinceEpoch}';
    final nextNumber = map.length + 1;
    final dueDateBase = map.values.isEmpty ? DateTime.now().add(const Duration(days:30)) : map.values.map((i)=>i.dueDate).reduce((a,b)=> a.isAfter(b)?a:b).add(const Duration(days:30));
    map[tempId] = Installment(id: tempId, debtCaseId: s.caseData.id, installmentNumber: nextNumber, amount: 0.01, dueDate: dueDateBase);
    emit(s.copyWith(localInstallments: map, replacingPlan: true));
  }

  void _onRemovePlaceholder(RemoveNewInstallmentPlaceholder e, Emitter<CaseDetailState> emit){
    final s = state; if (s is! CaseDetailLoaded) return;
    if(!e.tempId.startsWith('tmp-')) return;
    final map = Map<String,Installment>.from(s.localInstallments)..remove(e.tempId);
    emit(s.copyWith(localInstallments: map, replacingPlan: map.keys.any((k)=>k.startsWith('tmp-'))));
  }

  Future<void> _onReplacePlan(ApplyNewInstallmentsReplacePlan e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving:true,error:null));
    try {
      // Only allowed if no paid installments (backend will validate). Build list sorted by dueDate.
      final list = s.localInstallments.values.toList()..sort((a,b)=>a.dueDate.compareTo(b.dueDate));
      final payload = list.map((i)=>{'amount': i.amount, 'dueDate': i.dueDate.toIso8601String()}).toList();
      await api.replaceInstallmentPlan(caseId: s.caseData.id, installments: payload);
      add(LoadCaseDetail(s.caseData.id));
    } catch(ex){
      emit(s.copyWith(saving:false,error: ex.toString()));
    }
  }

  Future<void> _onDeletePlan(DeleteInstallmentPlanEvent e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving:true,error:null));
    try { await api.deleteInstallmentPlan(s.caseData.id); add(LoadCaseDetail(s.caseData.id)); }
    catch(ex){ emit(s.copyWith(saving:false,error: ex.toString())); }
  }

  Future<void> _onDeleteCase(DeleteCaseEvent e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    try { await api.deleteDebtCase(s.caseData); emit(CaseDetailDeleted()); }
    catch(ex){ emit(CaseDetailError(ex.toString())); }
  }

  Future<void> _onRegisterPayment(RegisterCasePayment e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving: true, error: null, successMessage: null));
    try {
      await api.registerPayment(caseId: s.caseData.id, amount: e.amount, paymentDate: e.paymentDate);
      // Reload updated case directly
      final data = await api.getCaseById(s.caseData.id);
      final map = <String, Installment>{ for (final inst in (data.installments ?? [])) inst.id : inst };
      emit(CaseDetailLoaded(
        caseData: data,
        debtorName: data.debtorName,
        owedAmount: data.owedAmount,
        state: data.state,
        nextDeadline: data.nextDeadlineDate,
        notes: data.notes,
        ongoingNegotiations: data.ongoingNegotiations ?? false,
        dirty: false,
        saving: false,
        localInstallments: map,
        installmentDirty: {},
        replacingPlan: false,
        successMessage: 'Pagamento registrato',
      ));
    } catch (ex) {
      emit(s.copyWith(saving: false, error: ex.toString(), successMessage: null));
    }
  }

  Future<void> _onRegisterInstallmentPayment(RegisterInstallmentPayment e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving: true, error: null, successMessage: null));
    try {
      await api.registerInstallmentPayment(
        caseId: s.caseData.id,
        installmentId: e.installmentId,
        amount: e.amount,
        paymentDate: e.paymentDate,
      );
      final data = await api.getCaseById(s.caseData.id);
      final map = <String, Installment>{ for (final inst in (data.installments ?? [])) inst.id : inst };
      emit(CaseDetailLoaded(
        caseData: data,
        debtorName: data.debtorName,
        owedAmount: data.owedAmount,
        state: data.state,
        nextDeadline: data.nextDeadlineDate,
        notes: data.notes,
        ongoingNegotiations: data.ongoingNegotiations ?? false,
        dirty: false,
        saving: false,
        localInstallments: map,
        installmentDirty: {},
        replacingPlan: false,
        successMessage: 'Pagamento rata registrato',
      ));
    } catch (ex) {
      emit(s.copyWith(saving: false, error: ex.toString(), successMessage: null));
    }
  }

  Future<void> _onUpdatePayment(UpdatePaymentEvent e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving: true, error: null, successMessage: null));
    try {
      await api.updatePayment(caseId: s.caseData.id, paymentId: e.paymentId, amount: e.amount, paymentDate: e.paymentDate);
      final data = await api.getCaseById(s.caseData.id);
      final map = <String, Installment>{ for (final inst in (data.installments ?? [])) inst.id : inst };
      emit(CaseDetailLoaded(
        caseData: data,
        debtorName: data.debtorName,
        owedAmount: data.owedAmount,
        state: data.state,
        nextDeadline: data.nextDeadlineDate,
        notes: data.notes,
        ongoingNegotiations: data.ongoingNegotiations ?? false,
        dirty: false,
        saving: false,
        localInstallments: map,
        installmentDirty: {},
        replacingPlan: false,
        successMessage: 'Pagamento aggiornato',
      ));
    } catch (ex) {
      emit(s.copyWith(saving: false, error: ex.toString(), successMessage: null));
    }
  }

  Future<void> _onDeletePayment(DeletePaymentEvent e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving: true, error: null, successMessage: null));
    try {
      await api.deletePayment(caseId: s.caseData.id, paymentId: e.paymentId);
      final data = await api.getCaseById(s.caseData.id);
      final map = <String, Installment>{ for (final inst in (data.installments ?? [])) inst.id : inst };
      emit(CaseDetailLoaded(
        caseData: data,
        debtorName: data.debtorName,
        owedAmount: data.owedAmount,
        state: data.state,
        nextDeadline: data.nextDeadlineDate,
        notes: data.notes,
        ongoingNegotiations: data.ongoingNegotiations ?? false,
        dirty: false,
        saving: false,
        localInstallments: map,
        installmentDirty: {},
        replacingPlan: false,
        successMessage: 'Pagamento eliminato',
      ));
    } catch (ex) {
      emit(s.copyWith(saving: false, error: ex.toString(), successMessage: null));
    }
  }

  Future<void> _onReplacePlanSimple(ReplaceInstallmentPlanSimple e, Emitter<CaseDetailState> emit) async {
    final s = state; if (s is! CaseDetailLoaded) return;
    emit(s.copyWith(saving:true,error:null,successMessage:null));
    try {
      final list = <Map<String,dynamic>>[];
      double distributed = 0.0;
      for (int i=0;i<e.numberOfInstallments;i++){
        double amount;
        if (i == e.numberOfInstallments -1) {
          amount = double.parse((e.total - distributed).toStringAsFixed(2));
        } else {
            amount = e.perInstallmentAmountFloor;
            distributed += amount;
        }
        final dueDate = e.firstDueDate.add(Duration(days: e.frequencyDays * i));
        list.add({'amount': amount, 'dueDate': dueDate.toIso8601String()});
      }
      await api.replaceInstallmentPlan(caseId: s.caseData.id, installments: list);
      add(LoadCaseDetail(s.caseData.id));
    } catch(ex){
      emit(s.copyWith(saving:false,error: ex.toString()));
    }
  }

  Future<void> _onResetCaseEdits(ResetCaseEdits e, Emitter<CaseDetailState> emit) async {
    final s = state;
    if (s is! CaseDetailLoaded) return;
    if (s.saving) return;
    emit(s.copyWith(
      debtorName: s.caseData.debtorName,
      owedAmount: s.caseData.owedAmount,
      state: s.caseData.state,
      nextDeadline: s.caseData.nextDeadlineDate,
      notes: s.caseData.notes,
      ongoingNegotiations: s.caseData.ongoingNegotiations ?? false,
      dirty: false,
      error: null,
      successMessage: null,
    ));
  }
}
