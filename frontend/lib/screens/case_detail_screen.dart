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
        final wide = MediaQuery.of(context).size.width > 780;
        return Scaffold(
          appBar: AppBar(
            title: Text('Pratica ${s.caseData.id.substring(0, 6)}'),
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Salva'),
                onPressed: s.dirty && !s.saving ? () {
                  if (_formKey.currentState?.validate()==true) {
                    context.read<CaseDetailBloc>().add(SaveCaseEdits());
                  }
                } : null,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
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
                      _EditHeaderSection(s: s, debtorCtrl: _debtorCtrl, amountCtrl: _amountCtrl, amountFocus: _amountFocus, bloc: context.read<CaseDetailBloc>()),
                      const SizedBox(height: 32),
                      _SectionTitle('Dati pratica'),
                      const SizedBox(height: 8),
                      _EditFieldsGrid(s: s, twoColumns: wide, notesCtrl: _notesCtrl, notesFocus: _notesFocus, bloc: context.read<CaseDetailBloc>(), formKey: _formKey),
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
    final base = Theme.of(context).colorScheme;
    if (s.state == CaseState.completata) {
      // USER PREFERENCE: Mostra placeholder esplicativo quando la pratica è completata
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

// --- Nuovi widget per layout Material ---
class _EditHeaderSection extends StatelessWidget {
  final CaseDetailLoaded s;
  final TextEditingController debtorCtrl;
  final TextEditingController amountCtrl;
  final FocusNode amountFocus;
  final CaseDetailBloc bloc;
  const _EditHeaderSection({required this.s, required this.debtorCtrl, required this.amountCtrl, required this.amountFocus, required this.bloc});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    // USER PREFERENCE: Assicura che il campo importo sia valorizzato con il valore attuale
    if (amountCtrl.text.isEmpty || amountCtrl.text == '0' || amountCtrl.text == '0,00') {
      amountCtrl.text = s.owedAmount != null ? NumberFormat('#,##0.00', 'it_IT').format(s.owedAmount).replaceAll('\u00A0', '') : '';
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
          TextFormField(
            controller: debtorCtrl,
            decoration: const InputDecoration(labelText: 'Debitore'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            onChanged: (v) => bloc.add(EditDebtorName(v.trim())),
            validator: (v) => (v==null||v.trim().length<2)?'Nome non valido':null,
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<CaseState>(
                  value: s.state,
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
                  onChanged: (v){
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed!=null) bloc.add(EditOwedAmount(parsed));
                  },
                  validator: (v){
                    final parsed = double.tryParse((v??'').replaceAll(',', '.'));
                    if (parsed==null || parsed<=0) return 'Importo non valido';
                    final decimals = v?.split(RegExp(r'[.,]')).length == 2 ? v?.split(RegExp(r'[.,]'))[1].length : 0;
                    if (decimals != null && decimals > 2) return 'Max 2 decimali';
                    return null;
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

class _StateChip extends StatelessWidget {
  final CaseState state;
  const _StateChip({required this.state});
  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    String label = 'Sconosciuto';
    switch (state) {
      case CaseState.messaInMoraDaFare:
        color = Colors.redAccent; label = 'Messa in Mora da Fare'; break;
      case CaseState.messaInMoraInviata:
        color = Colors.pink; label = 'Messa in Mora Inviata'; break;
      case CaseState.contestazioneDaRiscontrare:
        color = Colors.orange; label = 'Contestazione da Riscontrare'; break;
      case CaseState.depositoRicorso:
        color = Colors.teal; label = 'Deposito Ricorso'; break;
      case CaseState.decretoIngiuntivoDaNotificare:
        color = Colors.blue; label = 'DI da Notificare'; break;
      case CaseState.decretoIngiuntivoNotificato:
        color = Colors.blueGrey; label = 'DI Notificato'; break;
      case CaseState.precetto:
        color = Colors.indigo; label = 'Precetto'; break;
      case CaseState.pignoramento:
        color = Colors.deepPurple; label = 'Pignoramento'; break;
      case CaseState.completata:
        color = Colors.green; label = 'Completata'; break;
    }
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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

class _EditFieldsGrid extends StatelessWidget {
  final CaseDetailLoaded s;
  final bool twoColumns;
  final TextEditingController notesCtrl;
  final FocusNode notesFocus;
  final CaseDetailBloc bloc;
  final GlobalKey<FormState> formKey;
  const _EditFieldsGrid({required this.s, required this.twoColumns, required this.notesCtrl, required this.notesFocus, required this.bloc, required this.formKey});
  @override
  Widget build(BuildContext context) {
    final fields = [
      _EditFieldData(label: 'Ultima modifica stato', value: _fmtDate(s.caseData.lastStateDate)),
      if (s.caseData.createdDate != null) _EditFieldData(label: 'Creata il', value: _fmtDate(s.caseData.createdDate!)),
      if (s.caseData.lastModifiedDate != null) _EditFieldData(label: 'Aggiornata il', value: _fmtDate(s.caseData.lastModifiedDate!)),
      _EditFieldData(label: 'Negoziazione in corso', value: s.ongoingNegotiations ? 'Sì' : 'No'),
      if (s.caseData.totalPaidAmount != null) _EditFieldData(label: 'Totale pagato', value: '€ ${s.caseData.totalPaidAmount!.toStringAsFixed(2)}'),
      if (s.caseData.remainingAmount != null) _EditFieldData(label: 'Residuo', value: '€ ${s.caseData.remainingAmount!.toStringAsFixed(2)}'),
      if (s.caseData.createdBy != null) _EditFieldData(label: 'Creato da', value: s.caseData.createdBy!),
      if (s.caseData.lastModifiedBy != null) _EditFieldData(label: 'Ultima modifica da', value: s.caseData.lastModifiedBy!),
    ];
    final children = fields.map((f) => _EditFieldTile(data: f)).toList();
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
class _EditFieldData {
  final String label;
  final String value;
  _EditFieldData({required this.label, required this.value});
}
class _EditFieldTile extends StatelessWidget {
  final _EditFieldData data;
  const _EditFieldTile({required this.data});
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
