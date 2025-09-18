import 'package:flutter/material.dart';

/// Helper centralizzato per la selezione di date in italiano
/// Garantisce coerenza di testi, localizzazione e stile.
Future<DateTime?> pickItalianDate(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? helpText,
  Widget Function(BuildContext, Widget?)? builder,
}) {
  final now = DateTime.now();
  final init = initialDate ?? DateTime(now.year, now.month, now.day);
  final first = firstDate ?? DateTime(now.year - 5);
  final last = lastDate ?? DateTime(now.year + 10);
  DateTime safeInit = init;
  if (safeInit.isBefore(first)) safeInit = first;
  if (safeInit.isAfter(last)) safeInit = last;
  return showDatePicker(
    context: context,
    initialDate: safeInit,
    firstDate: first,
    lastDate: last,
    helpText: helpText ?? 'Seleziona data',
    cancelText: 'Annulla',
    confirmText: 'Conferma',
    errorFormatText: 'Formato non valido',
    errorInvalidText: 'Data non valida',
    fieldLabelText: 'Inserisci data',
    fieldHintText: 'gg/mm/aaaa',
    locale: const Locale('it', 'IT'),
    builder: (ctx, child) {
      final theme = Theme.of(ctx);
      final themed = Theme(
        data: theme.copyWith(
          datePickerTheme: const DatePickerThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
      if (builder != null) {
        return builder(ctx, themed);
      }
      return themed;
    },
  );
}
