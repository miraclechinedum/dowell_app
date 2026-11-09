/// Standard employee task bonus, configured in
/// `app_settings/reward_settings.employee_cash_bonus`.
///
/// Mirrors `configuredTaskBonus` in functions/src/admin-finance.ts, which is
/// the authority: the server reads the setting itself and rejects approval if
/// it is missing or invalid. The client only displays it.
const double maxTaskBonus = 1000;

/// Returns the configured bonus, or null when the setting is missing or
/// invalid (non-numeric, not positive, above [maxTaskBonus], or not whole cents).
double? configuredTaskBonus(Map<String, dynamic>? settings) {
  final value = settings?['employee_cash_bonus'];
  if (value is! num) return null;
  final amount = value.toDouble();
  if (!amount.isFinite || amount <= 0 || amount > maxTaskBonus) return null;
  if ((amount * 100).roundToDouble() / 100 != amount) return null;
  return amount;
}
