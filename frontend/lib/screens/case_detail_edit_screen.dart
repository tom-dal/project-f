import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../blocs/case_detail/case_detail_bloc.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../services/api_service.dart';
import '../utils/amount_validator.dart';

class CaseDetailEditScreen extends StatelessWidget {
  final String caseId;
  final DebtCase initialCase; // For immediate header info while loading fresh detail
  const CaseDetailEditScreen({super.key, required this.caseId, required this.initialCase});

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

  final NumberFormat _itFormatter = NumberFormat('#,##0.00', 'it_IT');
  bool _wasSaving = false; // track save transitions
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(() {
      if (!_amountFocus.hasFocus) {
        final parsed = _parseAmount(_amountCtrl.text);
        if (parsed != null) {
          _amountCtrl.text = _formatAmount(parsed);
        }
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaseDetailBloc, CaseDetailState>(
      listener: (context, state) {
        if (state is CaseDetailLoaded) {
          if (_initialLoaded && _wasSaving && !state.saving && state.error == null && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.successMessage!), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
            _notesCtrl.text = state.notes ?? '';
          } else if (!_notesFocus.hasFocus && _notesCtrl.text != (state.notes ?? '')) {
            _notesCtrl.text = state.notes ?? '';
          }
          _initialLoaded = true;
          _wasSaving = state.saving;
          _debtorCtrl.text = state.debtorName;
          if (!_amountFocus.hasFocus) {
            final formatted = _formatAmount(state.owedAmount);
            if (_amountCtrl.text != formatted) {
              _amountCtrl.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent),
            );
          }
        } else if (state is CaseDetailDeleted) {
          final debtBloc = context.read<DebtCaseBloc>();
          debtBloc.add(const LoadCasesPaginated());
          if (mounted) Navigator.of(context).pop();
        } else if (state is CaseDetailError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
          );
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
        final s = state as CaseDetailLoaded;
        final wide = MediaQuery.of(context).size.width > 780;
        return Scaffold(
          appBar: AppBar(
            title: Text('Pratica ${s.caseData.id.substring(0, 6)}'),
            bottom: s.saving ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(minHeight: 3),
            ) : null,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: s.dirty && !s.saving ? () {
              if (_formKey.currentState?.validate()==true) {
                context.read<CaseDetailBloc>().add(SaveCaseEdits());
              }
            } : null,
            icon: const Icon(Icons.save),
            label: const Text('Salva'),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderSection(
                        s: s,
                        debtorCtrl: _debtorCtrl,
                        amountCtrl: _amountCtrl,
                        amountFocus: _amountFocus,
                        bloc: context.read<CaseDetailBloc>(),
                      ),
                      const SizedBox(height: 32),
                      _SectionTitle('Note'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _notesCtrl,
                                focusNode: _notesFocus,
                                decoration: const InputDecoration(labelText: 'Note', alignLabelWithHint: true, hintText: 'Inserisci eventuali annotazioni'),
                                maxLines: 4,
                                onChanged: (v)=> context.read<CaseDetailBloc>().add(EditNotes(v.isEmpty? null : v)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'Svuota note',
                                  icon: const Icon(Icons.clear),
                                  onPressed: _notesCtrl.text.isEmpty ? null : () {
                                    _notesCtrl.clear();
                                    context.read<CaseDetailBloc>().add(EditNotes(null));
                                    setState(() {});
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle('Dati pratica'),
                      const SizedBox(height: 8),
                      _EditFieldsGrid(s: s, twoColumns: wide),
                      const SizedBox(height: 32),
                      _SectionTitle('Rateizzazione'),
                      const SizedBox(height: 8),
                      _buildInstallmentsSection(context, s),
                      const SizedBox(height: 32),
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

  Widget _buildInstallmentsSection(BuildContext context, CaseDetailLoaded s) {
    final bloc = context.read<CaseDetailBloc>();
    final base = Theme.of(context).colorScheme;
    if (s.state == CaseState.completata) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: base.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Gestione rate non disponibile per pratiche completate.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      );
    }
    if (s.caseData.hasInstallmentPlan != true) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: base.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nessun piano presente', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Crea un piano di rateizzazione. Le singole rate potranno essere modificate successivamente.'),
            const SizedBox(height: 12),
            _CreatePlanForm(onCreate: (n, first, amt, freq){
              bloc.add(CreateInstallmentPlanEvent(numberOfInstallments: n, firstDueDate: first, installmentAmount: amt, frequencyDays: freq));
            }),
          ],
        ),
      );
    }
    final placeholders = s.localInstallments.keys.where((k)=>k.startsWith('tmp-')).toList();
    final list = s.localInstallments.values.toList()..sort((a,b)=>a.dueDate.compareTo(b.dueDate));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Rateizzazione', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              if (s.replacingPlan) const Text('(Nuovo piano in preparazione)', style: TextStyle(color: Colors.orange))
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty) const Text('Nessuna rata'),
          if (list.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Importo')),
                  DataColumn(label: Text('Scadenza')),
                  DataColumn(label: Text('Stato')),
                  DataColumn(label: Text('Azioni')),
                ],
                rows: list.map((inst) {
                  final isPlaceholder = inst.id.startsWith('tmp-');
                  final dirty = s.installmentDirty.contains(inst.id) || isPlaceholder;
                  final rowColor = dirty ? Colors.amber.withValues(alpha: 0.12) : null;
                  return DataRow(
                    color: rowColor != null ? WidgetStatePropertyAll(rowColor) : null,
                    cells: [
                      DataCell(Row(children:[Text(inst.installmentNumber.toString()), if(dirty) const SizedBox(width:4), if(dirty) const Text('*', style: TextStyle(color: Colors.orange,fontWeight: FontWeight.bold))])),
                      DataCell(_AmountCell(
                        amount: inst.amount,
                        enabled: !isPlaceholder || true,
                        formatter: _itFormatter,
                        onChanged: (val){
                          final parsed = _parseAmount(val);
                          if (parsed!=null) bloc.add(UpdateInstallmentLocal(installmentId: inst.id, amount: parsed));
                        },
                      )),
                      DataCell(_DueDateCell(
                        date: inst.dueDate,
                        enabled: !isPlaceholder || true,
                        onPick: (d){ bloc.add(UpdateInstallmentLocal(installmentId: inst.id, dueDate: d)); },
                      )),
                      DataCell(Text(inst.paid==true? 'Pagata' : 'Da pagare', style: TextStyle(color: inst.paid==true? Colors.green: Colors.orange))),
                      DataCell(Row(
                        children: [
                          if (!isPlaceholder)
                            IconButton(
                              tooltip: 'Salva rata',
                              icon: const Icon(Icons.save, size: 18),
                              onPressed: dirty && !s.replacingPlan && !s.saving ? ()=> bloc.add(SaveSingleInstallment(inst.id)) : null,
                            ),
                          if (isPlaceholder)
                            IconButton(
                              tooltip: 'Rimuovi',
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: ()=> bloc.add(RemoveNewInstallmentPlaceholder(inst.id)),
                            ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi rata (placeholder)'),
                onPressed: s.saving ? null : ()=> bloc.add(AddNewInstallmentPlaceholder()),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Sostituisci piano'),
                onPressed: (!s.replacingPlan || placeholders.isEmpty || s.saving)? null : ()=> bloc.add(ApplyNewInstallmentsReplacePlan()),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_outline),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
                label: const Text('Elimina piano'),
                onPressed: s.saving ? null : ()=> _confirmDeletePlan(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlan(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Eliminare il piano rate?'),
        content: const Text('Il piano sarà rimosso se nessuna rata è pagata.'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CaseDetailBloc>().add(DeleteInstallmentPlanEvent());
            },
            child: const Text('Elimina'),
          )
        ],
      ),
    );
  }

  String _formatAmount(double v){
    return _itFormatter.format(v).replaceAll('\u00A0', '');
  }
  double? _parseAmount(String raw){
    final cleaned = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
  Map<String, dynamic> _normalizeAmount(String raw) {
    final original = raw.trim();
    if (original.isEmpty) return {'error': 'Importo non valido'};
    final stripped = original.replaceAll(RegExp(r'\s'), '');
    int lastDot = stripped.lastIndexOf('.');
    int lastComma = stripped.lastIndexOf(',');
    int sepIndex = lastDot > lastComma ? lastDot : lastComma;
    String intPart;
    String fracPart = '';
    if (sepIndex >= 0) {
      intPart = stripped.substring(0, sepIndex).replaceAll(RegExp(r'[^0-9]'), '');
      fracPart = stripped.substring(sepIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      intPart = stripped.replaceAll(RegExp(r'[^0-9]'), '');
    }
    if (intPart.isEmpty) return {'error': 'Importo non valido'};
    if (fracPart.length > 2) return {'error': 'Max 2 decimali'};
    final composed = intPart + (fracPart.isNotEmpty ? '.${fracPart}' : '');
    final val = double.tryParse(composed);
    if (val == null || val <= 0) return {'error': 'Importo non valido'};
    return {'value': val};
  }
}

class _HeaderSection extends StatelessWidget {
  final CaseDetailLoaded s;
  final TextEditingController debtorCtrl;
  final TextEditingController amountCtrl;
  final FocusNode amountFocus;
  final CaseDetailBloc bloc;
  const _HeaderSection({required this.s, required this.debtorCtrl, required this.amountCtrl, required this.amountFocus, required this.bloc});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    if (amountCtrl.text.isEmpty || amountCtrl.text == '0' || amountCtrl.text == '0,00') {
      amountCtrl.text = NumberFormat('#,##0.00', 'it_IT').format(s.owedAmount).replaceAll('\u00A0', '');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: base.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: debtorCtrl,
                  decoration: const InputDecoration(labelText: 'Debitore'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  onChanged: (v) => bloc.add(EditDebtorName(v.trim())),
                  validator: (v) => (v==null||v.trim().length<2)?'Nome non valido':null,
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Negoziazione in corso'),
                      Switch(
                        value: s.ongoingNegotiations,
                        onChanged: (v)=> bloc.add(EditOngoingNegotiations(v)),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<CaseState>(
                  initialValue: s.state,
                  decoration: const InputDecoration(labelText: 'Stato'),
                  items: CaseState.values.map((cs) => DropdownMenuItem(
                    value: cs,
                    child: Text(_readableState(cs)),
                  )).toList(),
                  onChanged: (val) { if (val != null) bloc.add(EditState(val)); },
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: TextFormField(
                  controller: amountCtrl,
                  focusNode: amountFocus,
                  decoration: const InputDecoration(labelText: 'Importo dovuto (€)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    FilteringTextInputFormatter.deny(RegExp(r'([.,].*[.,])')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;
                      final parts = text.split(RegExp(r'[.,]'));
                      if (parts.length == 2 && parts[1].length > 2) return oldValue;
                      return newValue;
                    }),
                  ],
                  onChanged: (v){
                    final res = (context.findAncestorStateOfType<_CaseDetailViewState>()?._normalizeAmount(v)) ?? {};
                    if (res['value'] != null) bloc.add(EditOwedAmount(res['value'] as double));
                  },
                  validator: (v){
                    final res = (context.findAncestorStateOfType<_CaseDetailViewState>()?._normalizeAmount(v??'')) ?? {'error':'Importo non valido'};
                    return res['error'];
                  },
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Scadenza:', style: Theme.of(context).textTheme.labelLarge),
                    Text(s.nextDeadline != null ? _fmtDate(s.nextDeadline!) : '-', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _readableState(CaseState cs) {
    switch (cs) {
      case CaseState.messaInMoraDaFare: return 'Messa in mora da fare';
      case CaseState.messaInMoraInviata: return 'Messa in mora inviata';
      case CaseState.contestazioneDaRiscontrare: return 'Contestazione da riscontrare';
      case CaseState.depositoRicorso: return 'Deposito ricorso';
      case CaseState.decretoIngiuntivoDaNotificare: return 'D.I. da notificare';
      case CaseState.decretoIngiuntivoNotificato: return 'D.I. notificato';
      case CaseState.precetto: return 'Precetto';
      case CaseState.pignoramento: return 'Pignoramento';
      case CaseState.completata: return 'Completata';
    }
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

class _EditFieldsGrid extends StatelessWidget {
  final CaseDetailLoaded s;
  final bool twoColumns;
  const _EditFieldsGrid({required this.s, required this.twoColumns});
  @override
  Widget build(BuildContext context) {
    final fields = [
      _FieldData(label: 'Ultima modifica stato', value: _fmtDate(s.caseData.lastStateDate)),
      if (s.caseData.createdDate != null) _FieldData(label: 'Creata il', value: _fmtDate(s.caseData.createdDate!)),
      if (s.caseData.lastModifiedDate != null) _FieldData(label: 'Aggiornata il', value: _fmtDate(s.caseData.lastModifiedDate!)),
      _FieldData(label: 'Negoziazione in corso', value: s.ongoingNegotiations ? 'Sì' : 'No'),
      if (s.caseData.totalPaidAmount != null) _FieldData(label: 'Totale pagato', value: '€ ${s.caseData.totalPaidAmount!.toStringAsFixed(2)}'),
      if (s.caseData.remainingAmount != null) _FieldData(label: 'Residuo', value: '€ ${s.caseData.remainingAmount!.toStringAsFixed(2)}'),
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

class _AmountCell extends StatefulWidget {
  final double amount;
  final bool enabled;
  final NumberFormat formatter;
  final ValueChanged<String> onChanged;
  const _AmountCell({required this.amount, required this.enabled, required this.formatter, required this.onChanged});
  @override
  State<_AmountCell> createState() => _AmountCellState();
}
class _AmountCellState extends State<_AmountCell> {
  late TextEditingController _ctrl;
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.formatter.format(widget.amount).replaceAll('\u00A0',''));
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        final parsed = _parse(_ctrl.text);
        if (parsed != null) {
          final formatted = widget.formatter.format(parsed).replaceAll('\u00A0','');
          if (_ctrl.text != formatted) _ctrl.text = formatted;
        }
      }
    });
  }
  double? _parse(String raw){
    final cleaned = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
  @override
  void didUpdateWidget(covariant _AmountCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.amount != widget.amount) {
      _ctrl.text = widget.formatter.format(widget.amount).replaceAll('\u00A0','');
    }
  }
  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        enabled: widget.enabled,
        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 14),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          FilteringTextInputFormatter.deny(RegExp(r'([.,].*[.,])')),
          TextInputFormatter.withFunction((oldValue, newValue){
            final parts = newValue.text.split(RegExp(r'[.,]'));
            if (parts.length==2 && parts[1].length>2) return oldValue; return newValue;
          })
        ],
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _DueDateCell extends StatelessWidget {
  final DateTime date;
  final bool enabled;
  final ValueChanged<DateTime> onPick;
  const _DueDateCell({required this.date, required this.enabled, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final txt = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
    return InkWell(
      onTap: !enabled ? null : () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(DateTime.now().year-1),
          lastDate: DateTime(DateTime.now().year+5),
          initialDate: date,
          helpText: 'Nuova scadenza rata',
        );
        if (picked != null) {
          onPick(DateTime(picked.year, picked.month, picked.day));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Text(txt, style: TextStyle(fontSize: 14, color: enabled ? Colors.blueGrey[800] : Colors.grey)),
            if (enabled) const SizedBox(width: 4),
            if (enabled) const Icon(Icons.edit_calendar, size: 16, color: Colors.blueGrey)
          ],
        ),
      ),
    );
  }
}

class _CreatePlanForm extends StatefulWidget {
  final void Function(int numberOfInstallments, DateTime firstDueDate, double installmentAmount, int frequencyDays) onCreate;
  const _CreatePlanForm({required this.onCreate});
  @override
  State<_CreatePlanForm> createState() => _CreatePlanFormState();
}
class _CreatePlanFormState extends State<_CreatePlanForm> {
  final _formKey = GlobalKey<FormState>();
  final _nCtrl = TextEditingController(text: '3');
  final _amtCtrl = TextEditingController();
  final _freqCtrl = TextEditingController(text: '30');
  DateTime _firstDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nCtrl.dispose();
    _amtCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: _nCtrl,
                  decoration: const InputDecoration(labelText: 'N. Rate'),
                  keyboardType: TextInputType.number,
                  validator: (v){
                    final n = int.tryParse(v??'');
                    if (n==null || n<1 || n>120) return '1-120';
                    return null;
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _amtCtrl,
                  decoration: const InputDecoration(labelText: 'Importo rata'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  validator: (v){
                    final res = normalizeFlexibleItalianAmount(v??'');
                    if (res.error!=null) return res.error;
                    return null;
                  },
                ),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: _freqCtrl,
                  decoration: const InputDecoration(labelText: 'Frequenza (gg)'),
                  keyboardType: TextInputType.number,
                  validator: (v){
                    final f = int.tryParse(v??'');
                    if (f==null || f<1 || f>365) return '1-365';
                    return null;
                  },
                ),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(DateTime.now().year+5),
                    initialDate: _firstDate,
                    helpText: 'Prima scadenza',
                  );
                  if (picked!=null) setState(()=> _firstDate = DateTime(picked.year,picked.month,picked.day));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Prima scadenza'),
                  child: Text('${_firstDate.day.toString().padLeft(2,'0')}/${_firstDate.month.toString().padLeft(2,'0')}/${_firstDate.year}'),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: const Text('Crea piano'),
            onPressed: () {
              if (_formKey.currentState?.validate()==true) {
                final n = int.parse(_nCtrl.text);
                final freq = int.parse(_freqCtrl.text);
                final amtRes = normalizeFlexibleItalianAmount(_amtCtrl.text);
                final amt = amtRes.value!;
                widget.onCreate(n, _firstDate, amt, freq);
              }
            },
          )
        ],
      ),
    );
  }
}

