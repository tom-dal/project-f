import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../blocs/cases_summary/cases_summary_bloc.dart';
import '../models/case_state.dart';
import '../widgets/case_list.dart';
import '../widgets/create_case_dialog.dart';
import '../widgets/case_filters.dart';
import '../widgets/cases_summary_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  // USER PREFERENCE: Removed frontend filtering - all filtering now happens on backend
  String _searchQuery = '';
  // CaseState? _stateFilter; // legacy unused now removed
  List<CaseState> _statesFilter = []; // USER PREFERENCE: multi-state filter
  DateTime? _deadlineFrom; // USER PREFERENCE: deadline range from
  DateTime? _deadlineTo;   // USER PREFERENCE: deadline range to
  int _currentPage = 0;
  int _pageSize = 20; // USER PREFERENCE: Made page size configurable
  static const List<int> _pageSizeOptions = [10, 20, 50, 100]; // USER PREFERENCE: Available page size options

  // USER PREFERENCE: Sorting fixed to nextDeadlineDate ASC
  static const String _fixedSortField = 'nextDeadlineDate';

  bool _isRefreshing = false; // USER PREFERENCE: partial refresh indicator

  @override
  void initState() {
    super.initState();
    _loadCases();
    // Forza il caricamento del riepilogo dopo il primo frame se per qualche motivo non è partito.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CasesSummaryBloc>().add(LoadCasesSummary());
    });
  }

  // USER PREFERENCE: Load cases with current filters and sorting
  void _loadCases({bool fullLoading = true}) {
    const String sortParam = 'nextDeadlineDate,asc'; // fixed sort
    if (!fullLoading) {
      setState(() => _isRefreshing = true);
    }
    print('[DEBUG] Load cases -> search="$_searchQuery" states=$_statesFilter deadlineFrom=$_deadlineFrom deadlineTo=$_deadlineTo sort=$sortParam page=$_currentPage size=$_pageSize fullLoading=$fullLoading');
    context.read<DebtCaseBloc>().add(LoadCasesPaginated(
      page: _currentPage,
      size: _pageSize,
      debtorName: _searchQuery.isEmpty ? null : _searchQuery,
      states: _statesFilter.isEmpty ? null : _statesFilter,
      nextDeadlineFrom: _deadlineFrom,
      nextDeadlineTo: _deadlineTo,
      sort: sortParam,
      showFullLoading: fullLoading,
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
    _currentPage = 0;
    _loadCases(fullLoading: false);
  }

  void _onStatesFilter(List<CaseState> states) {
    _statesFilter = states;
    _currentPage = 0;
    _loadCases(fullLoading: false);
  }

  void _onDeadlineRange(DateTime? from, DateTime? to) {
    _deadlineFrom = from;
    _deadlineTo = to;
    if (_deadlineFrom != null && _deadlineTo != null && _deadlineFrom!.isAfter(_deadlineTo!)) {
      return;
    }
    _currentPage = 0;
    _loadCases(fullLoading: false);
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
      body: MultiBlocListener(
        listeners: [
          BlocListener<DebtCaseBloc, DebtCaseState>(
            listenWhen: (prev, curr) => curr is DebtCasePaginatedLoaded || curr is DebtCaseError,
            listener: (context, state) {
              if (_isRefreshing) {
                setState(() => _isRefreshing = false);
              }
              if (state is DebtCasePaginatedLoaded) {
                context.read<CasesSummaryBloc>().add(RefreshCasesSummary());
              }
            },
          ),
        ],
        child: Column(
          children: [
            // Summary section independent from filters
            Padding(
              padding: const EdgeInsets.fromLTRB(24,24,24,8),
              child: CasesSummarySection(
                onRetry: () => context.read<CasesSummaryBloc>().add(LoadCasesSummary()),
                showKpis: true,
                showStateCards: true,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  BlocBuilder<DebtCaseBloc, DebtCaseState>(
                    builder: (context, state) {
                      if (state is DebtCaseLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is DebtCaseError) {
                        return Center(child: Text(state.message));
                      }
                      if (state is DebtCasePaginatedLoaded) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24,8,24,24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CaseFilters(
                                onStatesFilter: _onStatesFilter,
                                onSearchFilter: _onSearchFilter,
                                onDeadlineRange: _onDeadlineRange,
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
                  if (_isRefreshing)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: const Color(0xFF2C3E8C),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
