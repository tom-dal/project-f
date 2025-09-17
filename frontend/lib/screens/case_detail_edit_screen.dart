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
        return Scaffold(
          appBar: AppBar(
            title: Text('Pratica ${s.caseData.id.substring(0, 6)}'),
            actions: [
              // Reset button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton(
                  onPressed: (s.dirty && !s.saving) ? () {
                    // Unfocus to allow controllers to be overwritten by listener
                    _amountFocus.unfocus();
                    _notesFocus.unfocus();
                    FocusScope.of(context).unfocus();
                    context.read<CaseDetailBloc>().add(ResetCaseEdits());
                  } : null,
                  style: TextButton.styleFrom(
                    foregroundColor: (s.dirty && !s.saving) ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Row(
                    children: const [Icon(Icons.restart_alt, size: 18), SizedBox(width: 4), Text('Reset')],
                  ),
                ),
              ),
              // Save button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton(
                  onPressed: (s.dirty && !s.saving) ? () {
                    if (_formKey.currentState?.validate() ?? false) {
                      context.read<CaseDetailBloc>().add(SaveCaseEdits());
                    } else { setState((){}); }
                  } : null,
                  style: TextButton.styleFrom(
                    foregroundColor: (s.dirty && !s.saving) ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor,
                    backgroundColor: (s.dirty && !s.saving) ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Row(
                    children: const [Icon(Icons.save, size: 18), SizedBox(width: 6), Text('Salva')],
                  ),
                ),
              ),
            ],
            bottom: s.saving ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(minHeight: 3),
            ) : null,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN
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
                              bloc: context.read<CaseDetailBloc>(),
                            ),
                            const SizedBox(height: 28),
                            _NotesCard(
                              s: s,
                              notesCtrl: _notesCtrl,
                              notesFocus: _notesFocus,
                              bloc: context.read<CaseDetailBloc>(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      // RIGHT COLUMN
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EditablePaymentsCard(s: s, bloc: context.read<CaseDetailBloc>()),
                            const SizedBox(height: 28),
                            const _SimplePlaceholderCard(title: 'Rateizzazione', text: 'Gestione rate disponibile in vista dedicata.'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nessun piano presente', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Crea un piano di rateizzazione. Le singole rate potranno essere modificate successivamente.'),
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
                      DataCell(Text('€ ${_itFormatter.format(inst.amount)}')),
                      DataCell(Text(inst.dueDate != null ? _fmtDate(inst.dueDate!) : '-')),
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
  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

// --- COMPONENTI UI ---
class _EditableFieldsCard extends StatelessWidget {
  final CaseDetailLoaded s;
  final TextEditingController debtorCtrl;
  final TextEditingController amountCtrl;
  final FocusNode amountFocus;
  final CaseDetailBloc bloc;
  const _EditableFieldsCard({required this.s, required this.debtorCtrl, required this.amountCtrl, required this.amountFocus, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dirtyDebtor = s.debtorName != s.caseData.debtorName;
    final dirtyAmount = s.owedAmount != s.caseData.owedAmount;
    final dirtyState = s.state != s.caseData.state;
    final dirtyNeg = s.ongoingNegotiations != (s.caseData.ongoingNegotiations ?? false);

    InputDecoration _dec(String label,{Widget? prefixIcon, bool dirty=false, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: cs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withAlpha(60))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: dirty? cs.primary.withAlpha(160): cs.outline.withAlpha(70))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 2)),
    );

    final debtorField = TextFormField(
      controller: debtorCtrl,
      decoration: _dec('Debitore', dirty: dirtyDebtor, hint: 'Nome e cognome / Ragione sociale'),
      onChanged: (v)=> bloc.add(EditDebtorName(v)),
      validator: (v){ if(v==null || v.trim().isEmpty) return 'Obbligatorio'; if(v.trim().length<2) return 'Min 2 caratteri'; return null; },
    );
    final stateField = _StateDropdown(dirty: dirtyState, value: s.state, onChanged: (st)=> bloc.add(EditState(st)));
    final amountField = TextFormField(
      controller: amountCtrl,
      focusNode: amountFocus,
      decoration: _dec('Importo dovuto', dirty: dirtyAmount, prefixIcon: const Icon(Icons.euro)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      validator: (v){ if(v==null || v.trim().isEmpty) return 'Obbligatorio'; final p = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')); if(p==null || p<=0) return 'Valore non valido'; return null; },
      onChanged: (v){ final p = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')); if(p!=null) bloc.add(EditOwedAmount(p)); },
    );
    final negotiationField = _NegotiationSwitch(dirty: dirtyNeg, value: s.ongoingNegotiations, onChanged: (val)=> bloc.add(EditOngoingNegotiations(val)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24,24,24,24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dettagli principali', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          // Row 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: debtorField),
              const SizedBox(width: 24),
              SizedBox(width: 260, child: stateField),
            ],
          ),
          const SizedBox(height: 20),
          // Row 2
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: amountField),
                const SizedBox(width: 24),
                SizedBox(width: 260, child: negotiationField),
              ],
            ),
        ],
      ),
    );
  }
}

class _StateDropdown extends StatelessWidget {
  final bool dirty; final CaseState value; final ValueChanged<CaseState> onChanged;
  const _StateDropdown({required this.dirty, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = dirty? cs.primary.withAlpha(160): cs.outline.withAlpha(70);
    return Tooltip(
      message: 'Modifica lo stato procedurale della pratica',
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Stato',
          filled: true,
          fillColor: cs.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<CaseState>(
            isExpanded: true,
            value: value,
            onChanged: (v){ if(v!=null) onChanged(v); },
            items: CaseState.values.map((csVal){
              return DropdownMenuItem(
                value: csVal,
                child: Text(_label(csVal), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
  String _label(CaseState st){
    switch(st){
      case CaseState.messaInMoraDaFare: return 'Messa in Mora da Fare';
      case CaseState.messaInMoraInviata: return 'Messa in Mora Inviata';
      case CaseState.contestazioneDaRiscontrare: return 'Contestazione da Riscontrare';
      case CaseState.depositoRicorso: return 'Deposito Ricorso';
      case CaseState.decretoIngiuntivoDaNotificare: return 'DI da Notificare';
      case CaseState.decretoIngiuntivoNotificato: return 'DI Notificato';
      case CaseState.precetto: return 'Precetto';
      case CaseState.pignoramento: return 'Pignoramento';
      case CaseState.completata: return 'Completata';
    }
  }
}

class _NegotiationSwitch extends StatelessWidget {
  final bool dirty; final bool value; final ValueChanged<bool> onChanged;
  const _NegotiationSwitch({required this.dirty, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text('Negoziazione in corso', style: Theme.of(context).textTheme.labelLarge),
        Switch(
          value: value,
          onChanged: (v)=> onChanged(v),
        )
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  final CaseDetailLoaded s; final TextEditingController notesCtrl; final FocusNode notesFocus; final CaseDetailBloc bloc;
  const _NotesCard({required this.s, required this.notesCtrl, required this.notesFocus, required this.bloc});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dirty = (s.notes ?? '') != (s.caseData.notes ?? '');
    final hasContent = (notesCtrl.text.trim().isNotEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Note', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
              TextButton.icon(
                onPressed: hasContent ? () {
                  notesCtrl.clear();
                  bloc.add(EditNotes(null));
                } : null,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Svuota'),
                style: TextButton.styleFrom(
                  foregroundColor: hasContent ? cs.primary : Theme.of(context).disabledColor,
                ),
              )
            ],
          ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withAlpha(60))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: dirty? cs.primary.withAlpha(160): cs.outline.withAlpha(70))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 2)),
            ),
            onChanged: (v)=> bloc.add(EditNotes(v.isEmpty? null : v)),
          ),
        ],
      ),
    );
  }
}

class _SimplePlaceholderCard extends StatelessWidget {
  final String title; final String text;
  const _SimplePlaceholderCard({required this.title, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24,18,24,20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _EditablePaymentsCard extends StatelessWidget {
  final CaseDetailLoaded s; final CaseDetailBloc bloc;
  const _EditablePaymentsCard({required this.s, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final payments = _extractPayments();
    final fmtAmount = NumberFormat('#,##0.00', 'it_IT');
    final residuo = s.caseData.remainingAmount ?? (s.owedAmount - (s.caseData.totalPaidAmount ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24,18,24,20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pagamenti', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (payments.isEmpty) const Text('Nessun pagamento registrato', style: TextStyle(color: Colors.black54))
          else Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (s.caseData.totalPaidAmount!=null) Text('Totale pagato: € ${fmtAmount.format(s.caseData.totalPaidAmount!)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              _EditablePaymentsTable(payments: payments, hasInstallmentPlan: s.caseData.hasInstallmentPlan == true, owedAmount: s.owedAmount, onEdit: (row){ _openEditDialog(context, row); }, onDelete: (row){ _confirmDelete(context, row); }),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditDialog(BuildContext context, _EditablePaymentRow row){
    final hasPlan = s.caseData.hasInstallmentPlan == true;
    final fmtAmount = NumberFormat('#,##0.00', 'it_IT');
    final controller = TextEditingController(text: fmtAmount.format(row.amount).replaceAll('\u00A0',''));
    DateTime selectedDate = row.date;
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx){
        return StatefulBuilder(builder: (ctx,setState){
          double sumOthers = _extractPayments().where((p)=>p.id!=row.id).fold(0.0,(a,b)=>a+b.amount);
          double? parsedAmount; if(!hasPlan){
            parsedAmount = double.tryParse(controller.text.replaceAll('.', '').replaceAll(',', '.'));
          } else { parsedAmount = row.amount; }
          final overLimit = !hasPlan && parsedAmount!=null && (sumOthers + parsedAmount) > s.owedAmount + 0.0001; // tolleranza floating
          return AlertDialog(
            title: const Text('Modifica pagamento'),
            content: SizedBox(
              width: 380,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasPlan) TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Importo'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      onChanged: (_){ setState((){}); },
                      validator: (v){
                        if (v==null || v.trim().isEmpty) return 'Obbligatorio';
                        final val = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));
                        if (val==null || val<=0) return 'Valore non valido';
                        if ((sumOthers + val) > s.owedAmount + 0.0001) return 'Somma pagamenti supera importo dovuto';
                        return null;
                      },
                    ) else TextFormField(
                      enabled: false,
                      initialValue: fmtAmount.format(row.amount),
                      decoration: const InputDecoration(labelText: 'Importo (bloccato - piano rate)')
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 0)),
                        );
                        if (picked!=null){ setState(()=> selectedDate = picked); }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Data pagamento'),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text('${selectedDate.day.toString().padLeft(2,'0')}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.year}'),
                          ],
                        ),
                      ),
                    ),
                    if (overLimit) Padding(
                      padding: const EdgeInsets.only(top:8.0),
                      child: Text('Somma pagamenti supera importo dovuto', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                onPressed: () {
                  if (hasPlan){
                    // Solo data
                    if (selectedDate != row.date){
                      bloc.add(UpdatePaymentEvent(paymentId: row.id, paymentDate: selectedDate));
                    }
                    Navigator.pop(ctx);
                  } else {
                    if (formKey.currentState?.validate() ?? false){
                      final val = double.parse(controller.text.replaceAll('.', '').replaceAll(',', '.'));
                      final changedAmount = (val - row.amount).abs() > 0.0001;
                      final changedDate = selectedDate != row.date;
                      if (changedAmount || changedDate){
                        bloc.add(UpdatePaymentEvent(paymentId: row.id, amount: changedAmount? val : null, paymentDate: changedDate? selectedDate : null));
                      }
                      Navigator.pop(ctx);
                    }
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          );
        });
      }
    );
  }

  void _confirmDelete(BuildContext context, _EditablePaymentRow row){
    showDialog(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Eliminare pagamento?'),
        content: Text('Confermi eliminazione del pagamento di € ${NumberFormat('#,##0.00','it_IT').format(row.amount)} del ${_fmtDate(row.date)}?'),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: (){
              Navigator.pop(ctx);
              bloc.add(DeletePaymentEvent(row.id));
            },
            child: const Text('Elimina'),
          ),
        ],
      )
    );
  }

  List<_EditablePaymentRow> _extractPayments(){
    final list = <_EditablePaymentRow>[];
    final raw = s.caseData.payments;
    if (raw==null) return list;
    for (final p in raw) {
      try {
        if (p is Map) {
          final id = p['id']?.toString();
          final amountRaw = p['amount'];
          double? amount; if (amountRaw is num) amount = amountRaw.toDouble(); else if (amountRaw is String) amount = double.tryParse(amountRaw.replaceAll(',', '.'));
          final dateRaw = p['paymentDate'];
          DateTime? date; if (dateRaw is String && dateRaw.isNotEmpty){ try { date = DateTime.parse(dateRaw.length==10 && !dateRaw.contains('T') ? dateRaw : dateRaw); } catch(_){}}
          if (id!=null && amount!=null && date!=null){
            list.add(_EditablePaymentRow(id: id, amount: amount, date: date));
          }
        }
      } catch(_){ /* ignore */ }
    }
    list.sort((a,b)=> a.date.compareTo(b.date));
    return list;
  }

  String _fmtDate(DateTime d)=> '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

class _EditablePaymentRow { final String id; final double amount; final DateTime date; _EditablePaymentRow({required this.id, required this.amount, required this.date}); }

class _EditablePaymentsTable extends StatelessWidget {
  final List<_EditablePaymentRow> payments; final bool hasInstallmentPlan; final double owedAmount; final void Function(_EditablePaymentRow) onEdit; final void Function(_EditablePaymentRow) onDelete;
  const _EditablePaymentsTable({required this.payments, required this.hasInstallmentPlan, required this.owedAmount, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('dd/MM/yyyy');
    final fmtAmount = NumberFormat('#,##0.00', 'it_IT');
    final maxRowsNoScroll = 6;
    final rows = payments.asMap().entries.map((entry){
      final index = entry.key; final p = entry.value; final idx = payments.length - index; // descending numbering
      return DataRow(cells: [
        DataCell(Text('€ ${fmtAmount.format(p.amount)}')),
        DataCell(Text(fmtDate.format(p.date))),
        DataCell(Row(
          children: [
            IconButton(tooltip: 'Modifica', icon: const Icon(Icons.edit, size:18), onPressed: ()=> onEdit(p)),
            IconButton(tooltip: 'Elimina', icon: const Icon(Icons.delete_outline, size:18, color: Colors.red), onPressed: ()=> onDelete(p)),
          ],
        )),
      ]);
    }).toList();
    final table = DataTable(
      columns: const [
        DataColumn(label: Text('Importo')),
        DataColumn(label: Text('Data')),
        DataColumn(label: SizedBox.shrink()),
      ],
      rows: rows,
      headingRowHeight: 36,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 52,
    );
    if (payments.length <= maxRowsNoScroll) return table;
    final height = 52 * maxRowsNoScroll + 40;
    return SizedBox(height: height.toDouble(), child: SingleChildScrollView(child: table));
  }
}
