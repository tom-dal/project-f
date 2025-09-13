import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../blocs/cases_summary/cases_summary_bloc.dart';
import '../models/case_state.dart';
import '../models/debt_case.dart';
import '../widgets/create_case_dialog.dart';
import '../widgets/case_filters.dart';
import '../widgets/cases_summary_section.dart';
import '../widgets/cases_table.dart';
import 'case_detail_read_only_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  String _searchQuery = '';// USER PREFERENCE: backend filtering
  List<CaseState> _statesFilter = [];// USER PREFERENCE
  DateTime? _deadlineFrom;
  DateTime? _deadlineTo;
  int _currentPage = 0;
  int _pageSize = 20;
  static const List<int> _pageSizeOptions = [10,20,50,100];
  String? _sortField = 'nextDeadlineDate';
  String _sortDirection = 'asc';
  bool _isRefreshing = false;

  // Sticky layout constants
  static const double _kFiltersHeight = 60;
  static const double _kPageBarHeight = 48;
  static const double _kHeaderHeight = CasesTableLayout.rowHeight; // 44
  double get _stickyTotalHeight => _kFiltersHeight + _kPageBarHeight + _kHeaderHeight;

  @override
  void initState() { super.initState(); _loadCases(); WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; context.read<CasesSummaryBloc>().add(LoadCasesSummary()); }); }

  void _loadCases({bool fullLoading = true}) {
    final String? sortParam = _sortField != null ? '$_sortField,$_sortDirection' : null;
    if(!fullLoading){ setState(()=>_isRefreshing=true);}
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

  void _openCaseDetail(DebtCase debtCase){
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<DebtCaseBloc>(), child: CaseDetailReadOnlyScreen(caseId: debtCase.id, initialCase: debtCase))));
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

  void _onSortChange(String? field, String? direction) {
    _sortField = field;
    if (field == null) {
      // reset direction default
      _sortDirection = 'asc';
    } else if (direction != null) {
      _sortDirection = direction;
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

  void _applyQuickFilter({required List<CaseState> states, DateTime? from, DateTime? to}) {
    _statesFilter = states;
    _deadlineFrom = from;
    _deadlineTo = to;
    _currentPage = 0;
    _loadCases(fullLoading: false);
  }

  String _currentSortLabel() {
    // Descrizioni naturali della direzione
    if (_sortField == null) {
      return 'Ordinamento: Scadenza (più imminenti prima)';
    }
    if (_sortField == 'nextDeadlineDate') {
      if (_sortDirection == 'asc') {
        return 'Ordinamento: Scadenza (più imminenti prima)';
      } else {
        return 'Ordinamento: Scadenza (più lontane prima)';
      }
    } else if (_sortField == 'lastModifiedDate') {
      if (_sortDirection == 'asc') {
        return 'Ordinamento: Ultima attività (dalla meno recente alla più recente)';
      } else {
        return 'Ordinamento: Ultima attività (dalla più recente alla meno recente)';
      }
    }
    return 'Ordinamento: —';
  }
  String _buildPageLabel(DebtCasePaginatedLoaded s)=>'Pagina ${s.currentPage + 1} di ${s.totalPages} - ${s.totalElements} pratiche.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E8C),
        title: const Text('Gestione Recupero Crediti', style: TextStyle(color: Colors.white)),
        actions: [
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF2C3E8C)), onPressed: _showCreateCaseDialog, child: const Text('Nuova Pratica')),
          const SizedBox(width:12),
          OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)), onPressed: () {}, child: const Text('Dashboard')),
          const SizedBox(width:24),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<DebtCaseBloc, DebtCaseState>(
            listenWhen: (p,c)=> c is DebtCasePaginatedLoaded || c is DebtCaseError,
            listener: (context,state){ if(_isRefreshing) setState(()=>_isRefreshing=false); if(state is DebtCasePaginatedLoaded){ context.read<CasesSummaryBloc>().add(RefreshCasesSummary()); } },
          ),
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24,24,24,8),
              child: CasesSummarySection(
                onRetry: () => context.read<CasesSummaryBloc>().add(LoadCasesSummary()),
                showKpis: true,
                showStateCards: true,
                activeStates: _statesFilter,
                deadlineFrom: _deadlineFrom,
                deadlineTo: _deadlineTo,
                onSetStates: (s)=>_onStatesFilter(s),
                onSetDeadlineRange: (f,t)=>_onDeadlineRange(f,t),
                onApplyQuickFilter: (s,f,t)=>_applyQuickFilter(states:s, from:f, to:t),
                onClearAllFilters: (){ _onStatesFilter([]); _onDeadlineRange(null,null); },
              ),
            ),
            Expanded(
              child: BlocBuilder<DebtCaseBloc, DebtCaseState>(
                builder: (context, state){
                  if(state is DebtCaseLoading){ return const Center(child:CircularProgressIndicator()); }
                  if(state is DebtCaseError){ return Center(child: Text(state.message)); }
                  if(state is! DebtCasePaginatedLoaded){ return const SizedBox.shrink(); }
                  return Stack(
                    children: [
                      // Scrollable content
                      Positioned.fill(
                        top: _stickyTotalHeight,
                        child: _buildCasesList(state),
                      ),
                      // Filters bar
                      Positioned(
                        top:0,left:0,right:0,
                        child: _buildFiltersBar(),
                      ),
                      // Pagination / sort bar
                      Positioned(
                        top:_kFiltersHeight, left:0,right:0,
                        child: _buildPageBar(state),
                      ),
                      // Table header bar
                      Positioned(
                        top:_kFiltersHeight + _kPageBarHeight, left:0,right:0,
                        child: _buildTableHeader(),
                      ),
                      if(_isRefreshing)
                        const Positioned(top:0,left:0,right:0,child: LinearProgressIndicator(minHeight:3,color: Color(0xFF2C3E8C), backgroundColor: Colors.transparent)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersBar(){
    return Material(
      elevation: 2,
      child: Container(
        height: _kFiltersHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
        child: CaseFilters(
          compact: true,
          onStatesFilter: _onStatesFilter,
          onSearchFilter: _onSearchFilter,
          onDeadlineRange: _onDeadlineRange,
          selectedStates: _statesFilter,
          externalDeadlineFrom: _deadlineFrom,
          externalDeadlineTo: _deadlineTo,
          sortField: _sortField,
          sortDirection: _sortDirection,
          onSortChange: _onSortChange,
        ),
      ),
    );
  }

  Widget _buildPageBar(DebtCasePaginatedLoaded state){
    return Material(
      elevation: 1,
      child: Container(
        height: _kPageBarHeight,
        padding: const EdgeInsets.symmetric(horizontal:24),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)) )),
        child: Row(
          children: [
            Expanded(child: Text(_buildPageLabel(state), style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            const SizedBox(width:16),
            Text(_currentSortLabel(), style: TextStyle(fontSize: 12.5, color: Colors.grey[600], fontStyle: FontStyle.italic)),
            const SizedBox(width:24),
            _PaginationControls(
              hasPrev: state.hasPrevious,
              hasNext: state.hasNext,
              onPrev: _loadPreviousPage,
              onNext: _loadNextPage,
              pageSize: _pageSize,
              pageSizeOptions: _pageSizeOptions,
              onPageSizeChanged: _onPageSizeChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(){
    return Material(
      elevation: 1,
      child: Container(
        height: _kHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal:24),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)) )),
        child: const CasesTableHeader(),
      ),
    );
  }

  Widget _buildCasesList(DebtCasePaginatedLoaded state){
    if(state.cases.isEmpty){
      return const Center(child: Text('Nessuna pratica trovata'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: state.cases.length,
      itemBuilder: (ctx,i){
        final c = state.cases[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal:24),
          child: CasesTableDataRow(
            debtCase: c,
            dateFormat: _dateFormat,
            onTap: ()=>_openCaseDetail(c),
          ),
        );
      },
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final bool hasPrev; final bool hasNext; final VoidCallback? onPrev; final VoidCallback? onNext; final int pageSize; final List<int> pageSizeOptions; final ValueChanged<int?> onPageSizeChanged;
  const _PaginationControls({required this.hasPrev, required this.hasNext, this.onPrev, this.onNext, required this.pageSize, required this.pageSizeOptions, required this.onPageSizeChanged});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ElevatedButton.icon(onPressed: hasPrev?onPrev:null, icon: const Icon(Icons.chevron_left), label: const Text('Precedente')),
      const SizedBox(width:16),
      ElevatedButton.icon(onPressed: hasNext?onNext:null, icon: const Icon(Icons.chevron_right), label: const Text('Successiva')),
      const SizedBox(width:32),
      DropdownButton<int>(value: pageSize, items: pageSizeOptions.map((s)=>DropdownMenuItem<int>(value:s, child: Text('$s/pg'))).toList(), onChanged: onPageSizeChanged),
    ]);
  }
}
