import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/data/in_memory_ledger_repository.dart';
import 'package:bakibondhu/domain/money.dart';

/// Behavioural tests for the repository contract, against the in-memory store.
/// The sqflite store shares the same domain logic, so this pins the behaviour
/// both implementations must honour.
void main() {
  final today = DateTime(2026, 9, 7);
  DateTime dueAgo(int d) => today.subtract(Duration(days: d));

  // Deterministic ids for readable assertions.
  InMemoryLedgerRepository newRepo() {
    var n = 0;
    return InMemoryLedgerRepository(newId: () => 'x${n++}');
  }

  test('records credit/payment; balance, total and aging reconcile', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম স্টোর', phone: '01712345678');

    await repo.recordCredit(customerId: k.id, amount: Money.taka(20000), dueDate: dueAgo(18));
    await repo.recordCredit(customerId: k.id, amount: Money.taka(18000), dueDate: dueAgo(10));
    await repo.recordPayment(customerId: k.id, amount: Money.taka(5000));

    expect(await repo.balanceOf(k.id), Money.taka(33000));
    expect(await repo.totalReceivable(), Money.taka(33000));
    expect((await repo.agingOf(k.id, today: today)).total, Money.taka(33000));

    final ledger = await repo.transactionsOf(k.id);
    expect(ledger.length, 3);
    // newest first
    expect(ledger.first.amount, Money.taka(5000));
  });

  test('Home list is biggest-owed first; advances are excluded from the total', () async {
    final repo = newRepo();
    final a = await repo.addCustomer(name: 'A');
    final b = await repo.addCustomer(name: 'B');

    await repo.recordCredit(customerId: a.id, amount: Money.taka(1000));
    await repo.recordCredit(customerId: b.id, amount: Money.taka(5000));
    // A overpays -> advance (balance -2000)
    await repo.recordPayment(customerId: a.id, amount: Money.taka(3000));

    final list = await repo.customersWithBalances();
    expect(list.first.customer.id, b.id); // 5000 owed on top
    expect(await repo.balanceOf(a.id), Money.taka(-2000));
    expect(await repo.totalReceivable(), Money.taka(5000)); // A's advance not netted in
  });

  test('empty repository', () async {
    final repo = newRepo();
    expect(await repo.customers(), isEmpty);
    expect(await repo.totalReceivable(), Money.zero);
  });
}
