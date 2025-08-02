import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../models/case_state.dart';

class CreateCaseDialog extends StatefulWidget {
  const CreateCaseDialog({super.key});

  @override
  State<CreateCaseDialog> createState() => _CreateCaseDialogState();
}

class _CreateCaseDialogState extends State<CreateCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _debtorNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime _lastStateDate = DateTime.now();
  CaseState _initialState = CaseState.messaInMoraDaFare;

  @override
  void dispose() {
    _debtorNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      // Parsing the amount, replacing comma with dot for proper decimal conversion
      final amountText = _amountController.text.replaceAll(',', '.');
      final amount = double.tryParse(amountText);
      
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserire un importo valido')),
        );
        return;
      }
      
      context.read<DebtCaseBloc>().add(
            CreateDebtCase(
              debtorName: _debtorNameController.text,
              initialState: _initialState,
              lastStateDate: _lastStateDate,
              amount: amount,
            ),
          );
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastStateDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _lastStateDate) {
      setState(() {
        _lastStateDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Case'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _debtorNameController,
                decoration: const InputDecoration(
                  labelText: 'Debtor Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter debtor name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '€ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter debt amount';
                  }
                  // Check if it's a valid number (allowing both comma and dot as decimal separators)
                  final normalizedValue = value.replaceAll(',', '.');
                  if (double.tryParse(normalizedValue) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CaseState>(
                value: _initialState,
                decoration: const InputDecoration(
                  labelText: 'Initial State',
                  border: OutlineInputBorder(),
                ),
                items: CaseState.values
                    .where((state) => state != CaseState.completata)
                    .map((state) => DropdownMenuItem(
                          value: state,
                          child: Text(_getStateDisplayName(state)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _initialState = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Last State Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_dateFormat.format(_lastStateDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onSubmit,
          child: const Text('Create'),
        ),
      ],
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