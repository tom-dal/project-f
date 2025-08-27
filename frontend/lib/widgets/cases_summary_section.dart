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
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
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
          if (!(showKpis || showStateCards)) return const SizedBox.shrink();
          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900; // breakpoint
              final kpiWidget = showKpis ? _KpiChips(summary: s, twoColumns: true) : const SizedBox.shrink();
              final statesWidget = showStateCards ? _StatesGrid(summary: s, wrapCard: false) : const SizedBox.shrink();
              if (isNarrow) {
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showKpis) kpiWidget,
                        if (showKpis && showStateCards) const SizedBox(height: 12),
                        if (showStateCards) statesWidget,
                      ],
                    ),
                  ),
                );
              }
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      if (c.maxWidth < 900) {
                        // layout stretto invariato
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showKpis) kpiWidget,
                            if (showKpis && showStateCards) const SizedBox(height: 12),
                            if (showStateCards) statesWidget,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showKpis)
                            Expanded(
                              flex: 2, // USER PREFERENCE: 40% left
                              child: kpiWidget,
                            ),
                          if (showKpis && showStateCards)
                            const VerticalDivider(width: 20, thickness: 1),
                          if (showStateCards)
                            Expanded(
                              flex: 3, // USER PREFERENCE: 60% right
                              child: statesWidget,
                            ),
                        ],
                      );
                    },
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

class _KpiChips extends StatelessWidget {
  final CasesSummary summary;
  final bool twoColumns; // nuova opzione per griglia 2 colonne larghezza uniforme
  const _KpiChips({required this.summary, this.twoColumns = false});

  @override
  Widget build(BuildContext context) {
    final items = <_KpiData>[
      _KpiData(label: 'Pratiche attive', value: summary.totalActiveCases, color: Colors.blueGrey),
      _KpiData(label: 'Pratiche scadute', value: summary.overdue, color: Colors.red.shade500),
      _KpiData(label: 'In scadenza oggi', value: summary.dueToday, color: Colors.orange.shade600),
      _KpiData(label: 'Prossimi 7 giorni', value: summary.dueNext7Days, color: Colors.deepOrange.shade400),
    ];
    if (!twoColumns) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((d) => _KpiChip(data: d)).toList(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0; // più aria con larghezza maggiore
        final columns = 2;
        final chipWidth = (constraints.maxWidth - spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: items
              .map((d) => SizedBox(width: chipWidth, child: _KpiChip(data: d, centerContent: true)))
              .toList(),
        );
      },
    );
  }
}

class _KpiData {
  final String label; final int value; final Color color;
  const _KpiData({required this.label, required this.value, required this.color});
}

class _KpiChip extends StatelessWidget {
  final _KpiData data;
  final bool centerContent;
  const _KpiChip({required this.data, this.centerContent = false});
  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: centerContent ? MainAxisAlignment.center : MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.value.toString(),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: data.color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            data.label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.grey.shade800, height: 1.1),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: centerContent ? TextAlign.center : TextAlign.start,
          ),
        ),
      ],
    );
    return Material(
      color: data.color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: centerContent ? Center(child: row) : row,
        ),
      ),
    );
  }
}

class _StatesGrid extends StatelessWidget {
  final CasesSummary summary;
  final bool wrapCard;
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
    final content = LayoutBuilder(
      builder: (context, constraints) {
        // Colonne dinamiche: >=880 -> 4, >=660 -> 3, altrimenti 2
        int columns;
        final w = constraints.maxWidth;
        if (w >= 880) {
          columns = 4;
        } else if (w >= 660) {
          columns = 3;
        } else {
          columns = 2;
        }
        final gap = 10.0;
        final totalGap = gap * (columns - 1);
        final chipWidth = (constraints.maxWidth - totalGap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 8,
          children: orderedKeys.map((key) {
            final label = CasesSummary.readableStateNames[key] ?? key;
            final value = summary.states[key] ?? 0;
            final color = stateColorMap[key] ?? Colors.grey.shade600;
            return SizedBox(
              width: chipWidth,
              child: _StateChip(label: label, value: value, color: color),
            );
          }).toList(),
        );
      },
    );
    if (!wrapCard) return content;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        child: content,
      ),
    );
  }
}

class _StateChip extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  const _StateChip({required this.label, required this.value, required this.color});
  @override
  State<_StateChip> createState() => _StateChipState();
}

class _StateChipState extends State<_StateChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color.withOpacity(0.07);
    final hoverColor = widget.color.withOpacity(0.14);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _hover ? hoverColor : baseColor,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.value.toString(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.color), // USER PREFERENCE: uniform number size
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.grey.shade800, height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton({this.showKpis = true, this.showStateCards = true});
  final bool showKpis;
  final bool showStateCards;

  Widget _chipSkeleton() => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 36,
          width: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
  Widget _stateSkeleton({double w = 200}) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 36, // uniformato con chip KPI
          width: w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showKpis) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: List.generate(4, (_) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: _chipSkeleton())),
                ),
                if (showStateCards) const SizedBox(height: 12),
              ],
              if (showStateCards)
                LayoutBuilder(
                  builder: (c2, cc) {
                    int cols;
                    final w = cc.maxWidth;
                    if (w >= 880) {
                      cols = 4;
                    } else if (w >= 660) {
                      cols = 3;
                    } else {
                      cols = 2;
                    }
                    const gap = 10.0;
                    final chipW = (cc.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: 8,
                      children: List.generate(8, (_) => SizedBox(width: chipW, child: _stateSkeleton(w: chipW))),
                    );
                  },
                ),
            ],
          );
        }
        // wide layout skeleton
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showKpis)
              Expanded(
                flex: 2, // USER PREFERENCE: 40% left skeleton
                child: LayoutBuilder(
                  builder: (c2, cc) {
                    const spacing = 12.0;
                    const cols = 2;
                    final chipW = (cc.maxWidth - spacing) / cols;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: 10,
                      children: List.generate(4, (_) => SizedBox(width: chipW, child: _chipSkeleton())),
                    );
                  },
                ),
              ),
            if (showKpis && showStateCards) const VerticalDivider(width: 20, thickness: 1),
            if (showStateCards)
              Expanded(
                flex: 3, // USER PREFERENCE: 60% right skeleton
                child: LayoutBuilder(
                  builder: (c3, cc) {
                    int cols;
                    final w = cc.maxWidth;
                    if (w >= 880) {
                      cols = 4;
                    } else if (w >= 660) {
                      cols = 3;
                    } else {
                      cols = 2;
                    }
                    const gap = 10.0;
                    final chipW = (cc.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: 8,
                      children: List.generate(8, (_) => SizedBox(width: chipW, child: _stateSkeleton(w: chipW))),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
