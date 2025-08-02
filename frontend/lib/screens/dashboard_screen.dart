import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../widgets/case_list.dart';
import '../widgets/create_case_dialog.dart';
import '../widgets/case_filters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  // USER PREFERENCE: Removed frontend filtering - all filtering now happens on backend
  String _searchQuery = '';
  CaseState? _stateFilter;
  int _currentPage = 0;
  int _pageSize = 20; // USER PREFERENCE: Made page size configurable
  static const List<int> _pageSizeOptions = [10, 20, 50, 100]; // USER PREFERENCE: Available page size options

  // USER PREFERENCE: Sorting state management
  String _sortField = 'nextDeadlineDate'; // Default: data di scadenza
  bool _sortAscending = true; // Default: ASC
  static const List<Map<String, String>> _sortOptions = [
    {'field': 'nextDeadlineDate', 'label': 'Data Scadenza'},
    {'field': 'lastStateDate', 'label': 'Data Ultima Attività'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  // USER PREFERENCE: Load cases with current filters and sorting
  void _loadCases() {
    String sortParam = '$_sortField,${_sortAscending ? 'asc' : 'desc'}';
    context.read<DebtCaseBloc>().add(LoadCasesPaginated(
      page: _currentPage,
      size: _pageSize,
      debtorName: _searchQuery.isEmpty ? null : _searchQuery,
      state: _stateFilter,
      sort: sortParam,
    ));
  }

  void _showCreateCaseDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<DebtCaseBloc>(),
        child: const CreateCaseDialog(),
      ),
    );
  }

  // USER PREFERENCE: Apply filters via backend call instead of frontend filtering
  void _onSearchFilter(String query) {
    _searchQuery = query;
    _currentPage = 0; // Reset to first page when filtering
    _loadCases();
  }

  void _onStateFilter(CaseState? state) {
    _stateFilter = state;
    _currentPage = 0; // Reset to first page when filtering
    _loadCases();
  }

  // USER PREFERENCE: Handle page size change
  void _onPageSizeChanged(int? newSize) {
    if (newSize != null && newSize != _pageSize) {
      setState(() {
        _pageSize = newSize;
        _currentPage = 0; // Reset to first page when changing page size
      });
      _loadCases();
    }
  }

  void _loadNextPage() {
    _currentPage++;
    _loadCases();
  }

  void _loadPreviousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _loadCases();
    }
  }

  // USER PREFERENCE: Toggle sorting direction for same field or change field
  void _onSortChanged(String field) {
    setState(() {
      if (_sortField == field) {
        // Same field: toggle direction
        _sortAscending = !_sortAscending;
      } else {
        // Different field: change field and reset to ASC
        _sortField = field;
        _sortAscending = true;
      }
      _currentPage = 0; // Reset to first page when sorting changes
    });
    _loadCases();
  }

  Widget _buildPhaseCard(String title, int count, Color color, {CaseState? filterState}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: filterState != null ? () => _onStateFilter(filterState) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySection(String title, String message) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E8C),
        title: const Text(
          'Gestione Recupero Crediti',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF2C3E8C),
            ),
            onPressed: _showCreateCaseDialog,
            child: const Text('Nuova Pratica'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
            onPressed: () {},
            child: const Text('Dashboard'),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: BlocBuilder<DebtCaseBloc, DebtCaseState>(
        builder: (context, state) {
          if (state is DebtCaseLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DebtCaseError) {
            return Center(child: Text(state.message));
          }

          if (state is DebtCasePaginatedLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // State summary cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      final cardCount = 6;
                      final minCardWidth = 140.0;
                      final spacing = 16.0;
                      
                      // Calculate how many cards fit per row
                      int cardsPerRow = ((screenWidth + spacing) / (minCardWidth + spacing)).floor();
                      cardsPerRow = cardsPerRow.clamp(1, cardCount);
                      
                      final cardWidth = (screenWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;
                      
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _buildPhaseCard(
                              'Iniziali',
                              state.cases.where((c) => c.state == CaseState.messaInMoraDaFare).length,
                              Colors.blue.shade400,
                              filterState: CaseState.messaInMoraDaFare,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildPhaseCard(
                              'Messa in Mora',
                              state.cases.where((c) => c.state == CaseState.messaInMoraInviata).length,
                              Colors.orange.shade400,
                              filterState: CaseState.messaInMoraInviata,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildPhaseCard(
                              'Deposito Ricorso',
                              state.cases.where((c) => c.state == CaseState.depositoRicorso).length,
                              Colors.red.shade400,
                              filterState: CaseState.depositoRicorso,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildPhaseCard(
                              'Decreto Ingiuntivo',
                              state.cases.where((c) => c.state == CaseState.decretoIngiuntivoDaNotificare).length,
                              Colors.purple.shade400,
                              filterState: CaseState.decretoIngiuntivoDaNotificare,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildPhaseCard(
                              'Precetto',
                              state.cases.where((c) => c.state == CaseState.precetto).length,
                              Colors.green.shade400,
                              filterState: CaseState.precetto,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildPhaseCard(
                              'Completati',
                              state.cases.where((c) => c.state == CaseState.completata).length,
                              Colors.grey.shade400,
                              filterState: CaseState.completata,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Filters
                  CaseFilters(
                    onStateFilter: _onStateFilter,
                    onSearchFilter: _onSearchFilter,
                  ),
                  const SizedBox(height: 16),

                  // USER PREFERENCE: Sorting controls with visual indicators
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Text(
                            'Ordina per:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ..._sortOptions.map((option) {
                            final isSelected = _sortField == option['field'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: InkWell(
                                onTap: () => _onSortChanged(option['field']!),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF2C3E8C).withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF2C3E8C)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        option['label']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? const Color(0xFF2C3E8C)
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          _sortAscending
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          size: 20,
                                          color: const Color(0xFF2C3E8C),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          const Spacer(),
                          Text(
                            'Ordine: ${_sortAscending ? 'Crescente' : 'Decrescente'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cases table
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pratiche (${state.totalElements})',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Pagina ${state.currentPage + 1} di ${state.totalPages} - ${state.totalElements} totali',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          CaseList(cases: state.cases, dateFormat: _dateFormat),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: state.hasPrevious ? _loadPreviousPage : null,
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('Precedente'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: state.hasNext ? _loadNextPage : null,
                                icon: const Icon(Icons.chevron_right),
                                label: const Text('Successiva'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // USER PREFERENCE: Page size selector
                          Row(
                            children: [
                              const Text('Elementi per pagina:'),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _pageSize,
                                onChanged: _onPageSizeChanged,
                                items: _pageSizeOptions.map((size) {
                                  return DropdownMenuItem<int>(
                                    value: size,
                                    child: Text(size.toString()),
                                  );
                                }).toList(),
                                underline: Container(
                                  height: 1,
                                  color: Colors.grey.shade400,
                                ),
                                isExpanded: false,
                                iconSize: 24,
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Totale: ${state.totalElements}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
