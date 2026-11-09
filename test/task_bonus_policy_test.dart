import 'package:dowell_app/core/services/task_bonus_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a valid configured bonus', () {
    expect(configuredTaskBonus({'employee_cash_bonus': 25}), 25);
    expect(configuredTaskBonus({'employee_cash_bonus': 12.5}), 12.5);
  });

  test('accepts the confirmed boundaries 0.01 and 1000', () {
    expect(configuredTaskBonus({'employee_cash_bonus': 0.01}), 0.01);
    expect(configuredTaskBonus({'employee_cash_bonus': 1000}), 1000);
    expect(configuredTaskBonus({'employee_cash_bonus': 1000.0}), 1000);
  });

  test('rejects values just outside the boundaries', () {
    expect(configuredTaskBonus({'employee_cash_bonus': 1000.01}), isNull);
    expect(configuredTaskBonus({'employee_cash_bonus': 0.001}), isNull);
    expect(configuredTaskBonus({'employee_cash_bonus': double.infinity}), isNull);
  });

  test('rejects missing or invalid configuration instead of defaulting', () {
    for (final settings in <Map<String, dynamic>?>[
      null,
      {},
      {'employee_cash_bonus': '25'},
      {'employee_cash_bonus': 0},
      {'employee_cash_bonus': -5},
      {'employee_cash_bonus': 1000.01},
      {'employee_cash_bonus': 2.345},
      {'employee_cash_bonus': double.nan},
    ]) {
      expect(configuredTaskBonus(settings), isNull, reason: '$settings');
    }
  });
}
