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

class CaseDetailScreen extends StatelessWidget {
  final String caseId;
  final DebtCase initialCase; // For immediate header info while loading fresh detail
  const CaseDetailScreen({super.key, required this.caseId, required this.initialCase});

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

  bool _ignorePop = false;

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
            // Detect save completion (avoid first load)
            if (_initialLoaded && _wasSaving && !state.saving && state.error == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvato'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)));
              // Aggiorna sempre le note dopo il salvataggio, anche se il campo è in focus
              _notesCtrl.text = state.notes ?? '';
            } else if (!_notesFocus.hasFocus && _notesCtrl.text != (state.notes ?? '')) {
              // Aggiorna le note solo se non in focus e il valore è diverso
              _notesCtrl.text = state.notes ?? '';
            }
            _initialLoaded = true;
            _wasSaving = state.saving;
            _debtorCtrl.text = state.debtorName;
            // Aggiorna l'importo solo se il campo non è in focus e il valore è diverso
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
          // Refresh main list
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
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (_ignorePop || didPop) return;
            if (s.dirty || s.installmentDirty.isNotEmpty || s.replacingPlan) {
              final leave = await _confirmDiscard(context);
              if (leave) Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('Pratica ${s.caseData.id.substring(0, 6)}'),
              actions: [
                IconButton(
                  tooltip: 'Elimina pratica',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDeleteCase(context),
                )
              ],
              bottom: s.saving ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              ) : null,
            ),
            floatingActionButton: _buildFab(context, s),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 12),
                  _buildGeneralSection(context, s),
                  const SizedBox(height: 24),
                  _buildInstallmentsSection(context, s),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, Color color) => Chip(
    label: Text(label, style: TextStyle(color: color)),
    backgroundColor: color.withAlpha(25),
    side: BorderSide(color: color.withAlpha(60)),
  );

  Widget _buildGeneralSection(BuildContext context, CaseDetailLoaded s) {
    final bloc = context.read<CaseDetailBloc>();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Informazioni Generali', style: Theme.of(context).textTheme.titleMedium),
                if (s.dirty)
                  const Text('Modifiche non salvate', style: TextStyle(color: Colors.orange, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _debtorCtrl,
              decoration: const InputDecoration(labelText: 'Debitore'),
              onChanged: (v) => bloc.add(EditDebtorName(v.trim())),
              validator: (v) => (v==null||v.trim().length<2)?'Nome non valido':null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              decoration: const InputDecoration(labelText: 'Importo dovuto (€)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                FilteringTextInputFormatter.deny(RegExp(r'([.,].*[.,])')),
                // Limita a massimo 2 decimali
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text;
                  final parts = text.split(RegExp(r'[.,]'));
                  if (parts.length == 2 && parts[1].length > 2) {
                    return oldValue;
                  }
                  return newValue;
                }),
              ],
              onChanged: (v){
                final parsed = _parseAmount(v);
                if (parsed!=null) bloc.add(EditOwedAmount(parsed));
              },
              onEditingComplete: () {
                final parsed = _parseAmount(_amountCtrl.text);
                if (parsed!=null) _amountCtrl.text = _formatAmount(parsed);
              },
              validator: (v){
                final parsed = _parseAmount(v??'');
                if (parsed==null || parsed<=0) return 'Importo non valido';
                // max 2 decimals
                final decimals = v?.split(RegExp(r'[.,]')).length == 2 ? v?.split(RegExp(r'[.,]'))[1].length : 0;
                if (decimals != null && decimals > 2) return 'Max 2 decimali';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CaseState>(
              initialValue: s.state,
              items: CaseState.values.map((cs)=>DropdownMenuItem(value: cs, child: Text(_readableState(cs)))).toList(),
              onChanged: (val){ if (val!=null) bloc.add(EditState(val)); },
              decoration: const InputDecoration(labelText: 'Stato'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Scadenza corrente'),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.nextDeadline!=null? _fmtDate(s.nextDeadline!) : '-')),
                        IconButton(
                          icon: const Icon(Icons.date_range),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: now,
                              lastDate: DateTime(now.year+5),
                              initialDate: s.nextDeadline ?? now,
                              helpText: 'Seleziona nuova scadenza',
                            );
                            if (picked!=null) {
                              final dateTime = DateTime(picked.year, picked.month, picked.day, 0,0,0);
                              context.read<CaseDetailBloc>().add(EditNextDeadline(dateTime));
                            }
                          },
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('Negoziazione in corso'),
                    Switch(
                      value: s.ongoingNegotiations,
                      onChanged: (v)=>bloc.add(EditOngoingNegotiations(v)),
                    )
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _notesCtrl,
                    focusNode: _notesFocus,
                    decoration: const InputDecoration(labelText: 'Note', alignLabelWithHint: true, hintText: 'Inserisci eventuali annotazioni'),
                    maxLines: 4,
                    onChanged: (v)=>bloc.add(EditNotes(v.isEmpty?null:v)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Svuota note'),
                      onPressed: _notesCtrl.text.isEmpty ? null : () {
                        _notesCtrl.clear();
                        bloc.add(EditNotes(null));
                        setState(() {});
                      },
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                onPressed: s.dirty && !s.saving ? () {
                  if (_formKey.currentState?.validate()==true) {
                    context.read<CaseDetailBloc>().add(SaveCaseEdits());
                  }
                } : null,
                label: const Text('Salva'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentsSection(BuildContext context, CaseDetailLoaded s) {
    final bloc = context.read<CaseDetailBloc>();

    if (s.caseData.hasInstallmentPlan != true) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rateizzazione', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Nessun piano presente'),
              const SizedBox(height: 12),
              _CreatePlanForm(onCreate: (n, first, amt, freq){
                bloc.add(CreateInstallmentPlanEvent(numberOfInstallments: n, firstDueDate: first, installmentAmount: amt, frequencyDays: freq));
              }),
            ],
          ),
        ),
      );
    }

    final placeholders = s.localInstallments.keys.where((k)=>k.startsWith('tmp-')).toList();

    final list = s.localInstallments.values.toList()
      ..sort((a,b)=>a.dueDate.compareTo(b.dueDate));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _buildFab(BuildContext context, CaseDetailLoaded s) {
    final bloc = context.read<CaseDetailBloc>();
    final hasDirtyInstallments = s.installmentDirty.isNotEmpty;
    if (!hasDirtyInstallments || s.replacingPlan) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: s.saving ? null : () async {
        // Save all dirty installments sequentially
        for (final id in s.installmentDirty.toList()) {
          bloc.add(SaveSingleInstallment(id));
        }
      },
      icon: const Icon(Icons.save),
      label: const Text('Salva rate modificate'),
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Modifiche non salvate'),
        content: const Text('Uscire senza salvare le modifiche?'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('Annulla')),
          TextButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('Esci')),
        ],
      )
    );
    return res==true;
  }

  void _confirmDeleteCase(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Eliminare la pratica?'),
        content: const Text('L\'azione è irreversibile.'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CaseDetailBloc>().add(DeleteCaseEvent());
            },
            child: const Text('Elimina'),
          )
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

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
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

  String _formatAmount(double v){
    return _itFormatter.format(v).replaceAll('\u00A0', '');
  }
  double? _parseAmount(String raw){
    final cleaned = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}

class _AmountCell extends StatefulWidget {
  final double amount; final bool enabled; final ValueChanged<String> onChanged; final NumberFormat? formatter;
  const _AmountCell({required this.amount, required this.enabled, required this.onChanged, this.formatter});
  @override
  State<_AmountCell> createState() => _AmountCellState();
}
class _AmountCellState extends State<_AmountCell> {
  late TextEditingController _c;
  @override void initState(){
    super.initState();
    _c = TextEditingController(text: widget.amount.toStringAsFixed(2).replaceAll('.', ',')); // USER PREFERENCE: default decimal separator is comma
  }
  @override void dispose(){ _c.dispose(); super.dispose(); }
  @override void didUpdateWidget(covariant _AmountCell oldWidget){
    super.didUpdateWidget(oldWidget);
    final newText = widget.amount.toStringAsFixed(2).replaceAll('.', ','); // USER PREFERENCE: default decimal separator is comma
    if (oldWidget.amount != widget.amount && _c.text != newText) {
      _c.text = newText;
    }
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: _c,
        enabled: widget.enabled,
        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          FilteringTextInputFormatter.deny(RegExp(r'([.,].*[.,])')),
          // Limita a massimo 2 decimali
          TextInputFormatter.withFunction((oldValue, newValue) {
            final text = newValue.text;
            final parts = text.split(RegExp(r'[.,]'));
            if (parts.length == 2 && parts[1].length > 2) {
              return oldValue;
            }
            return newValue;
          }),
        ],
        onChanged: widget.onChanged,
        onEditingComplete: () {
          final raw = _c.text.trim();
          final cleaned = raw.replaceAll('.', '').replaceAll(',', '.');
          final parsed = double.tryParse(cleaned);
          if (parsed!=null) {
            // Format with comma as decimal separator
            final formatted = (widget.formatter != null ? widget.formatter!.format(parsed) : parsed.toStringAsFixed(2)).replaceAll('.', ',').replaceAll('\u00A0','');
            _c.text = formatted;
          }
        },
      ),
    );
  }
}

class _DueDateCell extends StatelessWidget {
  final DateTime date; final bool enabled; final ValueChanged<DateTime> onPick;
  const _DueDateCell({required this.date, required this.enabled, required this.onPick});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: !enabled? null : () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          firstDate: now,
          lastDate: DateTime(now.year+5),
          initialDate: date.isBefore(now)? now : date,
          helpText: 'Nuova scadenza rata',
        );
        if (picked!=null) {
          onPick(DateTime(picked.year, picked.month, picked.day, 0,0,0));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Text('${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'),
            if (enabled) const Icon(Icons.edit_calendar, size: 16, color: Colors.blueGrey)
          ],
        ),
      ),
    );
  }
}

class _CreatePlanForm extends StatefulWidget {
  final void Function(int, DateTime, double, int) onCreate;
  const _CreatePlanForm({required this.onCreate});
  @override
  State<_CreatePlanForm> createState() => _CreatePlanFormState();
}
class _CreatePlanFormState extends State<_CreatePlanForm> {
  final _formKey = GlobalKey<FormState>();
  final _nCtrl = TextEditingController(text: '3');
  final _amountCtrl = TextEditingController(text: '100,00'); // USER PREFERENCE: default decimal separator is comma
  DateTime? _firstDate;
  final _freqCtrl = TextEditingController(text: '30');

  @override void dispose(){ _nCtrl.dispose(); _amountCtrl.dispose(); _freqCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nCtrl,
                  decoration: const InputDecoration(labelText: 'Numero rate'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v){ final n = int.tryParse(v??''); if (n==null||n<1) return 'Min 1'; return null; },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Importo rata (€)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    FilteringTextInputFormatter.deny(RegExp(r'([.,].*[.,])')),
                    // Limita a massimo 2 decimali
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;
                      final parts = text.split(RegExp(r'[.,]'));
                      if (parts.length == 2 && parts[1].length > 2) {
                        return oldValue;
                      }
                      return newValue;
                    }),
                  ],
                  validator: (v){
                    final d = double.tryParse((v??'').replaceAll(',', '.'));
                    if (d==null||d<=0) return 'Importo';
                    final decimals = v?.split(RegExp(r'[.,]')).length == 2 ? v?.split(RegExp(r'[.,]'))[1].length : 0;
                    if (decimals != null && decimals > 2) return 'Max 2 decimali';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Prima scadenza'),
                  child: InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: now,
                        lastDate: DateTime(now.year+5),
                        initialDate: _firstDate ?? now.add(const Duration(days:7)),
                        helpText: 'Data prima rata',
                      );
                      if (picked!=null) setState(()=> _firstDate = picked);
                    },
                    child: Row(
                      children: [
                        Expanded(child: Text(_firstDate==null? 'Seleziona' : '${_firstDate!.day.toString().padLeft(2,'0')}/${_firstDate!.month.toString().padLeft(2,'0')}/${_firstDate!.year}')),
                        const Icon(Icons.date_range, size: 18)
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _freqCtrl,
                  decoration: const InputDecoration(labelText: 'Frequenza (giorni)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v){ final n = int.tryParse(v??''); if (n==null||n<1) return 'Min 1'; return null; },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.playlist_add),
              label: const Text('Crea piano'),
              onPressed: () {
                if (_formKey.currentState?.validate()==true && _firstDate!=null) {
                  final n = int.parse(_nCtrl.text);
                  final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
                  final freq = int.parse(_freqCtrl.text);
                  widget.onCreate(n, DateTime(_firstDate!.year, _firstDate!.month, _firstDate!.day), amount, freq);
                }
              },
            ),
          )
        ],
      ),
    );
  }
}
