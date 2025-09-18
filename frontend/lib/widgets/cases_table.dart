import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';

class CasesTableLayout {
  static const double rowHeight = 44;
  static const double actionsWidth = 56;
}

// CUSTOM IMPLEMENTATION: centralized column specification to ensure consistent flex & alignment
class _ColumnSpec {
  final String header;
  final int flex;
  final Alignment alignment;
  const _ColumnSpec(this.header, this.flex, this.alignment);
}

class CasesTableColumns {
  static const List<_ColumnSpec> columns = [
    _ColumnSpec('DEBITORE', 3, Alignment.centerLeft),
    _ColumnSpec('STATO', 2, Alignment.center),
    _ColumnSpec('ULTIMA ATTIVITÀ', 2, Alignment.center),
    _ColumnSpec('PROSSIMA SCADENZA', 2, Alignment.center),
    _ColumnSpec('RATEIZZAZIONE', 1, Alignment.center),
  ];
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
          for (final col in CasesTableColumns.columns)
            _hCell(col.header, flex: col.flex, style: style, alignment: col.alignment),
        ],
      ),
    );
  }

  Widget _hCell(String text, {required int flex, required TextStyle style, Alignment alignment = Alignment.centerLeft}) => Expanded(
        flex: flex,
        child: SizedBox(
          height: CasesTableLayout.rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              alignment: alignment,
              child: Text(
                text,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignment == Alignment.center ? TextAlign.center : TextAlign.left,
              ),
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
    final cols = CasesTableColumns.columns;
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
                _cellFromSpec(cols[0], child: Text(c.debtorName, style: baseStyle.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                _cellFromSpec(cols[1], child: _buildStateChip(c.state)),
                _cellFromSpec(cols[2], child: Text(widget.dateFormat.format(c.lastStateDate), style: baseStyle, textAlign: TextAlign.center)),
                _cellFromSpec(
                  cols[3],
                  child: Text(
                    c.nextDeadlineDate != null ? widget.dateFormat.format(c.nextDeadlineDate!) : '-',
                    style: baseStyle.copyWith(
                      color: overdue && c.nextDeadlineDate != null ? Colors.red : null,
                      fontWeight: overdue && c.nextDeadlineDate != null ? FontWeight.bold : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _cellFromSpec(
                  cols[4],
                  child: (c.hasInstallmentPlan ?? false)
                      ? const Icon(Icons.check, size: 18, color: Colors.green)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellFromSpec(_ColumnSpec spec, {required Widget child}) => Expanded(
        flex: spec.flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(alignment: spec.alignment, child: child),
        ),
      );

  // Centralized style mapping for case states (improved contrast + readability)
  // CUSTOM IMPLEMENTATION: palette for status chips with consistent bg/border alphas
  static final Map<CaseState, _CaseStateChipStyle> _stateStyles = {
    CaseState.messaInMoraDaFare: _CaseStateChipStyle('Messa in Mora da Fare', const Color(0xFF546E7A)), // Blue Grey 600
    CaseState.messaInMoraInviata: _CaseStateChipStyle('Messa in Mora Inviata', const Color(0xFFD84315)), // Deep Orange 700
    CaseState.contestazioneDaRiscontrare: _CaseStateChipStyle('Contestazione da Riscontrare', const Color(0xFFEF6C00)), // Orange 700
    CaseState.depositoRicorso: _CaseStateChipStyle('Deposito Ricorso', const Color(0xFF3949AB)), // Indigo 600
    CaseState.decretoIngiuntivoDaNotificare: _CaseStateChipStyle('Decreto Ingiuntivo da Notificare', const Color(0xFF00897B)), // Teal 600
    CaseState.decretoIngiuntivoNotificato: _CaseStateChipStyle('Decreto Ingiuntivo Notificato', const Color(0xFF00ACC1)), // Cyan 600
    CaseState.precetto: _CaseStateChipStyle('Precetto', const Color(0xFF1976D2)), // Blue 700
    CaseState.pignoramento: _CaseStateChipStyle('Pignoramento', const Color(0xFF6A1B9A)), // Purple 800
    CaseState.completata: _CaseStateChipStyle('Completata', const Color(0xFF2E7D32)), // Green 700
  };

  Widget _buildStateChip(CaseState state) {
    final style = _stateStyles[state] ?? _CaseStateChipStyle(state.name, Colors.grey.shade700);
    final fg = style.color;
    final bg = fg.withAlpha(32); // leggermente più contrastato rispetto a 24
    final borderColor = fg.withAlpha(100);
    final label = style.label;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 350),
      child: Container(
        // Nessuna larghezza fissa: il chip usa lo spazio disponibile della colonna
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: const BoxConstraints(minHeight: 30),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CaseStateChipStyle {
  final String label;
  final Color color;
  const _CaseStateChipStyle(this.label, this.color);
}
