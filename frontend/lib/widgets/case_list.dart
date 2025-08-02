import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import 'case_details_dialog.dart';

class CaseList extends StatelessWidget {
  final List<DebtCase> cases;
  final DateFormat dateFormat;

  const CaseList({
    super.key,
    required this.cases,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return const Center(
        child: Text('Nessuna pratica trovata'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 48,
        ),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(200), // DEBITORE
            1: FixedColumnWidth(150), // FASE ATTUALE
            2: FixedColumnWidth(150), // DATA ULTIMA ATTIVITÀ
            3: FixedColumnWidth(120), // SCADENZA
            4: FixedColumnWidth(100), // Azioni - ridotta per testare
          },
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(
                color: Colors.grey[100],
              ),
              children: const [
                _HeaderCell('DEBITORE'),
                _HeaderCell('STATO ATTUALE'),
                _HeaderCell('DATA ULTIMA ATTIVITÀ'),
                _HeaderCell('SCADENZA'),
                _HeaderCell(''), // Rimossa intestazione "AZIONI"
              ],
            ),
            // Data rows
            ...cases.map((debtCase) {
              final isOverdue = debtCase.nextDeadlineDate != null &&
                               debtCase.nextDeadlineDate!.isBefore(DateTime.now());
              return TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                children: [
                  _DataCell(
                    child: Text(
                      debtCase.debtorName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _DataCell(
                    child: _buildStateChip(debtCase.state),
                  ),
                  _DataCell(
                    child: Text(dateFormat.format(debtCase.lastStateDate)),
                  ),
                  _DataCell(
                    child: Text(
                      debtCase.nextDeadlineDate != null
                          ? dateFormat.format(debtCase.nextDeadlineDate!)
                          : '-',
                      style: TextStyle(
                        color: isOverdue && debtCase.nextDeadlineDate != null ? Colors.red : null,
                        fontWeight: isOverdue && debtCase.nextDeadlineDate != null ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                  _DataCell(
                    child: Container(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () => _showCaseDetails(context, debtCase),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.visibility,
                                size: 18,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteCaseConfirmation(context, debtCase),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateChip(CaseState state) {
    // Initialize with default values
    Color color = Colors.grey;
    String label = 'Sconosciuto';

    switch (state) {
      case CaseState.messaInMoraDaFare:
        color = Colors.grey;
        label = 'Messa in Mora da Fare';
        break;
      case CaseState.messaInMoraInviata:
        color = Colors.red;
        label = 'Messa in Mora Inviata';
        break;
      case CaseState.contestazioneDaRiscontrare:
        color = Colors.yellow;
        label = 'Contestazione da Riscontrare';
        break;
      case CaseState.depositoRicorso:
        color = Colors.orange;
        label = 'Deposito Ricorso';
        break;
      case CaseState.decretoIngiuntivoDaNotificare:
        color = Colors.green;
        label = 'Decreto Ingiuntivo da Notificare';
        break;
      case CaseState.decretoIngiuntivoNotificato:
        color = Colors.teal;
        label = 'Decreto Ingiuntivo Notificato';
        break;
      case CaseState.precetto:
        color = Colors.blue;
        label = 'Precetto';
        break;
      case CaseState.pignoramento:
        color = Colors.purple;
        label = 'Pignoramento';
        break;
      case CaseState.completata:
        color = Colors.green;
        label = 'Completata';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showCaseDetails(BuildContext context, DebtCase debtCase) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<DebtCaseBloc>(),
        child: CaseDetailsDialog(debtCase: debtCase),
      ),
    );
  }

  void _deleteCaseConfirmation(BuildContext context, DebtCase debtCase) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<DebtCaseBloc>(),
        child: AlertDialog(
          title: const Text('Conferma Eliminazione'),
          content: Text(
            'Sei sicuro di voler eliminare la pratica per ${debtCase.debtorName}? Questa azione non può essere annullata.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                // Usa il context originale invece di dialogContext per il BlocProvider
                context.read<DebtCaseBloc>().add(DeleteDebtCase(debtCase.id));
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pratica eliminata con successo')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Elimina'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final Widget child;

  const _DataCell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );
  }
}