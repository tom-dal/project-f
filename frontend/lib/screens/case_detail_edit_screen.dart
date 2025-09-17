import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../models/installment.dart';
import '../blocs/case_detail/case_detail_bloc.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../services/api_service.dart';

class CaseDetailEditScreen extends StatelessWidget {
  final String caseId;
  final DebtCase
      initialCase; // USER PREFERENCE: placeholder for potential optimistic header usage
  const CaseDetailEditScreen(
      {super.key, required this.caseId, required this.initialCase});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context, listen: false);
    return BlocProvider(
      create: (_) => CaseDetailBloc(api)..add(LoadCaseDetail(caseId)),
      child: const _CaseDetailView(),
    );
  }
}

class _CaseDetailView extends StatefulWidget {
  const _CaseDetailView();

  @override
  State<_CaseDetailView> createState() => _CaseDetailViewState();
}

class _CaseDetailViewState extends State<_CaseDetailView> {
  final _debtorCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _amountFocus = FocusNode();
  final _notesFocus = FocusNode();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'it_IT');
  bool _wasSaving = false;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(() {
      if (!_amountFocus.hasFocus) {
        final p = _parseAmount(_amountCtrl.text);
        if (p != null) _amountCtrl.text = _formatAmount(p);
      }
    });
  }

  @override
  void dispose() {
    _debtorCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _amountFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String _formatAmount(double v) => _fmt.format(v).replaceAll('\u00A0', '');

  double? _parseAmount(String raw) {
    final c = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(c);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaseDetailBloc, CaseDetailState>(
      listener: (context, state) {
        if (state is CaseDetailLoaded) {
          if (_initialLoaded &&
              _wasSaving &&
              !state.saving &&
              state.error == null &&
              state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.successMessage!),
                duration: const Duration(seconds: 2)));
          }
          if (!_notesFocus.hasFocus) _notesCtrl.text = state.notes ?? '';
          if (!_amountFocus.hasFocus) {
            final f = _formatAmount(state.owedAmount);
            if (_amountCtrl.text != f) {
              _amountCtrl.value = TextEditingValue(
                  text: f,
                  selection: TextSelection.collapsed(offset: f.length));
            }
          }
          _debtorCtrl.text = state.debtorName;
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.redAccent));
          }
          _wasSaving = state.saving;
          _initialLoaded = true;
        } else if (state is CaseDetailDeleted) {
          context.read<DebtCaseBloc>().add(const LoadCasesPaginated());
          if (mounted) Navigator.pop(context);
        } else if (state is CaseDetailError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message), backgroundColor: Colors.redAccent));
        }
      },
      builder: (context, state) {
        if (state is CaseDetailLoading) {
          return Scaffold(
              appBar: AppBar(title: const Text('Dettaglio Pratica')),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (state is CaseDetailError) {
          return Scaffold(
              appBar: AppBar(title: const Text('Dettaglio Pratica')),
              body: Center(child: Text('Errore: ${state.message}')));
        }
        final s = state as CaseDetailLoaded;
        return Scaffold(
          appBar: AppBar(
            title: Text('Pratica ${s.caseData.id.substring(0, 6)}'),
            actions: [
              TextButton(
                onPressed: (s.dirty && !s.saving)
                    ? () => context.read<CaseDetailBloc>().add(ResetCaseEdits())
                    : null,
                child: const Row(children: [
                  Icon(Icons.restart_alt, size: 18),
                  SizedBox(width: 4),
                  Text('Reset')
                ]),
              ),
              TextButton(
                onPressed: (s.dirty && !s.saving)
                    ? () {
                        if (_formKey.currentState?.validate() ?? false)
                          context.read<CaseDetailBloc>().add(SaveCaseEdits());
                      }
                    : null,
                style: TextButton.styleFrom(
                  backgroundColor: (s.dirty && !s.saving)
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  foregroundColor: (s.dirty && !s.saving)
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).disabledColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Row(children: [
                  Icon(Icons.save, size: 18),
                  SizedBox(width: 6),
                  Text('Salva')
                ]),
              ),
            ],
            bottom: s.saving
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3))
                : null,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EditableFieldsCard(
                                s: s,
                                debtorCtrl: _debtorCtrl,
                                amountCtrl: _amountCtrl,
                                amountFocus: _amountFocus,
                                bloc: context.read<CaseDetailBloc>()),
                            const SizedBox(height: 28),
                            _NotesCard(
                                s: s,
                                notesCtrl: _notesCtrl,
                                notesFocus: _notesFocus,
                                bloc: context.read<CaseDetailBloc>()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EditablePaymentsCard(
                                s: s, bloc: context.read<CaseDetailBloc>()),
                            const SizedBox(height: 28),
                            _InstallmentPlanCard(
                                s: s, bloc: context.read<CaseDetailBloc>()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditableFieldsCard extends StatelessWidget {
  final CaseDetailLoaded s;
  final TextEditingController debtorCtrl;
  final TextEditingController amountCtrl;
  final FocusNode amountFocus;
  final CaseDetailBloc bloc;

  const _EditableFieldsCard(
      {required this.s,
      required this.debtorCtrl,
      required this.amountCtrl,
      required this.amountFocus,
      required this.bloc});

  double? _parseAmount(String v) {
    final c = v.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(c);
  }

  String _formatAmount(double v) =>
      NumberFormat('#,##0.00', 'it_IT').format(v).replaceAll('\u00A0', '');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dettagli Principali',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        TextFormField(
          controller: debtorCtrl,
          decoration: const InputDecoration(labelText: 'Debitore'),
          onChanged: (v) => bloc.add(EditDebtorName(v)),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Obbligatorio';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: amountCtrl,
          focusNode: amountFocus,
          decoration: const InputDecoration(
              labelText: 'Importo dovuto', prefixIcon: Icon(Icons.euro)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          ],
          onChanged: (v) {
            final p = _parseAmount(v);
            if (p != null) bloc.add(EditOwedAmount(p));
          },
          validator: (v) {
            final p = _parseAmount(v ?? '');
            if (p == null || p <= 0) return 'Valore non valido';
            return null;
          },
          onEditingComplete: () {
            final p = _parseAmount(amountCtrl.text);
            if (p != null) amountCtrl.text = _formatAmount(p);
            FocusScope.of(context).unfocus();
          },
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final initial = s.nextDeadline ??
                    DateTime.now().add(const Duration(days: 1));
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 5),
                );
                if (picked != null) bloc.add(EditNextDeadline(picked));
              },
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Prossima scadenza'),
                child: Row(children: [
                  const Icon(Icons.event, size: 18),
                  const SizedBox(width: 8),
                  Text(s.nextDeadline == null
                      ? '—'
                      : DateFormat('dd/MM/yyyy').format(s.nextDeadline!))
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<CaseState>(
              // sostituito value (deprecato) con initialValue
              initialValue: s.state,
              items: CaseState.values
                  .map((st) => DropdownMenuItem(value: st, child: Text(st.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) bloc.add(EditState(v));
              },
              decoration: const InputDecoration(labelText: 'Stato'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Trattative in corso'),
          value: s.ongoingNegotiations,
          onChanged: (v) => bloc.add(EditOngoingNegotiations(v)),
        ),
      ]),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final CaseDetailLoaded s;
  final TextEditingController notesCtrl;
  final FocusNode notesFocus;
  final CaseDetailBloc bloc;

  const _NotesCard(
      {required this.s,
      required this.notesCtrl,
      required this.notesFocus,
      required this.bloc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dirty = (s.notes ?? '') != (s.caseData.notes ?? '');
    final hasContent = notesCtrl.text.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Note',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
              onPressed: hasContent
                  ? () {
                      notesCtrl.clear();
                      bloc.add(EditNotes(null));
                    }
                  : null,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Svuota')),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller: notesCtrl,
          focusNode: notesFocus,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Note',
            hintText: 'Aggiungi annotazioni (opzionale)',
            filled: true,
            fillColor: cs.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline.withAlpha(60))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: dirty
                        ? cs.primary.withAlpha(160)
                        : cs.outline.withAlpha(70))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 2)),
          ),
          onChanged: (v) => bloc.add(EditNotes(v.isEmpty ? null : v)),
        ),
      ]),
    );
  }
}

class PaymentRow {
  final String id;
  final double amount;
  final DateTime paymentDate;

  const PaymentRow(
      {required this.id, required this.amount, required this.paymentDate});
}

class _EditablePaymentsCard extends StatelessWidget {
  final CaseDetailLoaded s;
  final CaseDetailBloc bloc;

  const _EditablePaymentsCard({required this.s, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final payments = _extractPayments();
    final fmtAmount = NumberFormat('#,##0.00', 'it_IT');
    final residuo = s.caseData.remainingAmount ??
        (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pagamenti',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (payments.isEmpty)
          const Text('Nessun pagamento registrato',
              style: TextStyle(color: Colors.black54))
        else
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(children: [
              if (s.caseData.totalPaidAmount != null)
                Text(
                    'Totale pagato: € ${fmtAmount.format(s.caseData.totalPaidAmount!)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
            ]),
            const SizedBox(height: 12),
            _EditablePaymentsTable(
                payments: payments,
                hasInstallmentPlan: s.caseData.hasInstallmentPlan == true,
                owedAmount: s.owedAmount,
                onEdit: (r) => _openEditDialog(context, r),
                onDelete: (r) => _confirmDelete(context, r)),
          ]),
      ]),
    );
  }

  List<PaymentRow> _extractPayments() {
    final raw = s.caseData.payments ?? <dynamic>[];
    final out = <PaymentRow>[];
    for (final p in raw) {
      if (p is Map) {
        try {
          final id = (p['id'] ?? p['paymentId'] ?? '').toString();
          if (id.isEmpty) continue;
          final a = p['amount'];
          double? amount;
          if (a is num)
            amount = a.toDouble();
          else if (a is String)
            amount = double.tryParse(a.replaceAll(',', '.'));
          if (amount == null) continue;
          final dr = p['paymentDate'] ?? p['date'];
          DateTime? d;
          if (dr is String && dr.isNotEmpty) {
            try {
              d = DateTime.parse(dr);
            } catch (_) {}
          }
          d ??= DateTime.now();
          out.add(PaymentRow(id: id, amount: amount, paymentDate: d));
        } catch (_) {}
      }
    }
    out.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return out;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatAmount(double v) =>
      NumberFormat('#,##0.00', 'it_IT').format(v).replaceAll('\u00A0', '');

  double? _parseAmount(String raw) {
    final c = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(c);
  }

  void _openEditDialog(BuildContext context, PaymentRow row) {
    final amountCtrl = TextEditingController(text: _formatAmount(row.amount));
    DateTime picked = row.paymentDate;
    final formKey = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
              void submit() {
                if (formKey.currentState?.validate() ?? false) {
                  final newAmount = _parseAmount(amountCtrl.text) ?? row.amount;
                  final amountChanged = (newAmount - row.amount).abs() > 0.0001;
                  final dateChanged = picked != row.paymentDate;
                  if (amountChanged || dateChanged) {
                    bloc.add(UpdatePaymentEvent(
                        paymentId: row.id,
                        amount: amountChanged ? newAmount : null,
                        paymentDate: dateChanged ? picked : null));
                  }
                  Navigator.pop(ctx);
                }
              }

              return AlertDialog(
                title: const Text('Modifica pagamento'),
                content: SizedBox(
                    width: 420,
                    child: Form(
                        key: formKey,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextFormField(
                              controller: amountCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Importo',
                                  prefixIcon: Icon(Icons.euro)),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'))
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Obbligatorio';
                                final p = _parseAmount(v);
                                if (p == null || p <= 0)
                                  return 'Valore non valido';
                                return null;
                              }),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final pd = await showDatePicker(
                                  context: ctx,
                                  initialDate: picked,
                                  firstDate: DateTime(DateTime.now().year - 1),
                                  lastDate: DateTime(DateTime.now().year + 5));
                              if (pd != null)
                                setState(() => picked =
                                    DateTime(pd.year, pd.month, pd.day));
                            },
                            child: InputDecorator(
                                decoration: const InputDecoration(
                                    labelText: 'Data pagamento'),
                                child: Row(children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_fmtDate(picked))
                                ])),
                          ),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla')),
                  ElevatedButton(onPressed: submit, child: const Text('Salva'))
                ],
              );
            }));
  }

  void _confirmDelete(BuildContext context, PaymentRow row) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Conferma eliminazione'),
                content: Text(
                    'Eliminare il pagamento di ${_formatAmount(row.amount)} €?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla')),
                  ElevatedButton(
                      onPressed: () {
                        bloc.add(DeletePaymentEvent(row.id));
                        Navigator.pop(ctx);
                      },
                      child: const Text('Elimina')),
                ]));
  }
}

class _EditablePaymentsTable extends StatelessWidget {
  final List<PaymentRow> payments;
  final bool hasInstallmentPlan;
  final double owedAmount;
  final void Function(PaymentRow) onEdit;
  final void Function(PaymentRow) onDelete;

  const _EditablePaymentsTable(
      {required this.payments,
      required this.hasInstallmentPlan,
      required this.owedAmount,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('dd/MM/yyyy');
    final fmtAmt = NumberFormat('#,##0.00', 'it_IT');
    return DataTable(
      columns: const [
        DataColumn(label: Text('Importo')),
        DataColumn(label: Text('Data')),
        DataColumn(label: Text('Azioni'))
      ],
      rows: payments
          .map((p) => DataRow(cells: [
                DataCell(Text('€ ${fmtAmt.format(p.amount)}')),
                DataCell(Text(fmtDate.format(p.paymentDate))),
                DataCell(Row(children: [
                  IconButton(
                      tooltip: 'Modifica',
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => onEdit(p)),
                  IconButton(
                      tooltip: 'Elimina',
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => onDelete(p)),
                ])),
              ]))
          .toList(),
      headingRowHeight: 36,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 52,
    );
  }
}

class _InstallmentPlanCard extends StatelessWidget {
  final CaseDetailLoaded s;
  final CaseDetailBloc bloc;

  const _InstallmentPlanCard({required this.s, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final installments = s.caseData.installments ?? [];
    if (s.caseData.hasInstallmentPlan == true && installments.isNotEmpty) {
      final list = [...installments]
        ..sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));
      final anyPaid = list.any((i) => i.paid == true);
      final total = list.fold<double>(0.0, (a, b) => a + b.amount);
      final fmt = NumberFormat('#,##0.00', 'it_IT');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Row(children: [
            Expanded(
                child: Text('Rate (${installments.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
            if (!anyPaid)
              OutlinedButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Modifica piano'),
                  onPressed: () => _openReplacePlanDialog(context, list)),
          ]),
          const SizedBox(height: 8),
          const SizedBox(height: 12),
          _InstallmentsTable(
              installments: list,
              onEditDate: (i) => _openEditDateDialog(context, i)),
        ]),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: const Text('Nessun piano rateale presente',
          style: TextStyle(color: Colors.black54)),
    );
  }

  void _openEditDateDialog(BuildContext context, Installment inst) {
    if (inst.paid == true) return;
    DateTime newDate = inst.dueDate;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
              return AlertDialog(
                title: Text('Rata #${inst.installmentNumber}'),
                content: SizedBox(
                    width: 360,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                            context: ctx,
                            initialDate: newDate,
                            firstDate: DateTime(DateTime.now().year - 1),
                            lastDate: DateTime(DateTime.now().year + 5));
                        if (picked != null)
                          setState(() => newDate =
                              DateTime(picked.year, picked.month, picked.day));
                      },
                      child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Nuova scadenza'),
                          child: Row(children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(_fmtDate(newDate))
                          ])),
                    )),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla')),
                  ElevatedButton(
                      onPressed: () {
                        if (newDate != inst.dueDate) {
                          bloc.add(UpdateInstallmentLocal(
                              installmentId: inst.id, dueDate: newDate));
                          bloc.add(SaveSingleInstallment(inst.id));
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Salva')),
                ],
              );
            }));
  }

  void _openReplacePlanDialog(BuildContext context, List<Installment> current) {
    final blocState = context.read<CaseDetailBloc>().state as CaseDetailLoaded;
    final residuo = blocState.caseData.remainingAmount ??
        (blocState.owedAmount - (blocState.caseData.totalPaidAmount ?? 0));
    final installmentsCtrl =
        TextEditingController(text: current.length.toString());
    final freqCtrl = TextEditingController(text: '30');
    int parsedInstallments = current.length;
    int parsedFreq = 30;
    DateTime firstDue = current.isNotEmpty
        ? current.first.dueDate
        : DateTime.now().add(const Duration(days: 30));
    bool userPicked = false;
    double floorAmt(double total, int n) {
      if (n <= 0) return 0;
      final raw = total / n;
      return (raw * 100).floor() / 100.0;
    }

    double remainder(double total, double per, int n) {
      return double.parse((total - per * n).toStringAsFixed(2));
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
              void recalc({bool fromFreq = false}) {
                parsedInstallments = int.tryParse(installmentsCtrl.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                parsedFreq = int.tryParse(
                        freqCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                if (parsedFreq <= 0) parsedFreq = 1;
                if (!userPicked && (fromFreq || parsedInstallments > 0))
                  firstDue = DateTime.now().add(Duration(days: parsedFreq));
                setState(() {});
              }

              Future<void> pick() async {
                final p = await showDatePicker(
                    context: ctx,
                    initialDate: firstDue,
                    firstDate: DateTime(DateTime.now().year - 1),
                    lastDate: DateTime(DateTime.now().year + 5),
                    helpText: 'Prima scadenza');
                if (p != null) {
                  setState(() {
                    firstDue = DateTime(p.year, p.month, p.day);
                    userPicked = true;
                  });
                }
              }

              final per = floorAmt(residuo, parsedInstallments);
              final rem = remainder(residuo, per, parsedInstallments);
              String? validate() {
                if (parsedInstallments < 2) return 'Minimo 2 rate';
                if (parsedInstallments > 240) return 'Troppe rate';
                if (per < 0.01) return 'Importo rata troppo basso';
                if (parsedFreq < 1) return 'Frequenza minima 1';
                if (parsedFreq > 365) return 'Frequenza massima 365';
                return null;
              }

              void submit() {
                final err = validate();
                if (err != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(err)));
                  return;
                }
                bloc.add(ReplaceInstallmentPlanSimple(
                    numberOfInstallments: parsedInstallments,
                    firstDueDate: firstDue,
                    perInstallmentAmountFloor: per,
                    frequencyDays: parsedFreq,
                    total: residuo));
                Navigator.pop(ctx);
              }

              final fmt = NumberFormat('#,##0.00', 'it_IT');
              final error = validate();
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('Modifica piano rateale'),
                content: SizedBox(
                    width: 520,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Debito residuo: € ${fmt.format(residuo)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: TextField(
                                    controller: installmentsCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'Numero rate'),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (_) => recalc())),
                            const SizedBox(width: 16),
                            Expanded(
                                child: TextField(
                                    controller: freqCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'Giorni tra rate'),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (_) => recalc(fromFreq: true))),
                          ]),
                          const SizedBox(height: 14),
                          InkWell(
                              onTap: pick,
                              child: InputDecorator(
                                  decoration: const InputDecoration(
                                      labelText: 'Prima scadenza'),
                                  child: Row(children: [
                                    const Icon(Icons.calendar_today, size: 18),
                                    const SizedBox(width: 8),
                                    Text(_fmtDate(firstDue))
                                  ]))),
                          const SizedBox(height: 16),
                          Text('Importo rata (floor): € ${fmt.format(per)}'),
                          const SizedBox(height: 4),
                          Text(
                              'Resto ultima rata: € ${fmt.format(rem < 0 ? 0 : rem)}',
                              style: const TextStyle(color: Colors.black54)),
                          if (error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(error,
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12))),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla')),
                  ElevatedButton(
                      onPressed: submit, child: const Text('Conferma')),
                ],
              );
            }));
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _InstallmentsTable extends StatelessWidget {
  final List<Installment> installments;
  final void Function(Installment) onEditDate;

  const _InstallmentsTable(
      {required this.installments, required this.onEditDate});

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('dd/MM/yyyy');
    final fmtAmt = NumberFormat('#,##0.00', 'it_IT');
    return DataTable(
      columns: const [
        DataColumn(label: Text('Importo')),
        DataColumn(label: Text('Scadenza')),
        DataColumn(label: Text('Stato')),
        DataColumn(label: Text('Azioni'))
      ],
      rows: installments.map((i) {
        final late = i.dueDate.isBefore(DateTime.now()) && i.paid != true;
        final statusLabel = i.paid == true
            ? 'Pagata'
            : late
                ? 'Scaduta'
                : 'Da pagare';
        final statusColor = i.paid == true
            ? Colors.green
            : late
                ? Colors.red
                : Colors.orange;
        return DataRow(cells: [
          DataCell(Text('€ ${fmtAmt.format(i.amount)}')),
          DataCell(Text(fmtDate.format(i.dueDate))),
          DataCell(Text(statusLabel,
              style:
                  TextStyle(color: statusColor, fontWeight: FontWeight.w600))),
          DataCell(Row(children: [
            if (i.paid != true)
              IconButton(
                  tooltip: 'Modifica scadenza',
                  icon: const Icon(Icons.event, size: 18),
                  onPressed: () => onEditDate(i))
          ])),
        ]);
      }).toList(),
      headingRowHeight: 36,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 52,
    );
  }
}
