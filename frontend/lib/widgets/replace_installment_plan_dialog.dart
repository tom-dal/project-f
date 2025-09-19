import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/italian_date_picker.dart';
import '../utils/installment_rounding.dart';

/// Mostra il dialog per sostituire il piano rateale applicando la logica:
/// - Tutte le rate tranne l'ultima sono arrotondate all'intero (floor)
/// - L'ultima rata include il resto decimale per arrivare al totale residuo
Future<void> showReplaceInstallmentPlanDialog({
  required BuildContext context,
  required double residuo,
  required int initialInstallments,
  required DateTime initialFirstDueDate,
  required void Function({required int numberOfInstallments, required DateTime firstDueDate, required double perInstallmentAmountFloor, required int frequencyDays, required double total}) onConfirm,
}) async {
  final installmentsCtrl = TextEditingController(text: initialInstallments.toString());
  final freqCtrl = TextEditingController(text: '30');
  int parsedInstallments = initialInstallments;
  int parsedFreq = 30;
  DateTime firstDue = initialFirstDueDate;
  bool userPicked = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      void recalc({bool fromFreq = false}) {
        parsedInstallments = int.tryParse(installmentsCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        parsedFreq = int.tryParse(freqCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (parsedFreq <= 0) parsedFreq = 1;
        if (!userPicked && (fromFreq || parsedInstallments > 0)) {
          firstDue = DateTime.now().add(Duration(days: parsedFreq));
        }
        setState(() {});
      }

      Future<void> pick() async {
        final p = await pickItalianDate(
          ctx,
          initialDate: firstDue,
          firstDate: DateTime(DateTime.now().year - 1),
          lastDate: DateTime(DateTime.now().year + 5),
          helpText: 'Prima scadenza',
        );
        if (p != null) {
          setState(() {
            firstDue = DateTime(p.year, p.month, p.day);
            userPicked = true;
          });
        }
      }

      final per = perInstallmentIntFloor(residuo, parsedInstallments);
      final rem = lastInstallmentWithRemainder(residuo, per, parsedInstallments);

      String? validate() {
        if (parsedInstallments < 2) return 'Minimo 2 rate';
        if (parsedInstallments > 240) return 'Troppe rate';
        if (per < 0.01) return 'Importo rata troppo basso';
        if (parsedFreq < 1) return 'Frequenza minima 1';
        if (parsedFreq > 365) return 'Frequenza massima 365';
        return null;
      }

      void submit() {
        final err = validate();
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          return;
        }
        onConfirm(
          numberOfInstallments: parsedInstallments,
          firstDueDate: firstDue,
          perInstallmentAmountFloor: per,
          frequencyDays: parsedFreq,
          total: residuo,
        );
        Navigator.pop(ctx);
      }

      final fmt = NumberFormat('#,##0.00', 'it_IT');
      final error = validate();

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifica piano rateale'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Debito residuo: € ${fmt.format(residuo)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: installmentsCtrl,
                    decoration: const InputDecoration(labelText: 'Numero rate'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => recalc(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: freqCtrl,
                    decoration: const InputDecoration(labelText: 'Giorni tra rate'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => recalc(fromFreq: true),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              InkWell(
                onTap: pick,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Prima scadenza'),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(_fmtDate(firstDue)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Text('Importo rata: € ${fmt.format(per)}'),
              const SizedBox(height: 4),
              Text('Importo ultima rata: € ${fmt.format(rem < 0 ? 0 : rem)}', style: const TextStyle(color: Colors.black54)),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(onPressed: submit, child: const Text('Conferma')),
        ],
      );
    }),
  );
}

String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

