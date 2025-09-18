import 'dart:async';
import 'package:flutter/material.dart';
import '../models/case_state.dart';
import '../utils/date_formats.dart';
import '../utils/italian_date_picker.dart';

class CaseFilters extends StatefulWidget {
  final Function(List<CaseState>) onStatesFilter;
  final Function(String) onSearchFilter;
  final Function(DateTime?, DateTime?) onDeadlineRange;
  final List<CaseState>? selectedStates;
  final DateTime? externalDeadlineFrom;
  final DateTime? externalDeadlineTo;
  final String? sortField; // USER PREFERENCE: campo ordinamento
  final String sortDirection; // USER PREFERENCE: asc | desc
  final void Function(String? field, String? direction) onSortChange; // USER PREFERENCE
  final bool compact; // CUSTOM IMPLEMENTATION
  const CaseFilters({super.key, required this.onStatesFilter, required this.onSearchFilter, required this.onDeadlineRange, this.selectedStates, this.externalDeadlineFrom, this.externalDeadlineTo, required this.sortField, required this.sortDirection, required this.onSortChange, this.compact = false});
  @override
  State<CaseFilters> createState() => _CaseFiltersState();
}

class _CaseFiltersState extends State<CaseFilters> {
  final _searchController = TextEditingController();
  final _dateFormat = AppDateFormats.date; // centralizzato
  List<CaseState> _selectedStates = [];
  DateTime? _deadlineFrom;
  DateTime? _deadlineTo;
  Timer? _debounce;
  final LayerLink _statesLink = LayerLink();
  OverlayEntry? _statesOverlay;
  List<CaseState>? _statesDraft;

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
        if (mounted) setState(() { _deadlineFrom = widget.externalDeadlineFrom; _deadlineTo = widget.externalDeadlineTo; });
      }
    }
    if (widget.selectedStates != oldWidget.selectedStates) {
      final newStates = widget.selectedStates != null ? List<CaseState>.from(widget.selectedStates!) : <CaseState>[];
      bool differs = newStates.length != _selectedStates.length;
      if (!differs) {
        for (int i = 0; i < newStates.length; i++) { if (newStates[i] != _selectedStates[i]) { differs = true; break; } }
      }
      if (differs && mounted) setState(() { _selectedStates = newStates; });
    }
  }

  @override
  void dispose() {
    _removeStatesOverlay();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact(context) : _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
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
                Expanded(child: _searchField(borderRadius)),
                const SizedBox(width: 12),
                _pillDate(label: 'Scadenza dopo il', value: _deadlineFrom, onTap: _pickFromDate, radius: borderRadius),
                const SizedBox(width: 12),
                _pillDate(label: 'Scadenza entro il', value: _deadlineTo, onTap: _pickToDate, radius: borderRadius),
                const SizedBox(width: 12),
                _statesLabeled(radius: BorderRadius.circular(20)),
                const SizedBox(width: 12),
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
                    label: const Text('Reimposta'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_deadlineFrom != null && _deadlineTo != null && _deadlineFrom!.isAfter(_deadlineTo!))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('La data iniziale è successiva alla finale', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    final baseHeight = 60.0;
    final fieldHeight = 44.0;
    Widget wrap(Widget c) => SizedBox(height: fieldHeight, child: c);
    final fromDate = InkWell(onTap: _pickFromDate, borderRadius: borderRadius, child: _compactDatePill('Da', _deadlineFrom, borderRadius));
    final toDate = InkWell(onTap: _pickToDate, borderRadius: borderRadius, child: _compactDatePill('A', _deadlineTo, borderRadius));
    final reset = TextButton.icon(
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: borderRadius), foregroundColor: const Color(0xFF2C3E8C)),
      onPressed: _clearFilters,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Reimposta', style: TextStyle(fontSize: 12)),
    );
    return SizedBox(
      height: baseHeight,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          Expanded(flex: 2, child: wrap(_searchField(borderRadius, compact: true))),
          const SizedBox(width: 8),
          Expanded(child: wrap(fromDate)),
          const SizedBox(width: 8),
          Expanded(child: wrap(toDate)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: wrap(_statesLabeled(radius: BorderRadius.circular(16), compact: true))),
            const SizedBox(width: 8),
          Expanded(flex: 2, child: wrap(_buildSortChips(compact: true, height: fieldHeight))),
          const SizedBox(width: 8),
          wrap(reset),
        ]),
      ),
    );
  }

  Widget _searchField(BorderRadius borderRadius, {bool compact = false}) {
    return TextField(
      controller: _searchController,
      decoration: _pillDecoration(compact ? 'Cerca' : 'Cerca debitore', borderRadius).copyWith(
        prefixIcon: Icon(Icons.search, size: compact ? 18 : 20),
        contentPadding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 8 : 14),
        suffixIcon: _searchController.text.isNotEmpty ? IconButton(
          tooltip: 'Pulisci',
          icon: const Icon(Icons.close),
          onPressed: () { _searchController.clear(); widget.onSearchFilter(''); if (mounted) setState(() {}); },
        ) : null,
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () => widget.onSearchFilter(v));
        if (mounted) setState(() {});
      },
    );
  }

  InputDecorator _compactDatePill(String label, DateTime? value, BorderRadius radius) => InputDecorator(
    decoration: _pillDecoration(label, radius).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    child: Row(children: [
      const Icon(Icons.date_range, size: 16), const SizedBox(width: 4),
      Expanded(child: Text(value == null ? '—' : _dateFormat.format(value), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _buildSortChips({bool compact = false, double? height}) {
    final field = widget.sortField; final dir = widget.sortDirection; final base = const Color(0xFF2C3E8C);
    Widget chip({required String label, required String candidate, required IconData icon}) {
      final active = field == candidate; final arrow = active ? (dir == 'asc' ? '↑' : '↓') : '';
      final inner = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: compact ? 16 : 18, color: base), const SizedBox(width: 4),
        Flexible(child: Text(label, style: TextStyle(fontSize: compact ? 12 : 13, fontWeight: FontWeight.w600, color: base), overflow: TextOverflow.ellipsis)),
        if (arrow.isNotEmpty) ...[const SizedBox(width: 4), Text(arrow, style: TextStyle(fontSize: compact ? 12 : 13, fontWeight: FontWeight.w600, color: base))]
      ]);
      final content = AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 0 : 14),
        height: compact && height != null ? height : null,
        decoration: BoxDecoration(
          color: active ? base.withAlpha((0.18 * 255).round()) : base.withAlpha((0.07 * 255).round()),
            borderRadius: BorderRadius.circular(18),
          border: active ? Border.all(color: base, width: 1) : null,
        ),
        alignment: Alignment.center,
        child: inner,
      );
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (!active) widget.onSortChange(candidate, 'asc');
          else if (dir == 'asc') widget.onSortChange(candidate, 'desc');
          else widget.onSortChange(null, null);
        },
        child: content,
      );
    }
    if (compact) {
      return Row(children: [
        Expanded(child: chip(label: 'Scadenza', candidate: 'nextDeadlineDate', icon: Icons.event)),
        const SizedBox(width: 6),
        Expanded(child: chip(label: 'Ultima attività', candidate: 'lastModifiedDate', icon: Icons.history)),
      ]);
    }
    return Wrap(spacing: 10, runSpacing: 8, children: [
      chip(label: 'Scadenza', candidate: 'nextDeadlineDate', icon: Icons.event),
      chip(label: 'Ultima attività', candidate: 'lastModifiedDate', icon: Icons.history),
    ]);
  }

  String _getStateDisplayName(CaseState state) {
    switch (state) {
      case CaseState.messaInMoraDaFare: return 'Messa in Mora da Fare';
      case CaseState.messaInMoraInviata: return 'Messa in Mora Inviata';
      case CaseState.contestazioneDaRiscontrare: return 'Contestazione da Riscontrare';
      case CaseState.depositoRicorso: return 'Deposito Ricorso';
      case CaseState.decretoIngiuntivoDaNotificare: return 'Decreto Ingiuntivo da Notificare';
      case CaseState.decretoIngiuntivoNotificato: return 'Decreto Ingiuntivo Notificato';
      case CaseState.precetto: return 'Precetto';
      case CaseState.pignoramento: return 'Pignoramento';
      case CaseState.completata: return 'Completata';
    }
  }

  Widget _pillDate({required String label, required DateTime? value, required VoidCallback onTap, required BorderRadius radius}) {
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: InputDecorator(
        decoration: _pillDecoration(label, radius).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        child: Row(children: [
          const Icon(Icons.date_range, size: 16), const SizedBox(width: 4),
          Expanded(child: Text(value == null ? '—' : _dateFormat.format(value), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _statesLabeled({required BorderRadius radius, bool compact = false}) {
    final labelStyle = TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E8C));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Stati', style: labelStyle), const SizedBox(width: 6), _statesPill(radius, compact: compact),
    ]);
  }

  Widget _statesPill(BorderRadius radius, {bool compact = false}) {
    final active = _selectedStates.isNotEmpty; final label = _statesPillLabel();
    final height = compact ? 36.0 : 40.0; final width = compact ? 150.0 : 180.0;
    return CompositedTransformTarget(
      link: _statesLink,
      child: GestureDetector(
        onTap: _toggleStatesOverlay,
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 400),
          child: SizedBox(
            height: height, width: width,
            child: Container(
              decoration: BoxDecoration(
                color: active ? const Color(0xFF2C3E8C).withAlpha((0.08 * 255).round()) : Colors.white,
                borderRadius: radius,
                border: Border.all(color: active ? const Color(0xFF2C3E8C) : const Color(0xFFE0E0E0)),
              ),
              child: Stack(children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 30),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(label.isEmpty ? ' ' : label, style: TextStyle(fontSize: compact ? 12 : 12, color: const Color(0xFF2C3E8C), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                Positioned(right: 2, top: 0, bottom: 0, child: Icon(Icons.arrow_drop_down, size: compact ? 22 : 24, color: const Color(0xFF2C3E8C))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _statesPillLabel() {
    if (_selectedStates.isEmpty) return 'Tutti';
    if (_selectedStates.length == 1) return _getStateDisplayName(_selectedStates.first);
    return '${_selectedStates.length} stati';
  }

  void _toggleStatesOverlay() { if (_statesOverlay != null) { _removeStatesOverlay(); } else { _showStatesOverlay(); } }

  void _removeStatesOverlay() {
    if (_statesDraft != null) {
      final committed = List<CaseState>.from(_statesDraft!);
      setState(() => _selectedStates = committed);
      widget.onStatesFilter(List.unmodifiable(_selectedStates));
      _statesDraft = null;
    }
    _statesOverlay?.remove();
    _statesOverlay = null;
  }

  void _showStatesOverlay() {
    final overlay = Overlay.of(context);
    _statesDraft = List<CaseState>.from(_selectedStates);
    _statesOverlay = OverlayEntry(builder: (ctx) {
      return Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _removeStatesOverlay)),
        Positioned(
          width: 300,
          child: CompositedTransformFollower(
            link: _statesLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 44),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: StatefulBuilder(builder: (ctx, setInner) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        alignment: Alignment.centerLeft,
                        child: Text('Stati (${_statesDraft!.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C3E8C))),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Scrollbar(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (final s in CaseState.values)
                                CheckboxListTile(
                                  dense: true,
                                  value: _statesDraft!.contains(s),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(_getStateDisplayName(s), style: const TextStyle(fontSize: 13)),
                                  onChanged: (_) {
                                    _toggleStateDraftSelection(s); setInner(() {});
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(children: [
                          TextButton(onPressed: _statesDraft!.isEmpty ? null : () { _statesDraft!.clear(); setInner(() {}); }, child: const Text('Deseleziona tutto')),
                          const Spacer(),
                        ]),
                      )
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
      ]);
    });
    overlay.insert(_statesOverlay!);
  }

  void _toggleStateDraftSelection(CaseState s) { if (_statesDraft == null) return; if (_statesDraft!.contains(s)) { _statesDraft!.remove(s); } else { _statesDraft!.add(s); } }

  Future<void> _pickFromDate() async {
    final picked = await pickItalianDate(context, initialDate: _deadlineFrom ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'Data inizio scadenza');
    if (picked != null) { setState(() { _deadlineFrom = picked; }); widget.onDeadlineRange(_deadlineFrom, _deadlineTo); }
  }

  Future<void> _pickToDate() async {
    final picked = await pickItalianDate(context, initialDate: _deadlineTo ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'Data fine scadenza');
    if (picked != null) { setState(() { _deadlineTo = picked; }); widget.onDeadlineRange(_deadlineFrom, _deadlineTo); }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStates.clear();
      _deadlineFrom = null;
      _deadlineTo = null;
      _statesDraft = null;
    });
    widget.onSearchFilter('');
    widget.onStatesFilter([]);
    widget.onDeadlineRange(null, null);
  }

  Widget _pillContainer({required Widget child, double? width}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }

  InputDecoration _pillDecoration(String label, BorderRadius radius) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF2C3E8C)),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
