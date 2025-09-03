import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_state.dart';

class CaseFilters extends StatefulWidget {
  final Function(List<CaseState>) onStatesFilter;
  final Function(String) onSearchFilter;
  final Function(DateTime?, DateTime?) onDeadlineRange;
  final List<CaseState>? selectedStates; // external controlled states
  final DateTime? externalDeadlineFrom;
  final DateTime? externalDeadlineTo;
  final String? sortField; // USER PREFERENCE: current sort field (nextDeadlineDate | lastModifiedDate)
  final String sortDirection; // USER PREFERENCE: asc | desc
  final void Function(String? field, String? direction) onSortChange; // USER PREFERENCE: callback ordinamento

  const CaseFilters({
    super.key,
    required this.onStatesFilter,
    required this.onSearchFilter,
    required this.onDeadlineRange,
    this.selectedStates,
    this.externalDeadlineFrom,
    this.externalDeadlineTo,
    required this.sortField,
    required this.sortDirection,
    required this.onSortChange,
  });

  @override
  State<CaseFilters> createState() => _CaseFiltersState();
}

class _CaseFiltersState extends State<CaseFilters> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  List<CaseState> _selectedStates = [];
  DateTime? _deadlineFrom;
  DateTime? _deadlineTo;
  Timer? _debounce; // USER PREFERENCE: debounce search
  final LayerLink _statesLink = LayerLink();
  OverlayEntry? _statesOverlay;
  final ScrollController _statesScrollController = ScrollController();
  List<CaseState> _draftStates = []; // temp selection before apply

  @override
  void initState() {
    super.initState();
    // USER PREFERENCE: initialize internal state from external props to keep quick filters in sync
    _selectedStates = widget.selectedStates != null ? List.from(widget.selectedStates!) : [];
    _deadlineFrom = widget.externalDeadlineFrom;
    _deadlineTo = widget.externalDeadlineTo;
  }

  @override
  void didUpdateWidget(covariant CaseFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    // USER PREFERENCE: sync deadlines if parent (quick filters) changed them
    final fromChanged = widget.externalDeadlineFrom != oldWidget.externalDeadlineFrom;
    final toChanged = widget.externalDeadlineTo != oldWidget.externalDeadlineTo;
    if (fromChanged || toChanged) {
      if (_deadlineFrom != widget.externalDeadlineFrom || _deadlineTo != widget.externalDeadlineTo) {
        setState(() {
          _deadlineFrom = widget.externalDeadlineFrom;
            // keep end-of-day if provided externally, otherwise just assign
          _deadlineTo = widget.externalDeadlineTo;
        });
      }
    }
    // Also sync selected states (prevents future desync similar to deadlines)
    if (widget.selectedStates != oldWidget.selectedStates) {
      final newStates = widget.selectedStates != null ? List<CaseState>.from(widget.selectedStates!) : <CaseState>[];
      bool differs = newStates.length != _selectedStates.length;
      if (!differs) {
        for (int i = 0; i < newStates.length; i++) {
          if (newStates[i] != _selectedStates[i]) { differs = true; break; }
        }
      }
      if (differs) {
        setState(() { _selectedStates = newStates; });
      }
    }
  }

  @override
  void dispose() {
    _removeStatesOverlay();
    _statesScrollController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search (expanded)
                Expanded(
                  child: _pillContainer(
                    width: double.infinity,
                    child: TextField(
                      controller: _searchController,
                      decoration: _pillDecoration('Cerca debitore', borderRadius).copyWith(
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Pulisci',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onSearchFilter('');
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () => widget.onSearchFilter(v));
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _pillDate(label: 'Scadenza dopo il', value: _deadlineFrom, onTap: _pickFromDate, radius: borderRadius),
                const SizedBox(width: 12),
                _pillDate(label: 'Scadenza entro il', value: _deadlineTo, onTap: _pickToDate, radius: borderRadius),
                const SizedBox(width: 12),
                _statesPill(borderRadius),
                const SizedBox(width: 12),
                // Ordinamento inline
                _buildSortChips(),
                const SizedBox(width: 12),
                _pillContainer(
                  width: 120,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: borderRadius),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      foregroundColor: const Color(0xFF2C3E8C),
                    ),
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_deadlineFrom != null && _deadlineTo != null && _deadlineFrom!.isAfter(_deadlineTo!))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'La data iniziale è successiva alla finale',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChips() {
    // Determina stato chip
    String? field = widget.sortField;
    String dir = widget.sortDirection;

    Widget _chip({required String label, required String candidateField, required IconData iconBase}) {
      bool active = field == candidateField;
      String? arrow; // ↑ o ↓
      if (active) {
        arrow = dir == 'asc' ? '↑' : '↓';
      }
      Color baseColor = const Color(0xFF2C3E8C);
      Color bg = active ? baseColor.withOpacity(0.18) : baseColor.withOpacity(0.07);
      BorderSide? side = active ? BorderSide(color: baseColor, width: 1) : null;

      void cycle() {
        // Opzione A: ciclo uniforme none -> asc -> desc -> none
        if (!active) {
          widget.onSortChange(candidateField, 'asc');
        } else if (dir == 'asc') {
          widget.onSortChange(candidateField, 'desc');
        } else if (dir == 'desc') {
          widget.onSortChange(null, null); // disattiva
        }
      }

      return InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: cycle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: 52), // allinea all'altezza delle altre pill
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // stesso padding verticale delle pill
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: side != null ? Border.fromBorderSide(side) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconBase, size: 18, color: baseColor),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: baseColor)),
              if (arrow != null) ...[
                const SizedBox(width: 6),
                Text(arrow, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: baseColor)),
              ]
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _chip(label: 'Scadenza', candidateField: 'nextDeadlineDate', iconBase: Icons.event),
        _chip(label: 'Ultima attività', candidateField: 'lastModifiedDate', iconBase: Icons.history),
      ],
    );
  }

  InputDecoration _pillDecoration(String label, BorderRadius radius) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Color(0xFF2C3E8C), width: 1.4)),
        isDense: false,
      );

  Widget _pillContainer({required double width, required Widget child}) => SizedBox(
        width: width,
        child: child,
      );

  Widget _pillDate({required String label, required DateTime? value, required VoidCallback onTap, required BorderRadius radius}) {
    return _pillContainer(
      width: 170, // aumentato per etichette più lunghe
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: InputDecorator(
          decoration: _pillDecoration(label, radius),
          child: Row(
            children: [
              Icon(Icons.date_range, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value == null ? '—' : _dateFormat.format(value),
                  style: TextStyle(fontSize: 13, color: value == null ? Colors.grey.shade500 : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineFrom ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      helpText: 'Seleziona data',
      // niente locale: usa quella di sistema
    );
    if (picked != null) {
      setState(() {
        _deadlineFrom = DateTime(picked.year, picked.month, picked.day);
        if (_deadlineTo != null && _deadlineFrom!.isAfter(_deadlineTo!)) {
          // opzionale: auto-swap
        }
      });
      widget.onDeadlineRange(_deadlineFrom, _deadlineTo);
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final base = _deadlineFrom ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineTo ?? base,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      helpText: 'Seleziona data',
      // niente locale: usa quella di sistema
    );
    if (picked != null) {
      setState(() {
        _deadlineTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999); // fine giornata
      });
      widget.onDeadlineRange(_deadlineFrom, _deadlineTo);
    }
  }

  Widget _statesPill(BorderRadius radius) {
    return CompositedTransformTarget(
      link: _statesLink,
      child: _pillContainer(
        width: 200,
        child: InkWell(
          borderRadius: radius,
          onTap: _toggleStatesOverlay,
          child: InputDecorator(
            decoration: _pillDecoration('Stati', radius),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: Color(0xFF2C3E8C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedStates.isEmpty
                        ? 'Tutti'
                        : _selectedStates.length <= 2
                            ? _selectedStates.map(_getStateShort).join(', ')
                            : '${_selectedStates.length} selezionati',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(_statesOverlay == null ? Icons.arrow_drop_down : Icons.arrow_drop_up, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleStatesOverlay() {
    if (_statesOverlay == null) {
      _showStatesOverlay();
    } else {
      _removeStatesOverlay();
    }
  }

  void _showStatesOverlay() {
    _draftStates = List.from(_selectedStates);
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(0, 0);

    _statesOverlay = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Dismiss area
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeStatesOverlay,
                child: const SizedBox(),
              ),
            ),
            CompositedTransformFollower(
              link: _statesLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 8),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 220,
                    maxWidth: 280,
                    maxHeight: size.height * 0.6 + 240, // fallback
                  ),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Scrollbar(
                            controller: _statesScrollController,
                            thumbVisibility: true,
                            child: ListView(
                              controller: _statesScrollController,
                              primary: false,
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              children: [
                                ...CaseState.values.map((s) => CheckboxListTile(
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      visualDensity: VisualDensity.compact,
                                      title: Text(_getStateDisplayName(s), style: const TextStyle(fontSize: 13)),
                                      value: _draftStates.contains(s),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _draftStates.add(s);
                                          } else {
                                            _draftStates.remove(s);
                                          }
                                          _statesOverlay?.markNeedsBuild(); // FIX: force overlay rebuild so checkbox UI updates immediately
                                        });
                                      },
                                    )),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                          child: Row(
                            children: [
                              const Spacer(),
                              TextButton(
                                onPressed: _removeStatesOverlay,
                                child: const Text('Chiudi', style: TextStyle(fontSize: 12)),
                              ),
                              FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedStates = List.unmodifiable(_draftStates);
                                  });
                                  widget.onStatesFilter(_selectedStates);
                                  _removeStatesOverlay();
                                },
                                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), minimumSize: Size.zero),
                                child: const Text('Applica', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_statesOverlay!);
    setState(() {});
  }

  void _removeStatesOverlay() {
    _statesOverlay?.remove();
    _statesOverlay = null;
    setState(() {});
  }

  void _clearFilters() {
    _debounce?.cancel();
    _removeStatesOverlay();
    setState(() {
      _selectedStates = [];
      _searchController.clear();
      _deadlineFrom = null;
      _deadlineTo = null;
    });
    widget.onStatesFilter(const []);
    widget.onSearchFilter('');
    widget.onDeadlineRange(null, null);
  }

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

  String _getStateShort(CaseState s) {
    switch (s) {
      case CaseState.messaInMoraDaFare:
        return 'Mora da fare';
      case CaseState.messaInMoraInviata:
        return 'Mora inviata';
      case CaseState.contestazioneDaRiscontrare:
        return 'Contest.';
      case CaseState.depositoRicorso:
        return 'Ricorso';
      case CaseState.decretoIngiuntivoDaNotificare:
        return 'Decr. da notif.';
      case CaseState.decretoIngiuntivoNotificato:
        return 'Decr. notif.';
      case CaseState.precetto:
        return 'Precetto';
      case CaseState.pignoramento:
        return 'Pignor.';
      case CaseState.completata:
        return 'Complet.';
    }
  }
}
