import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../screens/case_detail_read_only_screen.dart';

class CaseList extends StatelessWidget {
  final List<DebtCase> cases;
  final DateFormat dateFormat;
  const CaseList({super.key, required this.cases, required this.dateFormat});

  static const double wDebtor = 220;
  static const double wState = 140;
  static const double wLastDate = 120;
  static const double wDeadline = 110;
  static const double wActions = 60; // ridotto, solo icona apri
  static const double rowHeight = 52; // uniform row height
  static const double _horizontalPadding = 0; // extra spacing if needed
  static const double totalWidth = wDebtor + wState + wLastDate + wDeadline + wActions + _horizontalPadding;

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return const Center(child: Text('Nessuna pratica trovata'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            ...cases.map((c) => _CaseRow(
                  debtCase: c,
                  dateFormat: dateFormat,
                  onOpen: () => _openDetail(context, c),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    TextStyle style = const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13);
    return Container(
      height: rowHeight,
      color: Colors.grey[100],
      child: Row(
        children: [
          _hCell('DEBITORE', wDebtor, style),
          _hCell('STATO ATTUALE', wState, style),
          _hCell('DATA ULTIMA ATTIVITÀ', wLastDate, style),
          _hCell('SCADENZA', wDeadline, style),
          _hCell('', wActions, style),
        ],
      ),
    );
  }

  Widget _hCell(String text, double w, TextStyle style) => SizedBox(
        width: w,
        height: rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      );

  void _openDetail(BuildContext context, DebtCase debtCase) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DebtCaseBloc>(),
          child: CaseDetailReadOnlyScreen(caseId: debtCase.id, initialCase: debtCase),
        ),
      ),
    );
  }
}

class _CaseRow extends StatefulWidget {
  final DebtCase debtCase;
  final DateFormat dateFormat;
  final VoidCallback onOpen;
  const _CaseRow({required this.debtCase, required this.dateFormat, required this.onOpen});
  @override
  State<_CaseRow> createState() => _CaseRowState();
}

class _CaseRowState extends State<_CaseRow> {
  bool hovering = false;
  static const double wDebtor = CaseList.wDebtor;
  static const double wState = CaseList.wState;
  static const double wLastDate = CaseList.wLastDate;
  static const double wDeadline = CaseList.wDeadline;
  static const double wActions = CaseList.wActions;
  static const double rowHeight = CaseList.rowHeight;

  @override
  Widget build(BuildContext context) {
    final c = widget.debtCase;
    final isOverdue = c.nextDeadlineDate != null && c.nextDeadlineDate!.isBefore(DateTime.now());
    final bg = hovering ? Colors.blue.withAlpha(25) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Container(
          height: rowHeight,
            color: bg,
          child: Row(
            children: [
              _cell(width: wDebtor, child: Text(c.debtorName, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              _cell(width: wState, child: buildStateChip(c.state)),
              _cell(width: wLastDate, child: Text(widget.dateFormat.format(c.lastStateDate))),
              _cell(
                width: wDeadline,
                child: Text(
                  c.nextDeadlineDate != null ? widget.dateFormat.format(c.nextDeadlineDate!) : '-',
                  style: TextStyle(
                    color: isOverdue && c.nextDeadlineDate != null ? Colors.red : null,
                    fontWeight: isOverdue && c.nextDeadlineDate != null ? FontWeight.bold : null,
                  ),
                ),
              ),
              _cell(
                width: wActions,
                child: IconButton(
                  tooltip: 'Apri dettaglio',
                  icon: const Icon(Icons.open_in_new, size: 18, color: Colors.blue),
                  onPressed: widget.onOpen,
                  splashRadius: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell({required double width, required Widget child}) => SizedBox(
        width: width,
        height: rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );
}

Widget buildStateChip(CaseState state) {
  Color color = Colors.grey;
  String label = 'Sconosciuto';
  switch (state) {
    case CaseState.messaInMoraDaFare:
      color = Colors.grey; label = 'Messa in Mora da Fare'; break;
    case CaseState.messaInMoraInviata:
      color = Colors.red; label = 'Messa in Mora Inviata'; break;
    case CaseState.contestazioneDaRiscontrare:
      color = Colors.yellow; label = 'Contestazione da Riscontrare'; break;
    case CaseState.depositoRicorso:
      color = Colors.orange; label = 'Deposito Ricorso'; break;
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
  );
}
