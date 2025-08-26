import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../blocs/cases_summary/cases_summary_bloc.dart';
import '../models/cases_summary.dart';

class CasesSummarySection extends StatelessWidget {
  final VoidCallback onRetry;
  final bool showKpis; // USER PREFERENCE: allow splitting KPI and states sections
  final bool showStateCards; // USER PREFERENCE: allow splitting KPI and states sections
  const CasesSummarySection({super.key, required this.onRetry, this.showKpis = true, this.showStateCards = true});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CasesSummaryBloc, CasesSummaryState>(
      builder: (context, summaryState) {
        debugPrint('[CasesSummarySection] state = ' + summaryState.runtimeType.toString());
        if (summaryState is CasesSummaryLoading || summaryState is CasesSummaryInitial) {
          return _SummarySkeleton(showKpis: showKpis, showStateCards: showStateCards);
        }
        if (summaryState is CasesSummaryError) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(child: Text('Errore riepilogo: ${summaryState.message}')),
                  TextButton(onPressed: onRetry, child: const Text('Riprova')),
                ],
              ),
            ),
          );
        }
        if (summaryState is CasesSummaryLoaded) {
          final s = summaryState.summary;
          if (!(showKpis || showStateCards)) {
            return const SizedBox.shrink();
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900; // breakpoint
              if (isNarrow) {
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showKpis) _KpiColumn(summary: s),
                        if (showKpis && showStateCards) const SizedBox(height: 24),
                        if (showStateCards) _StatesGrid(summary: s, wrapCard: false),
                      ],
                    ),
                  ),
                );
              }
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showKpis) SizedBox(width: 260, child: _KpiColumn(summary: s)),
                      if (showKpis && showStateCards) const VerticalDivider(width: 32, thickness: 1),
                      if (showStateCards) Expanded(child: _StatesGrid(summary: s, wrapCard: false)),
                    ],
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _KpiColumn extends StatelessWidget {
  final CasesSummary summary;
  const _KpiColumn({required this.summary});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryCard(title: 'Pratiche attive', count: summary.totalActiveCases, color: Colors.blueGrey),
        const SizedBox(height: 16),
        _SummaryCard(title: 'In scadenza oggi', count: summary.dueToday, color: Colors.orange),
        const SizedBox(height: 16),
        _SummaryCard(title: 'In scadenza nei prossimi 7 giorni', count: summary.dueNext7Days, color: Colors.redAccent),
      ],
    );
  }
}

class _StatesGrid extends StatelessWidget {
  final CasesSummary summary;
  final bool wrapCard; // se false evita Card esterna (usato nel layout unificato)
  const _StatesGrid({required this.summary, this.wrapCard = true});
  @override
  Widget build(BuildContext context) {
    const orderedKeys = [
      'MESSA_IN_MORA_DA_FARE',
      'MESSA_IN_MORA_INVIATA',
      'CONTESTAZIONE_DA_RISCONTRARE',
      'DEPOSITO_RICORSO',
      'DECRETO_INGIUNTIVO_DA_NOTIFICARE',
      'DECRETO_INGIUNTIVO_NOTIFICATO',
      'PRECETTO',
      'PIGNORAMENTO',
    ];
    final stateColorMap = <String, Color>{
      'MESSA_IN_MORA_DA_FARE': Colors.blue.shade400,
      'MESSA_IN_MORA_INVIATA': Colors.indigo.shade400,
      'CONTESTAZIONE_DA_RISCONTRARE': Colors.teal.shade400,
      'DEPOSITO_RICORSO': Colors.red.shade400,
      'DECRETO_INGIUNTIVO_DA_NOTIFICARE': Colors.purple.shade400,
      'DECRETO_INGIUNTIVO_NOTIFICATO': Colors.deepPurple.shade400,
      'PIGNORAMENTO': Colors.brown.shade400,
      'PRECETTO': Colors.green.shade400,
    };
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Stati delle pratiche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 24) / 2; // gap totale 24
            return Wrap(
              spacing: 24,
              runSpacing: 12,
              children: orderedKeys.map((key) {
                final label = CasesSummary.readableStateNames[key] ?? key;
                final value = summary.states[key] ?? 0;
                final numberColor = stateColorMap[key] ?? Colors.grey.shade700;
                return SizedBox(
                  width: cellWidth,
                  child: _StateCell(label: label, value: value, numberColor: numberColor),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
    if (!wrapCard) return content;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: content,
      ),
    );
  }
}

class _StateCell extends StatefulWidget {
  final String label;
  final int value;
  final Color numberColor;
  const _StateCell({required this.label, required this.value, required this.numberColor});
  @override
  State<_StateCell> createState() => _StateCellState();
}

class _StateCellState extends State<_StateCell> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final bg = _hover ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(child: Text(widget.label, style: const TextStyle(fontSize: 14))),
            Text(widget.value.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.numberColor)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final double width;
  const _SummaryCard({required this.title, required this.count, required this.color, this.width = 260});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton({this.showKpis = true, this.showStateCards = true});
  final bool showKpis;
  final bool showStateCards;
  Widget _box({double h = 90, double w = 160}) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showKpis) ...[
          _box(w: 260),
          const SizedBox(height: 16),
          _box(w: 260),
          const SizedBox(height: 16),
          _box(w: 260),
          if (showStateCards) const SizedBox(height: 24),
        ],
        if (showStateCards) ...[
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(height: 18, width: 220, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: List.generate(8, (_) => _box(h: 52, w: 240)),
          ),
        ],
      ],
    );
  }
}
