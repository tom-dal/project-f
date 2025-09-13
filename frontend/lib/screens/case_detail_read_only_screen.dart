import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../blocs/case_detail/case_detail_bloc.dart';
import '../services/api_service.dart';
import 'case_detail_screen.dart';

/// Read-only detail view. Navigates to editable screen on user action.
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

class _CaseDetailReadOnlyView extends StatelessWidget {
  const _CaseDetailReadOnlyView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CaseDetailBloc, CaseDetailState>(
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
          // Return empty scaffold if deleted while on read-only (rare).
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEdit(context, s),
            icon: const Icon(Icons.edit),
            label: const Text('Modifica'),
          ),
          body: LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 780; // heuristic for two columns
              final content = _DetailContent(s: s, twoColumns: wide);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: content,
              );
            },
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, CaseDetailLoaded s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDetailScreen(caseId: s.caseData.id, initialCase: s.caseData),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final CaseDetailLoaded s;
  final bool twoColumns;
  const _DetailContent({required this.s, required this.twoColumns});

  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat('#,##0.00', 'it_IT');
    final List<_FieldData> fields = [
      _FieldData(label: 'Debitore', value: s.debtorName),
      _FieldData(label: 'Importo dovuto', value: '€ ${fmtCurrency.format(s.owedAmount).replaceAll('\u00A0', '')}'),
      _FieldData(label: 'Stato', value: _readableState(s.state), chipColor: _stateColor(s.state)),
      _FieldData(label: 'Scadenza corrente', value: s.nextDeadline != null ? _fmtDate(s.nextDeadline!) : '-'),
      _FieldData(label: 'Negoziazione in corso', value: s.ongoingNegotiations ? 'Sì' : 'No'),
      _FieldData(label: 'Ultima modifica stato', value: _fmtDate(s.caseData.lastStateDate)),
      if (s.caseData.createdDate != null) _FieldData(label: 'Creata il', value: _fmtDate(s.caseData.createdDate!)),
      if (s.caseData.lastModifiedDate != null) _FieldData(label: 'Aggiornata il', value: _fmtDate(s.caseData.lastModifiedDate!)),
      if (s.caseData.totalPaidAmount != null) _FieldData(label: 'Totale pagato', value: '€ ${fmtCurrency.format(s.caseData.totalPaidAmount!).replaceAll('\u00A0', '')}'),
      if (s.caseData.remainingAmount != null) _FieldData(label: 'Residuo', value: '€ ${fmtCurrency.format(s.caseData.remainingAmount!).replaceAll('\u00A0', '')}'),
    ];

    final fieldWidgets = fields.map((f) => _InfoTile(data: f)).toList();

    Widget grid;
    if (twoColumns) {
      grid = Wrap(
        spacing: 20,
        runSpacing: 16,
        children: fieldWidgets.map((w) => SizedBox(width: (MediaQuery.of(context).size.width - 60) / 2, child: w)).toList(),
      );
    } else {
      grid = Column(children: [for (final w in fieldWidgets) Padding(padding: const EdgeInsets.only(bottom: 16), child: w)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dettaglio Pratica', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        grid,
        const SizedBox(height: 28),
        _NotesSection(notes: s.notes),
        const SizedBox(height: 28),
        _InstallmentsPreview(s: s),
      ],
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

  Color _stateColor(CaseState cs) {
    switch (cs) {
      case CaseState.completata: return Colors.green;
      case CaseState.pignoramento: return Colors.deepPurple;
      case CaseState.precetto: return Colors.indigo;
      case CaseState.decretoIngiuntivoNotificato: return Colors.blueGrey;
      case CaseState.decretoIngiuntivoDaNotificare: return Colors.blue;
      case CaseState.depositoRicorso: return Colors.teal;
      case CaseState.contestazioneDaRiscontrare: return Colors.orange;
      case CaseState.messaInMoraInviata: return Colors.pink;
      case CaseState.messaInMoraDaFare: return Colors.redAccent;
    }
  }
}

class _FieldData {
  final String label;
  final String value;
  final Color? chipColor;
  _FieldData({required this.label, required this.value, this.chipColor});
}

class _InfoTile extends StatelessWidget {
  final _FieldData data;
  const _InfoTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    final bg = base.surfaceVariant.withOpacity(0.4);
    final radius = BorderRadius.circular(12);
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: radius, border: Border.all(color: base.outlineVariant.withOpacity(0.4))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: base.primary)),
        const SizedBox(height: 6),
        if (data.chipColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: data.chipColor!.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: data.chipColor!.withOpacity(0.4))),
            child: Text(data.value, style: TextStyle(color: data.chipColor!, fontWeight: FontWeight.w600)),
          )
        else
          Text(data.value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String? notes;
  const _NotesSection({required this.notes});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Note', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (notes == null || notes!.isEmpty)
            const Text('— Nessuna nota —', style: TextStyle(color: Colors.black54))
          else
            Text(notes!, style: const TextStyle(height: 1.3)),
        ]),
      ),
    );
  }
}

class _InstallmentsPreview extends StatelessWidget {
  final CaseDetailLoaded s;
  const _InstallmentsPreview({required this.s});
  @override
  Widget build(BuildContext context) {
    if (s.caseData.hasInstallmentPlan != true) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rateizzazione', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Nessun piano rate presente'),
          ]),
        ),
      );
    }

    final list = s.localInstallments.values.toList()..sort((a,b)=>a.dueDate.compareTo(b.dueDate));
    final fmt = DateFormat('dd/MM/yyyy');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Text('Rateizzazione', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              Text('(${list.length} rate)', style: const TextStyle(color: Colors.black54)),
            ],
          ),
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
        ]),
      ),
    );
  }

  void _goToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDetailScreen(caseId: s.caseData.id, initialCase: s.caseData),
      ),
    );
  }
}

