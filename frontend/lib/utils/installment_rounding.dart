// Rounding helpers for installment plans (integer rounding for all but last installment)
// CUSTOM IMPLEMENTATION: shared logic so edit & readonly screens remain consistent.

double perInstallmentIntFloor(double total, int n) {
  if (n <= 0) return 0;
  final raw = total / n;
  return raw.floorToDouble(); // integer part only
}

double lastInstallmentWithRemainder(double total, double per, int n) {
  if (n <= 0) return 0;
  if (n == 1) return double.parse(total.toStringAsFixed(2));
  final rem = total - per * (n - 1);
  return double.parse(rem.toStringAsFixed(2)); // keep two decimals
}

