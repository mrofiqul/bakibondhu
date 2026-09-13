import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';
import 'package:bakibondhu/features/customers/history_export.dart';

void main() {
  test('history statement lists oldest-first with a running balance', () {
    const customer = Customer(id: 'c1', name: 'করিম', phone: '01712345678');
    // Detail screen holds newest-first.
    final history = [
      TxnEntry(
          id: 't2',
          customerId: 'c1',
          type: TxnType.payment,
          amount: Money.taka(300),
          createdAt: DateTime(2026, 9, 10)),
      TxnEntry(
          id: 't1',
          customerId: 'c1',
          type: TxnType.credit,
          amount: Money.taka(1000),
          note: 'চাল',
          createdAt: DateTime(2026, 9, 5)),
    ];

    final s = buildHistoryStatement(
      customer: customer,
      history: history,
      balance: Money.taka(700),
      shopName: 'রহিম স্টোর',
      now: DateTime(2026, 9, 12),
    );

    // Header
    expect(s, contains('করিম'));
    expect(s, contains('01712345678'));
    expect(s, contains('রহিম স্টোর'));

    // Both legs with signed amounts
    expect(s, contains(S.gaveCredit));
    expect(s, contains(S.gotPayment));
    expect(s, contains('+৳1,000'));
    expect(s, contains('−৳300'));
    expect(s, contains('চাল')); // the note

    // Oldest-first: the credit (Sep 5) is listed before the payment (Sep 10).
    expect(s.indexOf('+৳1,000'), lessThan(s.indexOf('−৳300')));

    // Running balance: 1000 after the credit, 700 after the payment.
    expect(s, contains('৳1,000 বাকি'));
    expect(s, contains('৳700 বাকি'));

    // Footer totals
    expect(s, contains('${S.totalTransactions}: 2'));
    expect(s, contains(S.madeWithApp));
  });

  test('empty history still produces a valid statement', () {
    const customer = Customer(id: 'c1', name: 'রহিম');
    final s = buildHistoryStatement(
      customer: customer,
      history: const [],
      balance: Money.zero,
      shopName: 'দোকান',
      now: DateTime(2026, 9, 12),
    );
    expect(s, contains('রহিম'));
    expect(s, contains(S.noHistory));
    expect(s, contains('${S.totalTransactions}: 0'));
  });
}
