import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../blocs/case_detail/case_detail_bloc.dart';
import '../services/api_service.dart';
import 'case_detail_screen.dart';

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
                        _HeaderSection(s: s),
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
        builder: (_) => CaseDetailScreen(caseId: s.caseData.id, initialCase: s.caseData),
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
                    const SizedBox(width: 16),
                    Text('Importo: ', style: Theme.of(context).textTheme.labelLarge),
                    Text('€ ${fmtCurrency.format(s.owedAmount)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: base.primary)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
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
    );
  }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
        border: Border.all(color: base.outline.withOpacity(0.08)),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
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
          border: Border.all(color: base.outline.withOpacity(0.08)),
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
        border: Border.all(color: base.outline.withOpacity(0.08)),
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
        builder: (_) => CaseDetailScreen(caseId: s.caseData.id, initialCase: s.caseData),
      ),
    );
  }
}
