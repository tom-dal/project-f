import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../models/case_state.dart';
import '../utils/italian_date_picker.dart';
import '../utils/date_formats.dart';

class CreateCaseDialog extends StatefulWidget {
  const CreateCaseDialog({super.key});

  @override
  State<CreateCaseDialog> createState() => _CreateCaseDialogState();
}

class _CreateCaseDialogState extends State<CreateCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _debtorNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateFormat = AppDateFormats.date; // centralizzato
  DateTime? _lastStateDate = DateTime.now();

  CaseState _initialState = CaseState.messaInMoraDaFare;
  bool _submitting = false; // CUSTOM IMPLEMENTATION: prevent double submit
  final _debtorFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus after build to ensure dialog animation done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _debtorFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debtorFocus.dispose();
    _debtorNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_submitting) return;
    if (_formKey.currentState!.validate()) {
      // Parsing the amount, replacing comma with dot for proper decimal conversion
      final amountText = _amountController.text.replaceAll(',', '.').trim();
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserire un importo valido (> 0)')),
        );
        return;
      }
      // NON serve setState(_submitting=true) se chiudi subito la modale
      context.read<DebtCaseBloc>().add(
        CreateDebtCase(
          debtorName: _debtorNameController.text.trim(),
          initialState: _initialState,
          lastStateDate: _lastStateDate, // può essere null
          amount: amount,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initial = _lastStateDate ?? DateTime.now();
    final DateTime? picked = await pickItalianDate(
      context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data stato',
    );
    if (picked != null && mounted) {
      setState(() { _lastStateDate = picked; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 640; // breakpoint
                final verticalGap = const SizedBox(height: 20);

                Widget debtorField = TextFormField(
                  focusNode: _debtorFocus,
                  controller: _debtorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Debitore',
                    helperText: 'Nome o ragione sociale',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Il nome è obbligatorio';
                    if (value.trim().length < 2) return 'Minimo 2 caratteri';
                    return null;
                  },
                );

                Widget amountField = TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(
                    labelText: 'Importo Dovuto',
                    prefixText: '€ ',
                    helperText: 'Es. 1234.56',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Importo obbligatorio';
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null) return 'Formato non valido';
                    if (parsed <= 0) return 'Deve essere > 0';
                    return null;
                  },
                );

                Widget stateField = DropdownButtonFormField<CaseState>(
                  value: _initialState,
                  decoration: const InputDecoration(
                    labelText: 'Stato Iniziale',
                    helperText: 'Seleziona lo stato corrente',
                    border: OutlineInputBorder(),
                  ),
                  items: CaseState.values
                      .where((s) => s != CaseState.completata)
                      .map((state) => DropdownMenuItem(
                            value: state,
                            child: Text(_getStateDisplayName(state)),
                          ))
                      .toList(),
                  onChanged: (value) { if (value != null) setState(() { _initialState = value; }); },
                );

                Widget dateField = InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data Stato',
                    border: const OutlineInputBorder(),
                    suffixIcon: _lastStateDate != null ? IconButton(
                      tooltip: 'Rimuovi',
                      icon: const Icon(Icons.clear),
                      onPressed: () { setState(() { _lastStateDate = null; }); },
                    ) : IconButton(
                      tooltip: 'Seleziona data',
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(context),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_lastStateDate != null ? _dateFormat.format(_lastStateDate!) : '— Oggi —'),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                );

                Widget formGrid;
                if (wide) {
                  formGrid = Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: debtorField),
                          const SizedBox(width: 24),
                          Expanded(child: amountField),
                        ],
                      ),
                      verticalGap,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: stateField),
                          const SizedBox(width: 24),
                          Expanded(child: dateField),
                        ],
                      ),
                    ],
                  );
                } else {
                  formGrid = Column(
                    children: [
                      debtorField,
                      verticalGap,
                      amountField,
                      verticalGap,
                      stateField,
                      verticalGap,
                      dateField,
                    ],
                  );
                }

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.assignment_add, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Nuova Pratica',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      formGrid,
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _onSubmit,
                            icon: _submitting ? const SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.check_circle_outline),
                            label: Text(_submitting ? 'Creazione...' : 'Crea Pratica'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
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
}