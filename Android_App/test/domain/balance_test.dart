import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/domain/balance.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

void main() {
  group('Money', () {
    test('lakh grouping and ৳ prefix', () {
      expect(Money.taka(124500).format(), '৳1,24,500');
      expect(Money.taka(45000).format(), '৳45,000');
      expect(Money.taka(500).format(), '৳500');
      expect(Money.taka(0).format(), '৳0');
    });

    test('paisa shown only when present, no float error', () {
      expect(Money.taka(12.50).format(), '৳12.50');
      expect(Money.taka(0.1) + Money.taka(0.2), Money.taka(0.3)); // exact
    });
  });

  group('balance', () {
    TxnEntry credit(num t) => TxnEntry(
        id: 'c$t',
        customerId: 'k1',
        type: TxnType.credit,
        amount: Money.taka(t),
        createdAt: DateTime(2026, 1, 1));
    TxnEntry payment(num t) => TxnEntry(
        id: 'p$t',
        customerId: 'k1',
        type: TxnType.payment,
        amount: Money.taka(t),
        createdAt: DateTime(2026, 1, 2));

    test('balance = Σ amount × sign', () {
      expect(customerBalance([credit(20000), credit(18000), payment(5000)]),
          Money.taka(33000));
    });

    test('overpayment yields a negative (advance) balance', () {
      expect(customerBalance([credit(10000), payment(15000)]), Money.taka(-5000));
    });

    test('totalOwed sums only positive balances', () {
      final balances = [Money.taka(45000), Money.taka(-5000), Money.taka(28500)];
      expect(totalOwed(balances), Money.taka(73500));
    });
  });
}
