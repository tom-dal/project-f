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

  const CaseFilters({
    super.key,
    required this.onStatesFilter,
    required this.onSearchFilter,
    required this.onDeadlineRange,
    this.selectedStates,
    this.externalDeadlineFrom,
    this.externalDeadlineTo,
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

  @override
  void didUpdateWidget(covariant CaseFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool changed = false;
    if (widget.selectedStates != null) {
      final newSet = widget.selectedStates!;
      if (newSet.length != _selectedStates.length || !_selectedStates.every(newSet.contains)) {
        _selectedStates = List.from(newSet);
        changed = true;
      }
    }
    if (widget.externalDeadlineFrom != null || _deadlineFrom != null) {
      if (widget.externalDeadlineFrom?.millisecondsSinceEpoch != _deadlineFrom?.millisecondsSinceEpoch) {
        _deadlineFrom = widget.externalDeadlineFrom;
        changed = true;
      }
    }
    if (widget.externalDeadlineTo != null || _deadlineTo != null) {
      if (widget.externalDeadlineTo?.millisecondsSinceEpoch != _deadlineTo?.millisecondsSinceEpoch) {
        _deadlineTo = widget.externalDeadlineTo;
        changed = true;
      }
    }
    if (changed) setState(() {});
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
