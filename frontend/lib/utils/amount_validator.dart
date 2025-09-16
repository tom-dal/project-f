class AmountValidationResult {
  final double? value;
  final String? error;
  const AmountValidationResult({this.value, this.error});
  bool get isValid => value != null && error == null;
}

// USER PREFERENCE: Normalizzazione flessibile stile italiano. Ultimo separatore (.,) = decimale, altri = migliaia.
AmountValidationResult normalizeFlexibleItalianAmount(String raw) {
  final original = raw.trim();
  if (original.isEmpty) return const AmountValidationResult(error: 'Importo non valido');
  final stripped = original.replaceAll(RegExp(r'\s'), '');
  final lastDot = stripped.lastIndexOf('.');
  final lastComma = stripped.lastIndexOf(',');
  final sepIndex = lastDot > lastComma ? lastDot : lastComma;
  String intPart;
  String fracPart = '';
  if (sepIndex >= 0) {
    intPart = stripped.substring(0, sepIndex).replaceAll(RegExp(r'[^0-9]'), '');
    fracPart = stripped.substring(sepIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
  } else {
    intPart = stripped.replaceAll(RegExp(r'[^0-9]'), '');
  }
  if (intPart.isEmpty) return const AmountValidationResult(error: 'Importo non valido');
  if (fracPart.length > 2) return const AmountValidationResult(error: 'Max 2 decimali');
  final composed = intPart + (fracPart.isNotEmpty ? '.$fracPart' : '');
  final val = double.tryParse(composed);
  if (val == null || val <= 0) return const AmountValidationResult(error: 'Importo non valido');
  return AmountValidationResult(value: val);
}

