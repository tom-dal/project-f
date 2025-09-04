import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../blocs/debt_case/debt_case_bloc.dart';

class CaseDetailsDialog extends StatefulWidget {
  final DebtCase debtCase;

  const CaseDetailsDialog({
    super.key,
    required this.debtCase,
  });

  @override
  State<CaseDetailsDialog> createState() => _CaseDetailsDialogState();
}

class _CaseDetailsDialogState extends State<CaseDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  late CaseState _selectedState;
  late CaseState _originalState;
  late String _originalNotes;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  bool _isEditMode = false; // Aggiunta modalità di modifica

  @override
  void initState() {
    super.initState();
    _selectedState = widget.debtCase.state;
    _originalState = widget.debtCase.state;
    _originalNotes = widget.debtCase.notes ?? '';
    _notesController.text = _originalNotes;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _selectedState != _originalState ||
           _notesController.text.trim() != _originalNotes.trim();
  }

  void safeSetState(VoidCallback fn){ if(!mounted) return; setState(fn); }

  void _enterEditMode() {
    safeSetState(() { _isEditMode = true; });
  }

  void _exitEditMode() {
    safeSetState(() {
      _isEditMode = false;
      // Ripristina i valori originali
      _selectedState = _originalState;
      _notesController.text = _originalNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _isEditMode ? Icons.edit : Icons.folder_open,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditMode ? 'Modifica Pratica' : 'Dettagli Pratica',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Debitore: ${widget.debtCase.debtorName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Case Info Cards
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Basic Info Card
                    _buildInfoCard(
                      'Informazioni Base',
                      [
                        _buildInfoRow('ID Pratica', widget.debtCase.id.toString()),
                        _buildInfoRow('Debitore', widget.debtCase.debtorName),
                        _buildInfoRow('Importo', '€ ${widget.debtCase.owedAmount.toStringAsFixed(2)}'),
                        _buildInfoRow('Data Creazione',
                            widget.debtCase.createdDate != null 
                                ? _dateFormat.format(widget.debtCase.createdDate!)
                                : 'N/A'),
                        _buildInfoRow('Ultimo Aggiornamento', 
                            widget.debtCase.updatedDate != null 
                                ? _dateFormat.format(widget.debtCase.updatedDate!)
                                : 'N/A'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Current State Card
                    _buildStateCard(),
                    const SizedBox(height: 16),

                    // Notes Card
                    _buildNotesCard(),
                  ],
                ),
              ),
            ),

            // Action Buttons
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stato Pratica',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_isEditMode) ...[
              DropdownButtonFormField<CaseState>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'Stato',
                  border: OutlineInputBorder(),
                ),
                items: CaseState.values.map((state) {
                  return DropdownMenuItem(
                    value: state,
                    child: Text(_getStateDisplayName(state)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    safeSetState(() { _selectedState = value; });
                  }
                },
              ),
            ] else ...[
              _buildInfoRow('Stato Attuale', _getStateDisplayName(_selectedState)),
              _buildInfoRow('Data Ultimo Stato',
                  _dateFormat.format(widget.debtCase.lastStateDate)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_isEditMode) ...[
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                    hintText: 'Inserisci note aggiuntive...',
                  ),
                  maxLines: 4,
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[50],
                ),
                child: Text(
                  widget.debtCase.notes?.isNotEmpty == true
                      ? widget.debtCase.notes!
                      : 'Nessuna nota disponibile',
                  style: TextStyle(
                    color: widget.debtCase.notes?.isNotEmpty == true
                        ? Colors.black87
                        : Colors.grey[600],
                    fontStyle: widget.debtCase.notes?.isNotEmpty == true
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isEditMode) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _exitEditMode,
            child: const Text('Annulla'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _hasChanges ? _saveChanges : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasChanges ? const Color(0xFF2C3E8C) : null,
              foregroundColor: _hasChanges ? Colors.white : null,
            ),
            child: const Text('Salva Modifiche'),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _enterEditMode,
            child: const Text('Modifica'),
          ),
        ],
      );
    }
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
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

  void _saveChanges() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<DebtCaseBloc>().add(
        UpdateDebtCase(
          id: widget.debtCase.id,
          state: _selectedState,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        ),
      );
      if(mounted) Navigator.of(context).pop();
      // SnackBar after pop can fail if context is gone: show only if still mounted (parent might keep it)
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pratica aggiornata con successo')),
        );
      }
    }
  }
}
