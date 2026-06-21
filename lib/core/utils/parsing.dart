/// Coerces a dynamic JSON value to a [double], returning 0 when it cannot be
/// parsed. Centralises the `_toDouble` helper that was duplicated verbatim
/// across data models, repositories and pages.
double toDoubleOrZero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
