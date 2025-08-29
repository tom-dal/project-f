import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../blocs/cases_summary/cases_summary_bloc.dart';
import '../models/cases_summary.dart';
import '../models/case_state.dart';

class CasesSummarySection extends StatelessWidget {
  final VoidCallback onRetry;
  final bool showKpis; // USER PREFERENCE: allow splitting KPI and states sections
  final bool showStateCards; // USER PREFERENCE: allow splitting KPI and states sections
  final List<CaseState> activeStates; // current filter states
  final DateTime? deadlineFrom;
  final DateTime? deadlineTo;
  final void Function(List<CaseState>) onSetStates;
  final void Function(DateTime? from, DateTime? to) onSetDeadlineRange;
  final VoidCallback onClearAllFilters;
  const CasesSummarySection({
    super.key,
    required this.onRetry,
    this.showKpis = true,
    this.showStateCards = true,
    required this.activeStates,
    required this.deadlineFrom,
    required this.deadlineTo,
    required this.onSetStates,
    required this.onSetDeadlineRange,
    required this.onClearAllFilters,
  });

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
              final kpiWidget = showKpis ? _KpiChips(
                summary: s,
                twoColumns: true,
                activeStates: activeStates,
                deadlineFrom: deadlineFrom,
                deadlineTo: deadlineTo,
                onSetStates: onSetStates,
                onSetDeadlineRange: onSetDeadlineRange,
                onClearAllFilters: onClearAllFilters,
              ) : const SizedBox.shrink();
              final statesWidget = showStateCards ? _StatesGrid(
                summary: s,
                wrapCard: false,
                activeStates: activeStates,
                onSetStates: onSetStates,
                onClearAllFilters: onClearAllFilters,
                onResetDeadlines: () => onSetDeadlineRange(null, null),
              ) : const SizedBox.shrink();
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
  final List<CaseState> activeStates;
  final DateTime? deadlineFrom;
  final DateTime? deadlineTo;
  final void Function(List<CaseState>) onSetStates;
  final void Function(DateTime? from, DateTime? to) onSetDeadlineRange;
  final VoidCallback onClearAllFilters;
  const _KpiChips({
    required this.summary,
    this.twoColumns = false,
    required this.activeStates,
    required this.deadlineFrom,
    required this.deadlineTo,
    required this.onSetStates,
    required this.onSetDeadlineRange,
    required this.onClearAllFilters,
  });

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  bool _sameDay(DateTime a, DateTime b) => a.year==b.year && a.month==b.month && a.day==b.day;

  bool _isActiveAttive() {
    if (deadlineFrom != null || deadlineTo != null) return false;
    final nonCompleted = CaseState.values.where((c) => c != CaseState.completata).toList();
    if (activeStates.length != nonCompleted.length) return false;
    final setA = activeStates.toSet();
    final setB = nonCompleted.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }
  bool _isActiveOverdue() {
    final today = _startOfDay(DateTime.now());
    if (deadlineFrom != null) return false;
    if (deadlineTo == null) return false;
    final toDay = _startOfDay(deadlineTo!);
    return toDay.isBefore(today); // any past to-date with no from
  }
  bool _isActiveToday() {
    if (deadlineFrom == null || deadlineTo == null) return false;
    final today = DateTime.now();
    return _sameDay(deadlineFrom!, today) && _sameDay(deadlineTo!, today);
  }
  bool _isActiveNext7() {
    if (deadlineFrom == null || deadlineTo == null) return false;
    final today = _startOfDay(DateTime.now());
    final plus7 = _startOfDay(today.add(const Duration(days: 7)));
    return _sameDay(deadlineFrom!, today) && _sameDay(deadlineTo!, plus7);
  }

  void _applyAttive() {
    final nonCompleted = CaseState.values.where((c) => c != CaseState.completata).toList();
    if (_isActiveAttive()) {
      onClearAllFilters(); // toggle off to clear
    } else {
      onSetStates(nonCompleted);
      onSetDeadlineRange(null, null);
    }
  }
  void _applyOverdue() {
    if (_isActiveOverdue()) {
      onClearAllFilters();
    } else {
      final yesterday = DateTime.now().subtract(const Duration(days:1));
      onSetStates([]); // overwrite states
      onSetDeadlineRange(null, _endOfDay(yesterday));
    }
  }
  void _applyToday() {
    if (_isActiveToday()) {
      onClearAllFilters();
    } else {
      final today = DateTime.now();
      final from = _startOfDay(today);
      final to = _endOfDay(today);
      print('[DEBUG QUICK FILTER] TODAY apply range from=' + from.toIso8601String() + ' to=' + to.toIso8601String());
      onSetStates([]);
      onSetDeadlineRange(from, to);
    }
  }
  void _applyNext7() {
    if (_isActiveNext7()) {
      onClearAllFilters();
    } else {
      final today = _startOfDay(DateTime.now());
      final plus7 = today.add(const Duration(days:7));
      onSetStates([]);
      onSetDeadlineRange(today, _endOfDay(plus7));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <_KpiData>[
      _KpiData(id: 'ATTIVE', label: 'Pratiche attive', value: summary.totalActiveCases, color: Colors.blueGrey, active: _isActiveAttive(), onTap: _applyAttive),
      _KpiData(id: 'OVERDUE', label: 'Pratiche scadute', value: summary.overdue, color: Colors.red.shade500, active: _isActiveOverdue(), onTap: _applyOverdue),
      _KpiData(id: 'TODAY', label: 'In scadenza oggi', value: summary.dueToday, color: Colors.orange.shade600, active: _isActiveToday(), onTap: _applyToday),
      _KpiData(id: 'NEXT7', label: 'Scadenza nei prossimi 7 giorni', value: summary.dueNext7Days, color: Colors.deepOrange.shade400, active: _isActiveNext7(), onTap: _applyNext7),
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
  final String id;
  final String label; final int value; final Color color; final bool active; final VoidCallback onTap;
  const _KpiData({required this.id, required this.label, required this.value, required this.color, required this.active, required this.onTap});
}

class _KpiChip extends StatelessWidget {
  final _KpiData data;
  final bool centerContent;
  const _KpiChip({required this.data, this.centerContent = false});
  @override
  Widget build(BuildContext context) {
    final active = data.active;
    final bg = active ? data.color.withOpacity(0.18) : data.color.withOpacity(0.07);
    final border = active ? Border.all(color: data.color, width: 1.2) : null;
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
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: data.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(border: border, borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          // removed full-width to allow 2-column layout
          child: centerContent ? Center(child: row) : row,
        ),
      ),
    );
  }
}

class _StatesGrid extends StatelessWidget {
  final CasesSummary summary;
  final bool wrapCard;
  final List<CaseState> activeStates;
  final void Function(List<CaseState>) onSetStates;
  final VoidCallback onClearAllFilters;
  final VoidCallback onResetDeadlines; // clear deadlines when selecting a state
  const _StatesGrid({required this.summary, this.wrapCard = true, required this.activeStates, required this.onSetStates, required this.onClearAllFilters, required this.onResetDeadlines});
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
              child: _StateChip(
                label: label,
                value: value,
                color: color,
                active: activeStates.any((cs) => cs.name.toUpperCase() == key),
                onTap: () {
                  // toggle logic: overwrite or clear
                  final enumVal = _mapRawToCaseState(key);
                  if (enumVal == null) return;
                  if (activeStates.length == 1 && activeStates.first == enumVal) {
                    onSetStates([]); // toggle off
                  } else {
                    onSetStates([enumVal]);
                    onResetDeadlines(); // overwrite deadlines per requisito
                  }
                },
              ),
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
  CaseState? _mapRawToCaseState(String raw) {
    switch(raw) {
      case 'MESSA_IN_MORA_DA_FARE': return CaseState.messaInMoraDaFare;
      case 'MESSA_IN_MORA_INVIATA': return CaseState.messaInMoraInviata;
      case 'CONTESTAZIONE_DA_RISCONTRARE': return CaseState.contestazioneDaRiscontrare;
      case 'DEPOSITO_RICORSO': return CaseState.depositoRicorso;
      case 'DECRETO_INGIUNTIVO_DA_NOTIFICARE': return CaseState.decretoIngiuntivoDaNotificare;
      case 'DECRETO_INGIUNTIVO_NOTIFICATO': return CaseState.decretoIngiuntivoNotificato;
      case 'PRECETTO': return CaseState.precetto;
      case 'PIGNORAMENTO': return CaseState.pignoramento;
      default: return null;
    }
  }
}

class _StateChip extends StatefulWidget {
  final String label; final int value; final Color color; final bool active; final VoidCallback onTap;
  const _StateChip({required this.label, required this.value, required this.color, required this.active, required this.onTap});
  @override
  State<_StateChip> createState() => _StateChipState();
}

class _StateChipState extends State<_StateChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final baseBg = widget.color.withOpacity(widget.active ? 0.18 : 0.07);
    final hoverBg = widget.color.withOpacity(widget.active ? 0.24 : 0.14);
    final border = widget.active ? Border.all(color: widget.color, width: 1.2) : null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _hover ? hoverBg : baseBg,
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          width: double.infinity, // expand to full cell width
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.value.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.color)),
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
