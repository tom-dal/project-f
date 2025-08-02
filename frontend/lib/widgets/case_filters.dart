import 'package:flutter/material.dart';
import '../models/case_state.dart';

class CaseFilters extends StatefulWidget {
  final Function(CaseState?) onStateFilter;
  final Function(String) onSearchFilter;

  const CaseFilters({
    super.key,
    required this.onStateFilter,
    required this.onSearchFilter,
  });

  @override
  State<CaseFilters> createState() => _CaseFiltersState();
}

class _CaseFiltersState extends State<CaseFilters> {
  final _searchController = TextEditingController();
  CaseState? _selectedState;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtri',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Search bar
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Cerca debitore',
                hintText: 'Inserisci nome debitore...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: widget.onSearchFilter,
            ),
            const SizedBox(height: 16),
            
            // Filter row
            Row(
              children: [
                // State filter
                Expanded(
                  child: DropdownButtonFormField<CaseState?>(
                    value: _selectedState,
                    decoration: const InputDecoration(
                      labelText: 'Stato',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<CaseState?>(
                        value: null,
                        child: Text('Tutti gli stati'),
                      ),
                      ...CaseState.values.map((state) {
                        return DropdownMenuItem<CaseState?>(
                          value: state,
                          child: Text(_getStateDisplayName(state)),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedState = value;
                      });
                      widget.onStateFilter(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Clear filters button
                ElevatedButton(
                  onPressed: _clearFilters,
                  child: const Text('Cancella Filtri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedState = null;
      _searchController.clear();
    });
    widget.onStateFilter(null);
    widget.onSearchFilter('');
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
}
