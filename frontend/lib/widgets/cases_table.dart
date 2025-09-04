import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';

class CasesTableLayout {
  static const double rowHeight = 44;
  static const double actionsWidth = 56;
}

class CasesTableHeader extends StatelessWidget {
  const CasesTableHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, letterSpacing: .3, color: Colors.black87);
    return Container(
      height: CasesTableLayout.rowHeight,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        children: [
          _hCell('DEBITORE', flex: 3, style: style),
          _hCell('STATO', flex: 2, style: style),
          _hCell('ULTIMA ATTIVITÀ', flex: 2, style: style),
            _hCell('SCADENZA', flex: 2, style: style),
          SizedBox(
            width: CasesTableLayout.actionsWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(alignment: Alignment.center, child: Text('', style: style)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String text, {required int flex, required TextStyle style}) => Expanded(
        flex: flex,
        child: SizedBox(
          height: CasesTableLayout.rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      );
}

class CasesTableDataRow extends StatefulWidget {
  final DebtCase debtCase;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  const CasesTableDataRow({super.key, required this.debtCase, required this.dateFormat, required this.onTap});
  @override
  State<CasesTableDataRow> createState() => _CasesTableDataRowState();
}

class _CasesTableDataRowState extends State<CasesTableDataRow> {
  bool hovering = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.debtCase;
    final overdue = c.nextDeadlineDate != null && c.nextDeadlineDate!.isBefore(DateTime.now());
    final baseStyle = const TextStyle(fontSize: 13);
    final bg = hovering ? Colors.blue.withAlpha(18) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: CasesTableLayout.rowHeight,
            child: Row(
              children: [
                _cell(flex: 3, child: Text(c.debtorName, style: baseStyle.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                _cell(flex: 2, child: _buildStateChip(c.state)),
                _cell(flex: 2, child: Text(widget.dateFormat.format(c.lastStateDate), style: baseStyle)),
                _cell(
                  flex: 2,
                  child: Text(
                    c.nextDeadlineDate != null ? widget.dateFormat.format(c.nextDeadlineDate!) : '-',
                    style: baseStyle.copyWith(
                      color: overdue && c.nextDeadlineDate != null ? Colors.red : null,
                      fontWeight: overdue && c.nextDeadlineDate != null ? FontWeight.bold : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: CasesTableLayout.actionsWidth,
                  child: IconButton(
                    tooltip: 'Apri dettaglio',
                    icon: const Icon(Icons.open_in_new, size: 18, color: Colors.blue),
                    onPressed: widget.onTap,
                    splashRadius: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell({required int flex, required Widget child}) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );

  String _getStateDisplayName(CaseState state) {
    switch (state) {
      case CaseState.messaInMoraDaFare:
        return 'Messa in Mora da Fare';
      case CaseState.messaInMoraInviata:
        return 'Messa in Mora Inviata';
      case CaseState.contestazioneDaRiscontrare:
        return 'Contestazione da Riscontrare';
      case CaseState.depositoRicorso:
        return 'Deposito Ricorso';
      case CaseState.decretoIngiuntivoDaNotificare:
        return 'Decreto Ingiuntivo da Notificare';
      case CaseState.decretoIngiuntivoNotificato:
        return 'Decreto Ingiuntivo Notificato';
      case CaseState.precetto:
        return 'Precetto';
      case CaseState.pignoramento:
        return 'Pignoramento';
      case CaseState.completata:
        return 'Completata';
    }
  }

  Widget _buildStateChip(CaseState state) {
    Color color = Colors.grey;
    switch (state) {
      case CaseState.messaInMoraDaFare: color = Colors.grey; break;
      case CaseState.messaInMoraInviata: color = Colors.red; break;
      case CaseState.contestazioneDaRiscontrare: color = Colors.amber; break;
      case CaseState.depositoRicorso: color = Colors.orange; break;
      case CaseState.decretoIngiuntivoDaNotificare: color = Colors.green; break;
      case CaseState.decretoIngiuntivoNotificato: color = Colors.teal; break;
      case CaseState.precetto: color = Colors.blue; break;
      case CaseState.pignoramento: color = Colors.purple; break;
      case CaseState.completata: color = Colors.green; break;
    }
    final label = _getStateDisplayName(state);
    return SizedBox(
      width: 140, // fixed width for all badges
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(60)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
