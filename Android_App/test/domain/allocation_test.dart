import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/domain/aging.dart';
import 'package:bakibondhu/domain/allocation.dart';
import 'package:bakibondhu/domain/balance.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// These mirror the QA/Test-Case Specification §13 allocation fixtures
/// (F-ALLOC-01 … 08). Each asserts the FIFO allocations, the balance, and — the
/// key invariant — that the aging buckets sum back to the positive balance.
void main() {
  final today = DateTime(2026, 9, 7);
  DateTime dueAgo(int days) => today.subtract(Duration(days: days));

  // Sequential clock so "created order" is deterministic.
  var seq = 0;
  DateTime nextTs() => DateTime(2026, 1, 1).add(Duration(seconds: seq++));

  TxnEntry credit(String id, num taka, {int? dueDaysAgo}) => TxnEntry(
        id: id,
        customerId: 'k1',
        type: TxnType.credit,
        amount: Money.taka(taka),
        dueDate: dueDaysAgo == null ? null : dueAgo(dueDaysAgo),
        createdAt: nextTs(),
      );
  TxnEntry payment(String id, num taka) => TxnEntry(
        id: id,
        customerId: 'k1',
        type: TxnType.payment,
        amount: Money.taka(taka),
        createdAt: nextTs(),
      );
  TxnEntry reverse(String id, num taka, String ofId, {required bool ofCredit}) =>
      TxnEntry(
        id: id,
        customerId: 'k1',
        // reversing a credit is a credit-adjustment; reversing a payment a debit-adjustment
        type: ofCredit ? TxnType.adjustmentCredit : TxnType.adjustmentDebit,
        amount: Money.taka(taka),
        reversalOfId: ofId,
        createdAt: nextTs(),
      );

  /// Total allocated to each credit, in taka, for easy assertions.
  Map<String, int> allocatedTakaByCredit(List<TxnEntry> txns) {
    final out = <String, int>{};
    for (final a in reallocateCustomer(txns)) {
      out[a.creditTxnId] = (out[a.creditTxnId] ?? 0) + (a.amount.paisa ~/ 100);
    }
    return out;
  }

  void expectReconciles(List<TxnEntry> txns) {
    final balance = customerBalance(txns);
    final aging = customerAging(txns, today: today);
    final positive = balance.isPositive ? balance : Money.zero;
    expect(aging.total, positive,
        reason: 'aging buckets must sum to the positive balance');
  }

  setUp(() => seq = 0);

  test('F-ALLOC-01 · partial payment, oldest-first', () {
    final txns = [
      credit('C1', 20000, dueDaysAgo: 18),
      credit('C2', 18000, dueDaysAgo: 10),
      credit('C3', 12000, dueDaysAgo: 1),
      payment('P1', 5000),
    ];
    expect(allocatedTakaByCredit(txns), {'C1': 5000});
    expect(customerBalance(txns), Money.taka(45000));
    final aging = customerAging(txns, today: today);
    expect(aging.bucket0to7, Money.taka(12000));
    expect(aging.bucket8to30, Money.taka(33000));
    expectReconciles(txns);
  });

  test('F-ALLOC-02 · payment spanning multiple credits', () {
    final txns = [
      credit('C1', 20000, dueDaysAgo: 18),
      credit('C2', 18000, dueDaysAgo: 10),
      credit('C3', 12000, dueDaysAgo: 1),
      payment('P1', 25000),
    ];
    expect(allocatedTakaByCredit(txns), {'C1': 20000, 'C2': 5000});
    expect(customerBalance(txns), Money.taka(25000));
    final aging = customerAging(txns, today: today);
    expect(aging.bucket0to7, Money.taka(12000));
    expect(aging.bucket8to30, Money.taka(13000));
    expectReconciles(txns);
  });

  test('F-ALLOC-03 · multiple payments', () {
    final txns = [
      credit('C1', 20000, dueDaysAgo: 18),
      credit('C2', 18000, dueDaysAgo: 10),
      payment('P1', 15000),
      payment('P2', 10000),
    ];
    expect(allocatedTakaByCredit(txns), {'C1': 20000, 'C2': 5000});
    expect(customerBalance(txns), Money.taka(13000));
    expect(customerAging(txns, today: today).bucket8to30, Money.taka(13000));
    expectReconciles(txns);
  });

  test('F-ALLOC-04 · overpayment leaves an advance (unallocated)', () {
    final txns = [
      credit('C1', 10000, dueDaysAgo: 5),
      payment('P1', 15000),
    ];
    expect(allocatedTakaByCredit(txns), {'C1': 10000});
    expect(customerBalance(txns), Money.taka(-5000));
    expect(customerAging(txns, today: today).total, Money.zero);
    expectReconciles(txns);
  });

  test('F-ALLOC-04b · advance absorbed by the next credit', () {
    final txns = [
      credit('C1', 10000, dueDaysAgo: 5),
      payment('P1', 15000),
      credit('C2', 8000, dueDaysAgo: 0),
    ];
    expect(allocatedTakaByCredit(txns), {'C1': 10000, 'C2': 5000});
    expect(customerBalance(txns), Money.taka(3000));
    expect(customerAging(txns, today: today).bucket0to7, Money.taka(3000));
    expectReconciles(txns);
  });

  test('F-ALLOC-05 · reverse a credit', () {
    final txns = [
      credit('C1', 20000, dueDaysAgo: 18),
      credit('C2', 18000, dueDaysAgo: 10),
      payment('P1', 15000),
      reverse('R1', 18000, 'C2', ofCredit: true),
    ];
    expect(allocatedTakaByCredit(txns), {'C1': 15000});
    expect(customerBalance(txns), Money.taka(5000));
    expect(customerAging(txns, today: today).bucket8to30, Money.taka(5000));
    expectReconciles(txns);
  });

  test('F-ALLOC-06 · reverse a payment re-exposes the credit', () {
    final txns = [
      credit('C1', 20000, dueDaysAgo: 18),
      payment('P1', 20000),
      reverse('D1', 20000, 'P1', ofCredit: false),
    ];
    expect(allocatedTakaByCredit(txns), isEmpty);
    expect(customerBalance(txns), Money.taka(20000));
    expect(customerAging(txns, today: today).bucket8to30, Money.taka(20000));
    expectReconciles(txns);
  });

  test('F-ALLOC-07 · idempotent — recompute gives identical result', () {
    final txns = [
      credit('C1', 20000, dueDaysAgo: 18),
      credit('C2', 18000, dueDaysAgo: 10),
      payment('P1', 25000),
    ];
    final first = allocatedTakaByCredit(txns);
    final second = allocatedTakaByCredit(txns);
    expect(second, first);
  });

  test('F-ALLOC-08 · exact settle', () {
    final txns = [
      credit('C1', 10000, dueDaysAgo: 5),
      payment('P1', 10000),
    ];
    expect(allocatedTakaByCredit(txns), {'C1': 10000});
    expect(customerBalance(txns), Money.zero);
    expect(customerAging(txns, today: today).total, Money.zero);
    expectReconciles(txns);
  });
}
