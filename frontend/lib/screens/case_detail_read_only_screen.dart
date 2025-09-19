import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../models/installment.dart';
import '../blocs/case_detail/case_detail_bloc.dart';
import '../services/api_service.dart';
import '../utils/amount_validator.dart';
import '../utils/italian_date_picker.dart';
import '../utils/date_formats.dart';
import '../utils/installment_rounding.dart';
import 'case_detail_edit_screen.dart';
import '../widgets/replace_installment_plan_dialog.dart';

class CaseDetailReadOnlyScreen extends StatelessWidget {
  final String caseId;
  final DebtCase initialCase;
  const CaseDetailReadOnlyScreen({super.key, required this.caseId, required this.initialCase});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context, listen: false);
    return BlocProvider(
      create: (_) => CaseDetailBloc(api)..add(LoadCaseDetail(caseId)),
      child: const _CaseDetailReadOnlyView(),
    );
  }
}

class _CaseDetailReadOnlyView extends StatefulWidget {
  const _CaseDetailReadOnlyView();
  @override
  State<_CaseDetailReadOnlyView> createState() => _CaseDetailReadOnlyViewState();
}

class _CaseDetailReadOnlyViewState extends State<_CaseDetailReadOnlyView> {
  String? _lastSuccess;
  String? _lastError;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaseDetailBloc, CaseDetailState>(
      listener: (context, state){
        if (state is CaseDetailLoaded) {
          if (state.successMessage != null && state.successMessage != _lastSuccess) {
            _lastSuccess = state.successMessage;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.successMessage!), behavior: SnackBarBehavior.floating),
            );
          }
          if (state.error != null && state.error != _lastError) {
            _lastError = state.error;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent),
            );
          }
        }
      },
      builder: (context, state) {
        if (state is CaseDetailLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dettaglio Pratica')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state is CaseDetailError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dettaglio Pratica')),
            body: Center(child: Text('Errore: ${state.message}')),
          );
        }
        if (state is CaseDetailDeleted) {
          return const Scaffold();
        }
        final s = state as CaseDetailLoaded;
        return Scaffold(
          appBar: AppBar(
            title: Text('Pratica ${s.caseData.id.substring(0, 6)}'),
            actions: [
              TextButton(
                onPressed: () => _openEdit(context, s),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 6),
                    Text('Modifica'),
                  ],
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 980; // threshold for two column
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1300),
                    child: wide
                      ? _TwoColumnBody(state: s, openRegisterPayment: _openRegisterPaymentDialog, openEdit: ()=>_openEdit(context, s), openRegisterInstallmentPayment: _openRegisterInstallmentPaymentDialog, onCreatePlan: ()=>_openCreateInstallmentPlanDialog(s))
                      : _SingleColumnBody(state: s, openRegisterPayment: _openRegisterPaymentDialog, openEdit: ()=>_openEdit(context, s), openRegisterInstallmentPayment: _openRegisterInstallmentPaymentDialog, onCreatePlan: ()=>_openCreateInstallmentPlanDialog(s)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, CaseDetailLoaded s) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDetailEditScreen(caseId: s.caseData.id, initialCase: s.caseData),
      ),
    );
    debugPrint('[READONLY] Returned from edit with result: $result');
    bool shouldRefresh = false;
    if (result == 'refresh') shouldRefresh = true;
    else if (result is bool && result) shouldRefresh = true;
    else if (result is Map && (result['refresh'] == true)) shouldRefresh = true;
    if (shouldRefresh) {
      context.read<CaseDetailBloc>().add(LoadCaseDetail(s.caseData.id));
    }
  }

  void _openRegisterPaymentDialog(CaseDetailLoaded s) {
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    if (residuo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun importo residuo da registrare')),
      );
      return;
    }
    final amountCtrl = TextEditingController(
      text: NumberFormat('#,##0.00', 'it_IT').format(residuo).replaceAll('\u00A0',''),
    );
    DateTime selectedDate = DateTime.now();
    bool pagamentoParziale = false; // USER PREFERENCE: partial payment toggle activates manual amount entry
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

          Future<void> _pickDate() async {
            final picked = await pickItalianDate(
              ctx,
              initialDate: selectedDate,
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime(DateTime.now().year + 5),
              helpText: 'Data pagamento',
            );
            if (picked != null) {
              setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
            }
          }

          String? _amountValidator(String? v) {
            if (!pagamentoParziale) return null; // full payment, skip manual validation
            final res = normalizeFlexibleItalianAmount(v ?? '');
            if (!res.isValid) return res.error;
            final value = res.value!;
            if (value <= 0) return 'Importo non valido';
            if (value > residuo + 0.0001) return 'Importo superiore al residuo';
            return null;
          }

          void _submit() {
            if (pagamentoParziale) {
              if (!(formKey.currentState?.validate() ?? false)) return;
            }
            double amount;
            if (pagamentoParziale) {
              final res = normalizeFlexibleItalianAmount(amountCtrl.text);
              if (!res.isValid) return; // safety
              amount = res.value!;
            } else {
              amount = residuo; // full payment
            }
            context.read<CaseDetailBloc>().add(
              RegisterCasePayment(amount: amount, paymentDate: selectedDate),
            );
            Navigator.pop(ctx);
          }

          final base = Theme.of(context).colorScheme;
          final inputDecoration = InputDecoration(
            labelText: 'Importo (€)',
            filled: true,
            fillColor: pagamentoParziale ? base.surface : base.surface.withAlpha((0.5 * 255).round()),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: base.outline.withAlpha((0.30 * 255).round()))),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: base.outline.withAlpha((0.15 * 255).round()))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            title: Text('Registra pagamento', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amountCtrl,
                            enabled: pagamentoParziale,
                            validator: _amountValidator,
                            decoration: inputDecoration,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                              FilteringTextInputFormatter.deny(RegExp(r'([.,].*[.,])')),
                              TextInputFormatter.withFunction((oldValue, newValue) {
                                final parts = newValue.text.split(RegExp(r'[.,]'));
                                if (parts.length == 2 && parts[1].length > 2) return oldValue; return newValue;
                              })
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: pagamentoParziale,
                      onChanged: (v) {
                        setState(() {
                          pagamentoParziale = v ?? false;
                          if (!pagamentoParziale) {
                            // reset to full amount
                            amountCtrl.text = NumberFormat('#,##0.00', 'it_IT').format(residuo).replaceAll('\u00A0','');
                          } else {
                            amountCtrl.selection = TextSelection(baseOffset: 0, extentOffset: amountCtrl.text.length);
                          }
                        });
                      },
                      title: const Text('Pagamento parziale'),
                      subtitle: pagamentoParziale ? Text('Residuo massimo: € ${NumberFormat('#,##0.00', 'it_IT').format(residuo)}', style: const TextStyle(fontSize: 12)) : null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 12),
                    // Data pagamento picker styled similar to pills
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data pagamento',
                          filled: true,
                          fillColor: base.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: base.outline.withAlpha((0.30 * 255).round()))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: base.outline.withAlpha((0.30 * 255).round()))),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(_fmtDate(selectedDate), style: const TextStyle(fontWeight: FontWeight.w500))),
                            const Icon(Icons.date_range, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _submit();
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Conferma'),
              ),
            ],
          );
        });
      },
    );
  }

  // Apertura dialog creazione piano rateale
  void _openCreateInstallmentPlanDialog(CaseDetailLoaded s) {
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    if (residuo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nessun importo residuo su cui creare un piano rateale')));
      return;
    }
    final installmentsCtrl = TextEditingController(text: '2');
    final frequencyCtrl = TextEditingController(text: '30');
    final formKey = GlobalKey<FormState>();
    int parsedInstallments = 2;
    int parsedFrequency = 30;
    DateTime firstDueDate = DateTime.now().add(Duration(days: parsedFrequency));
    bool userPickedDate = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx){
        return StatefulBuilder(builder: (ctx, setState){
          final fmt = NumberFormat('#,##0.00', 'it_IT');
          void recalc({bool fromFrequency=false}){
            parsedInstallments = int.tryParse(installmentsCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            parsedFrequency = int.tryParse(frequencyCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (parsedFrequency <= 0) parsedFrequency = 1;
            if (!userPickedDate && (fromFrequency || parsedFrequency != 0)) {
              firstDueDate = DateTime.now().add(Duration(days: parsedFrequency));
            }
            setState((){});
          }

          Future<void> _pickDate() async {
            final picked = await pickItalianDate(
              ctx,
              initialDate: firstDueDate,
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime(DateTime.now().year + 5),
              helpText: 'Prima scadenza',
            );
            if (picked != null) {
              setState((){ firstDueDate = DateTime(picked.year, picked.month, picked.day); userPickedDate = true; });
            }
          }

          // Nuova logica: rate intere (floor) + ultima con resto decimale
          final perInstallment = perInstallmentIntFloor(residuo, parsedInstallments);
          final lastAmount = lastInstallmentWithRemainder(residuo, perInstallment, parsedInstallments);
          final remainder = parsedInstallments > 1 ? double.parse((lastAmount - perInstallment).toStringAsFixed(2)) : 0.0; // differenza rispetto alle altre

          String? _validate(){
            if (parsedInstallments < 2) return 'Numero di rate minimo 2';
            if (parsedInstallments > 240) return 'Numero di rate troppo elevato';
            if (perInstallment < 1 && residuo >= 2) return 'Importo per rata troppo basso (aumenta numero rate o riduci)';
            if (parsedFrequency < 1) return 'Giorni tra rate minimo 1';
            if (parsedFrequency > 365) return 'Giorni tra rate massimo 365';
            return null;
          }

          void _submit(){
            final err = _validate();
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              return;
            }
            context.read<CaseDetailBloc>().add(CreateInstallmentPlanEvent(
              numberOfInstallments: parsedInstallments,
              firstDueDate: firstDueDate,
              installmentAmount: perInstallment, // le prime n-1 rate
              frequencyDays: parsedFrequency,
            ));
            Navigator.pop(ctx);
          }

          final base = Theme.of(context).colorScheme;
          InputDecoration fieldDec(String label) => InputDecoration(
            labelText: label,
            filled: true,
            fillColor: base.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: base.outline.withAlpha((0.30*255).round()))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          );

          String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

          final validationError = _validate();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Crea piano rateale', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Importo residuo: € ${fmt.format(residuo)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: installmentsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: fieldDec('Numero rate'),
                            onChanged: (_)=>recalc(),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: frequencyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: fieldDec('Giorni tra rate'),
                            onChanged: (_)=>recalc(fromFrequency:true),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Prima scadenza',
                          filled: true,
                          fillColor: base.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: base.outline.withAlpha((0.30 * 255).round()))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: base.outline.withAlpha((0.30 * 255).round()))),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(_fmtDate(firstDueDate), style: const TextStyle(fontWeight: FontWeight.w500))),
                            const Icon(Icons.date_range, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Anteprima', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height:8),
                    Builder(builder: (_){
                      if (parsedInstallments < 2) return const Text('Inserisci almeno 2 rate', style: TextStyle(color: Colors.black54));
                      if (perInstallment < 0.01) return const Text('Importo rata risultante troppo basso', style: TextStyle(color: Colors.redAccent));
                      final coveredFirst = perInstallment * (parsedInstallments - 1);
                      final totalCheck = coveredFirst + lastAmount;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...(parsedInstallments == 2 ?
                          [Text('Importo prima rata: € ${fmt.format(perInstallment)}'),
                            Text('Importo seconda rata: € ${fmt.format(lastAmount)}')] :
                          [Text('Importo rate: € ${fmt.format(perInstallment)}'),
                          Text('Ultima rata: € ${fmt.format(lastAmount)}')]),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Dopo la creazione sarà possibile modificare manualmente le scadenze delle singole rate', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    if (validationError != null) Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(validationError, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton.icon(
                onPressed: validationError == null ? _submit : null,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Crea piano'),
              ),
            ],
          );
        });
      }
    );
  }

  void _openRegisterInstallmentPaymentDialog(Installment inst, CaseDetailLoaded s){
    if (inst.paid == true) return; // safeguard
    final amount = inst.amount;
    DateTime selectedDate = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx){
        return StatefulBuilder(builder: (ctx,setState){
          String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
          Future<void> _pickDate() async {
            final picked = await pickItalianDate(
              ctx,
              initialDate: selectedDate,
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime(DateTime.now().year + 5),
              helpText: 'Data pagamento rata',
            );
            if (picked != null) setState(()=> selectedDate = DateTime(picked.year, picked.month, picked.day));
          }
          void _submit(){
            context.read<CaseDetailBloc>().add(RegisterInstallmentPayment(
              installmentId: inst.id,
              amount: amount,
              paymentDate: selectedDate,
            ));
            Navigator.pop(ctx);
          }
          final base = Theme.of(context).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Registra pagamento rata #${inst.installmentNumber}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    enabled: false,
                    initialValue: NumberFormat('#,##0.00','it_IT').format(amount),
                    decoration: InputDecoration(
                      labelText: 'Importo rata (€)',
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: base.outline.withAlpha((0.20*255).round()))),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data pagamento',
                        filled: true,
                        fillColor: base.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: base.outline.withAlpha((0.30 * 255).round()))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: base.outline.withAlpha((0.30 * 255).round()))),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(_fmtDate(selectedDate), style: const TextStyle(fontWeight: FontWeight.w500))),
                          const Icon(Icons.date_range, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.check, size: 18), label: const Text('Conferma')),
            ],
          );
        });
      }
    );
  }

  void _openReplacePlanDialog(CaseDetailLoaded s) {
    // Mostra dialog sostituzione piano con stessa logica di arrotondamento interi + resto
    final list = s.localInstallments.values.toList();
    if (list.isEmpty) return; // safety
    list.sort((a,b)=>a.installmentNumber.compareTo(b.installmentNumber));
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    showReplaceInstallmentPlanDialog(
      context: context,
      residuo: residuo,
      initialInstallments: list.length,
      initialFirstDueDate: list.first.dueDate,
      onConfirm: ({required int numberOfInstallments, required DateTime firstDueDate, required double perInstallmentAmountFloor, required int frequencyDays, required double total}) {
        context.read<CaseDetailBloc>().add(ReplaceInstallmentPlanSimple(
          numberOfInstallments: numberOfInstallments,
          firstDueDate: firstDueDate,
            perInstallmentAmountFloor: perInstallmentAmountFloor,
            frequencyDays: frequencyDays,
            total: total,
        ));
      },
    );
  }
}

class _TwoColumnBody extends StatelessWidget {
  final CaseDetailLoaded state;
  final void Function(CaseDetailLoaded) openRegisterPayment;
  final VoidCallback openEdit;
  final void Function(Installment, CaseDetailLoaded) openRegisterInstallmentPayment;
  final void Function() onCreatePlan; // nuova callback
  const _TwoColumnBody({required this.state, required this.openRegisterPayment, required this.openEdit, required this.openRegisterInstallmentPayment, required this.onCreatePlan});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderSection(s: state),
              const SizedBox(height: 28),
              _LeftSectionCard(
                title: 'Dati pratica',
                child: _FieldsGrid(s: state, twoColumns: true),
              ),
              const SizedBox(height: 28),
              _LeftSectionCard(
                title: 'Note',
                child: _NotesSection(notes: state.notes),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // RIGHT
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaymentsSection(s: state, onRegisterPayment: openRegisterPayment),
              const SizedBox(height: 28),
              _InstallmentsSideCard(s: state, openEdit: openEdit, openRegisterInstallmentPayment: (inst)=>openRegisterInstallmentPayment(inst, state), onCreatePlan: onCreatePlan),
            ],
          ),
        )
      ],
    );
  }
}

class _SingleColumnBody extends StatelessWidget {
  final CaseDetailLoaded state;
  final void Function(CaseDetailLoaded) openRegisterPayment;
  final VoidCallback openEdit;
  final void Function(Installment, CaseDetailLoaded) openRegisterInstallmentPayment;
  final void Function() onCreatePlan; // nuova callback
  const _SingleColumnBody({required this.state, required this.openRegisterPayment, required this.openEdit, required this.openRegisterInstallmentPayment, required this.onCreatePlan});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderSection(s: state),
        const SizedBox(height: 24),
        _PaymentsSection(s: state, onRegisterPayment: openRegisterPayment),
        const SizedBox(height: 24),
        _InstallmentsSideCard(s: state, openEdit: openEdit, openRegisterInstallmentPayment: (inst)=>openRegisterInstallmentPayment(inst, state), onCreatePlan: onCreatePlan),
        const SizedBox(height: 24),
        _LeftSectionCard(title: 'Dati pratica', child: _FieldsGrid(s: state, twoColumns: false)),
        const SizedBox(height: 24),
        _LeftSectionCard(title: 'Note', child: _NotesSection(notes: state.notes)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LeftSectionCard extends StatelessWidget {
  final String title; final Widget child;
  const _LeftSectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final CaseDetailLoaded s;
  const _HeaderSection({required this.s});
  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat('#,##0.00', 'it_IT');
    final base = Theme.of(context).colorScheme;
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    final hasPayments = (s.caseData.totalPaidAmount ?? 0) > 0.0;
    final isCompletata = s.state == CaseState.completata;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.debtorName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StateChip(state: s.state),
                    if (s.ongoingNegotiations) ...[
                      const SizedBox(width: 12),
                      _NegotiationChip(),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 40,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Importo dovuto', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height:4),
                        Text('€ ${fmtCurrency.format(s.owedAmount)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
                      ],
                    ),
                    if (!isCompletata && hasPayments) Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Debito residuo', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height:4),
                        Text('€ ${fmtCurrency.format(residuo)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prossima scadenza', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height:4),
              Text(s.nextDeadline != null ? _fmtDate(s.nextDeadline!) : '-', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
            ],
          ),
        ],
      ),
    );
  }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PaymentsSection extends StatelessWidget {
  final CaseDetailLoaded s;
  final void Function(CaseDetailLoaded) onRegisterPayment;
  const _PaymentsSection({required this.s, required this.onRegisterPayment});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    final payments = _extractPayments();
    final fmt = NumberFormat('#,##0.00', 'it_IT');
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    final canRegister = (s.caseData.hasInstallmentPlan != true) && residuo > 0.0 && s.state != CaseState.completata;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Pagamenti', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
              if (canRegister) OutlinedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Registra pagamento'),

                onPressed: ()=>onRegisterPayment(s),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty) const Text('Nessun pagamento registrato', style: TextStyle(color: Colors.black54))
          else Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (s.caseData.totalPaidAmount!=null) Text('Totale pagato: € ${fmt.format(s.caseData.totalPaidAmount!)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              _PaymentsTable(payments: payments, hasInstallmentPlan: s.caseData.hasInstallmentPlan == true, s: s),
            ],
          ),
        ],
      ),
    );
  }

  List<_PaymentRow> _extractPayments() {
    final list = <_PaymentRow>[];
    final raw = s.caseData.payments;
    if (raw == null) return list;
    final hasPlan = s.caseData.hasInstallmentPlan == true;
    final installmentById = hasPlan
        ? {for (final inst in s.localInstallments.values) inst.id: inst}
        : const <String, Installment>{};
    for (final p in raw) {
      try {
        if (p is Map) {
          final amountRaw = p['amount'];
          double? amount;
          if (amountRaw is num) amount = amountRaw.toDouble();
          else if (amountRaw is String) amount = double.tryParse(amountRaw.replaceAll(',', '.'));
          final dateRaw = p['paymentDate'];
          DateTime? date;
          if (dateRaw is String && dateRaw.isNotEmpty) {
            try { date = DateTime.parse(dateRaw.length==10 && !dateRaw.contains('T') ? dateRaw : dateRaw); } catch(_) {}
          }
          String? numberLabel;
          if (hasPlan) {
            final instId = p['installmentId'];
            if (instId is String) {
              final inst = installmentById[instId];
              numberLabel = inst != null ? inst.installmentNumber.toString() : '?';
            } else {
              numberLabel = '?';
            }
          }
          if (amount!=null && date!=null) {
            list.add(_PaymentRow(amount: amount, date: date, installmentNumberLabel: numberLabel));
          } else {
            list.add(_PaymentRow(amount: amount ?? 0.0, date: date ?? DateTime.fromMillisecondsSinceEpoch(0), invalid: true, installmentNumberLabel: numberLabel));
          }
        }
      } catch(_) {
        list.add(_PaymentRow(amount: 0.0, date: DateTime.fromMillisecondsSinceEpoch(0), invalid: true, installmentNumberLabel: hasPlan ? '?' : null));
      }
    }
    list.sort((a,b)=> a.date.compareTo(b.date));
    return list;
  }
}

class _PaymentRow {
  final double amount;
  final DateTime date;
  final bool invalid;
  final String? installmentNumberLabel; // null quando non c'è piano
  const _PaymentRow({
    required this.amount,
    required this.date,
    this.invalid = false,
    this.installmentNumberLabel,
  });
}

class _PaymentsTable extends StatelessWidget {
  final List<_PaymentRow> payments;
  final bool hasInstallmentPlan;
  final CaseDetailLoaded s;
  const _PaymentsTable({required this.payments, required this.hasInstallmentPlan, required this.s});
  @override
  Widget build(BuildContext context) {
    final fmt = AppDateFormats.date;
    final fmtAmount = NumberFormat('#,##0.00', 'it_IT');
    const maxRowsNoScroll = 10;
    final rows = List<DataRow>.generate(payments.length, (index) {
      final p = payments[index];
      final number = hasInstallmentPlan
          ? (p.installmentNumberLabel ?? '?')
          : (index + 1).toString();
      return DataRow(cells: [
        DataCell(Text(number)),
        DataCell(Text(p.invalid ? '?' : '€ ${fmtAmount.format(p.amount)}')),
        DataCell(Text(p.invalid ? '?' : fmt.format(p.date))),
      ]);
    });
    final table = DataTable(
      columns:  [
        DataColumn(label: hasInstallmentPlan? Text('Rata') : SizedBox.shrink()), // header vuoto
        const DataColumn(label: Text('Importo')),
        const DataColumn(label: Text('Data')),
      ],
      rows: rows,
      headingRowHeight: 36,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
    );
    if (payments.length <= maxRowsNoScroll) return table;
    final height = 48 * maxRowsNoScroll + 40;
    return SizedBox(
      height: height.toDouble(),
      child: SingleChildScrollView(child: table),
    );
  }
}

extension<E> on Iterable<E> {
  List<T> mapIndexed<T>(T Function(int index, E e) toElement){
    var i=0; final out=<T>[]; for(final e in this){ out.add(toElement(i,e)); i++; } return out; }
}

class _NegotiationChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withAlpha((0.18 * 255).round())),
      ),
      child: const Text('Negoziazione in corso', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
    );
  }
}

class _FieldsGrid extends StatelessWidget {
  final CaseDetailLoaded s;
  final bool twoColumns;
  const _FieldsGrid({required this.s, required this.twoColumns});
  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat('#,##0.00', 'it_IT');
    final fields = [
      _FieldData(label: 'Importo dovuto', value: '€ ${fmtCurrency.format(s.owedAmount)}'),
      _FieldData(label: 'Ultima modifica stato', value: _fmtDate(s.caseData.lastStateDate)),
      if (s.caseData.createdDate != null) _FieldData(label: 'Creata il', value: _fmtDate(s.caseData.createdDate!)),
      if (s.caseData.lastModifiedDate != null) _FieldData(label: 'Aggiornata il', value: _fmtDate(s.caseData.lastModifiedDate!)),
      _FieldData(label: 'Negoziazione in corso', value: s.ongoingNegotiations ? 'Sì' : 'No'),
      if (s.caseData.totalPaidAmount != null) _FieldData(label: 'Totale pagato', value: '€ ${fmtCurrency.format(s.caseData.totalPaidAmount!)}'),
      if (s.caseData.remainingAmount != null) _FieldData(label: 'Residuo', value: '€ ${fmtCurrency.format(s.caseData.remainingAmount!)}'),
      if (s.caseData.createdBy != null) _FieldData(label: 'Creato da', value: s.caseData.createdBy!),
      if (s.caseData.lastModifiedBy != null) _FieldData(label: 'Ultima modifica da', value: s.caseData.lastModifiedBy!),
    ];
    final children = fields.map((f) => _FieldTile(data: f)).toList();
    if (twoColumns) {
      return Wrap(
        spacing: 20,
        runSpacing: 12,
        children: children.map((w) => SizedBox(width: 150, child: w)).toList(),
      );
    } else {
      return Column(
        children: [for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: w)],
      );
    }
  }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _FieldData { final String label; final String value; _FieldData({required this.label, required this.value}); }

class _FieldTile extends StatelessWidget {
  final _FieldData data;
  const _FieldTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: base.tertiary)),
        const SizedBox(height: 2),
        Text(data.value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String? notes;
  const _NotesSection({required this.notes});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: base.outline.withAlpha((0.08 * 255).round())),
      ),
      child: notes == null || notes!.isEmpty
          ? const Text('— Nessuna nota —', style: TextStyle(color: Colors.black54))
          : Text(notes!, style: const TextStyle(height: 1.3)),
    );
  }
}

class _StateChip extends StatelessWidget {
  final CaseState state;
  const _StateChip({required this.state});
  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey; String label = 'Sconosciuto';
    switch (state) {
      case CaseState.messaInMoraDaFare: color = Colors.grey; label = 'Messa in Mora da Fare'; break;
      case CaseState.messaInMoraInviata: color = Colors.red; label = 'Messa in Mora Inviata'; break;
      case CaseState.contestazioneDaRiscontrare: color = Colors.orange; label = 'Contestazione da Riscontrare'; break;
      case CaseState.depositoRicorso: color = Colors.amber; label = 'Deposito Ricorso'; break;
      case CaseState.decretoIngiuntivoDaNotificare: color = Colors.green; label = 'DI da Notificare'; break;
      case CaseState.decretoIngiuntivoNotificato: color = Colors.teal; label = 'DI Notificato'; break;
      case CaseState.precetto: color = Colors.blue; label = 'Precetto'; break;
      case CaseState.pignoramento: color = Colors.purple; label = 'Pignoramento'; break;
      case CaseState.completata: color = Colors.green; label = 'Completata'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha((0.18 * 255).round())),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _InstallmentsSideCard extends StatelessWidget {
  final CaseDetailLoaded s; final VoidCallback openEdit;
  final void Function(Installment inst) openRegisterInstallmentPayment;
  final VoidCallback? onCreatePlan; // opzionale per stato senza piano
  const _InstallmentsSideCard({required this.s, required this.openEdit, required this.openRegisterInstallmentPayment, this.onCreatePlan});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    if (s.caseData.hasInstallmentPlan != true) {
      final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
      final canCreate = residuo > 0 && s.state != CaseState.completata;
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: base.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0,2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Piano rateale', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('Nessun piano rate', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            if (canCreate && onCreatePlan != null) ElevatedButton.icon(
              onPressed: onCreatePlan,
              icon: const Icon(Icons.playlist_add_circle_outlined),
              label: const Text('Crea piano rateale'),
            ),
            if (!canCreate) const Text('Impossibile creare un piano (debito saldato o pratica completata).', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      );
    }
    final list = s.localInstallments.values.toList()..sort((a,b)=>a.dueDate.compareTo(b.dueDate));
    final fmt = AppDateFormats.date; // centralizzato
    const maxRows = 10;
    final anyPaid = list.any((i)=> i.paid == true);
    final canModify = !anyPaid && s.state != CaseState.completata;
    final rows = list.map((i) => DataRow(cells: [
      DataCell(Text(i.installmentNumber.toString())),
      DataCell(Text('€ ${i.amount.toStringAsFixed(2).replaceAll('.', ',')}')),
      DataCell(Text(fmt.format(i.dueDate))),
      DataCell(Text(i.paid==true? 'Pagata' : i.dueDate.isBefore(DateTime.now())? 'Scaduta' : 'Da pagare',
          style: TextStyle(color: i.paid==true? Colors.green : i.dueDate.isBefore(DateTime.now())? Colors.red : Colors.orange, fontWeight: FontWeight.w600))),
      DataCell(
        Center(
          child: i.paid==true || s.state==CaseState.completata ? const SizedBox.shrink() : Tooltip(
            message: 'Registra pagamento',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32), // Più compatto
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: ()=>openRegisterInstallmentPayment(i),
              icon: const Icon(Icons.payments_outlined, size: 15),
              label: const Text('Paga', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ),
    ])).toList();
    final table = DataTable(
      columns: const [
        DataColumn(label:  SizedBox.shrink()), // Colonna numero fissa e stretta
        DataColumn(label: Text('Importo')), // Colonna importo fissa
        DataColumn(label: Text('Scadenza')),
        DataColumn(label: Text('Stato')),
        DataColumn(label: SizedBox.shrink()), // Colonna azione centrata e fissa
      ],
      rows: rows,
      headingRowHeight: 34,
      dataRowMinHeight: 38,
      dataRowMaxHeight: 46,
    );
    Widget tableWidget;
    if (list.length > maxRows) {
      tableWidget = SizedBox(
        height: 46 * maxRows + 40,
        child: SingleChildScrollView(child: table),
      );
    } else {
      tableWidget = table;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(child: Text('Rate (${list.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
              if (canModify)
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Modifica piano'),
                  onPressed: () {
                    // Usa il dialog condiviso accedendo allo stateful ancestor tramite context.findAncestorStateOfType
                    final state = context.findAncestorStateOfType<_CaseDetailReadOnlyViewState>();
                    state?._openReplacePlanDialog(s);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          tableWidget,
        ],
      ),
    );
  }
}
