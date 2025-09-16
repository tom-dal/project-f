import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../blocs/case_detail/case_detail_bloc.dart';
import '../services/api_service.dart';
import '../utils/amount_validator.dart';
import 'case_detail_edit_screen.dart';

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
              TextButton.icon(
                onPressed: () => _openEdit(context, s),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Modifica'),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 780;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderSection(s: s, onRegisterPayment: _openRegisterPaymentDialog),
                        const SizedBox(height: 32),
                        _SectionTitle('Dati pratica'),
                        const SizedBox(height: 8),
                        _FieldsGrid(s: s, twoColumns: wide),
                        const SizedBox(height: 32),
                        _SectionTitle('Note'),
                        const SizedBox(height: 8),
                        _NotesSection(notes: s.notes),
                        const SizedBox(height: 32),
                        _SectionTitle('Rateizzazione'),
                        const SizedBox(height: 8),
                        _InstallmentsPreview(s: s),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEdit(context, s),
            icon: const Icon(Icons.edit),
            label: const Text('Modifica'),
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, CaseDetailLoaded s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDetailEditScreen(caseId: s.caseData.id, initialCase: s.caseData),
      ),
    );
  }

  void _openRegisterPaymentDialog(CaseDetailLoaded s) {
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool useResiduo = false;
    final formKey = GlobalKey<FormState>();
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            void applyResiduo(bool v){
              setState(() {
                useResiduo = v;
                if (useResiduo) {
                  amountCtrl.text = NumberFormat('#,##0.00', 'it_IT').format(residuo).replaceAll('\u00A0','');
                } else {
                  amountCtrl.clear();
                }
              });
            }
            return AlertDialog(
              title: const Text('Registra pagamento'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(labelText: 'Importo (€)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          FilteringTextInputFormatter.deny(RegExp(r'([.,].*[.,])')),
                          TextInputFormatter.withFunction((oldValue,newValue){
                            final parts = newValue.text.split(RegExp(r'[.,]'));
                            if (parts.length==2 && parts[1].length>2) return oldValue; return newValue;
                          })
                        ],
                        validator: (v){
                          if (useResiduo) return null;
                          final res = normalizeFlexibleItalianAmount(v??'');
                          if (res.error!=null) return res.error;
                          return null;
                        },
                        enabled: !useResiduo,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Switch(value: useResiduo && residuo>0, onChanged: residuo>0 ? (v)=>applyResiduo(v) : null),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Usa importo residuo (${residuo>0? '€ '+residuo.toStringAsFixed(2):'0'})')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(now.year-1),
                            lastDate: DateTime(now.year+5),
                            initialDate: selectedDate,
                            helpText: 'Data pagamento',
                          );
                          if (picked!=null) setState(()=> selectedDate = DateTime(picked.year, picked.month, picked.day));
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Data pagamento'),
                          child: Row(
                            children: [
                              Expanded(child: Text('${selectedDate.day.toString().padLeft(2,'0')}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.year}')),
                              const Icon(Icons.date_range, size: 18)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Annulla')),
                ElevatedButton(
                  onPressed: (){
                    if (formKey.currentState?.validate()==true) {
                      double amount;
                      if (useResiduo) {
                        amount = residuo;
                      } else {
                        final res = normalizeFlexibleItalianAmount(amountCtrl.text);
                        if (!res.isValid) return; else amount = res.value!;
                      }
                      context.read<CaseDetailBloc>().add(RegisterCasePayment(amount: amount, paymentDate: selectedDate));
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Conferma'),
                )
              ],
            );
          },
        );
      }
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final CaseDetailLoaded s;
  final void Function(CaseDetailLoaded) onRegisterPayment;
  const _HeaderSection({required this.s, required this.onRegisterPayment});
  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat('#,##0.00', 'it_IT');
    final base = Theme.of(context).colorScheme;
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    final showRegisterPayment = (s.caseData.hasInstallmentPlan != true) && residuo > 0.0;
    final hasPayments = (s.caseData.totalPaidAmount ?? 0) > 0.0;
    final isCompletata = s.state == CaseState.completata;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.debtorName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Importo:', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(width: 4),
                    Text('€ ${fmtCurrency.format(s.owedAmount)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
                  ],
                ),
                if (!isCompletata && hasPayments) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Residuo:', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(width: 4),
                      Text('€ ${fmtCurrency.format(residuo)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Scadenza:', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(width: 4),
                    Text(s.nextDeadline != null ? _fmtDate(s.nextDeadline!) : '-', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
                  ],
                ),
                if (showRegisterPayment) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Registra pagamento'),
                    onPressed: () => onRegisterPayment(s),
                  ),
                  const SizedBox(height: 8),
                  Text('Residuo: € ${fmtCurrency.format(residuo)}', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Divider(thickness: 1)),
        ],
      ),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Wrap(
          spacing: 32,
          runSpacing: 20,
          children: children.map((w) => SizedBox(width: 320, child: w)).toList(),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 20), child: w)],
        ),
      );
    }
  }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _FieldData {
  final String label;
  final String value;
  _FieldData({required this.label, required this.value});
}

class _FieldTile extends StatelessWidget {
  final _FieldData data;
  const _FieldTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: base.secondary)),
        const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
    Color color = Colors.grey;
    String label = 'Sconosciuto';
    switch (state) {
      case CaseState.messaInMoraDaFare:
        color = Colors.grey; label = 'Messa in Mora da Fare'; break;
      case CaseState.messaInMoraInviata:
        color = Colors.red; label = 'Messa in Mora Inviata'; break;
      case CaseState.contestazioneDaRiscontrare:
        color = Colors.orange; label = 'Contestazione da Riscontrare'; break;
      case CaseState.depositoRicorso:
        color = Colors.amber; label = 'Deposito Ricorso'; break;
      case CaseState.decretoIngiuntivoDaNotificare:
        color = Colors.green; label = 'DI da Notificare'; break;
      case CaseState.decretoIngiuntivoNotificato:
        color = Colors.teal; label = 'DI Notificato'; break;
      case CaseState.precetto:
        color = Colors.blue; label = 'Precetto'; break;
      case CaseState.pignoramento:
        color = Colors.purple; label = 'Pignoramento'; break;
      case CaseState.completata:
        color = Colors.green; label = 'Completata'; break;
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

class _InstallmentsPreview extends StatelessWidget {
  final CaseDetailLoaded s;
  const _InstallmentsPreview({required this.s});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    if (s.caseData.hasInstallmentPlan != true) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: base.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: base.outline.withAlpha((0.08 * 255).round())),
        ),
        child: const Text('Nessun piano rate presente'),
      );
    }
    final list = s.localInstallments.values.toList()..sort((a,b)=>a.dueDate.compareTo(b.dueDate));
    final fmt = DateFormat('dd/MM/yyyy');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: base.outline.withAlpha((0.08 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate (${list.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Importo')),
                DataColumn(label: Text('Scadenza')),
                DataColumn(label: Text('Stato')),
              ],
              rows: list.map((i) => DataRow(cells: [
                DataCell(Text(i.installmentNumber.toString())),
                DataCell(Text('€ ${i.amount.toStringAsFixed(2).replaceAll('.', ',')}')),
                DataCell(Text(fmt.format(i.dueDate))),
                DataCell(Text(i.paid==true? 'Pagata' : 'Da pagare', style: TextStyle(color: i.paid==true? Colors.green : Colors.orange))),
              ])).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _goToEdit(context),
              icon: const Icon(Icons.edit_note),
              label: const Text('Modifica rate'),
            ),
          )
        ],
      ),
    );
  }
  void _goToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDetailEditScreen(caseId: s.caseData.id, initialCase: s.caseData),
      ),
    );
  }
}
