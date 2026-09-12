import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/data/in_memory_ledger_repository.dart';
import 'package:bakibondhu/domain/collections.dart';
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
    expect(await repo.totalSales(), Money.zero);
    expect(await repo.dailySales(), isEmpty);
  });

  test('total sales = credit only, grouped by day, newest first', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম');
    final b = await repo.addCustomer(name: 'বকুল');

    // Sep 5: two credits (৳1000 + ৳500)
    await repo.recordCredit(customerId: k.id, amount: Money.taka(1000), at: DateTime(2026, 9, 5, 10));
    await repo.recordCredit(customerId: b.id, amount: Money.taka(500), at: DateTime(2026, 9, 5, 16));
    // Sep 7: one credit (৳2000) + a payment that must NOT count as a sale
    await repo.recordCredit(customerId: k.id, amount: Money.taka(2000), at: DateTime(2026, 9, 7, 9));
    await repo.recordPayment(customerId: k.id, amount: Money.taka(300), at: DateTime(2026, 9, 7, 12));

    expect(await repo.totalSales(), Money.taka(3500)); // 1000+500+2000; payment excluded

    final days = await repo.dailySales();
    expect(days.length, 2);
    expect(days.first.day, DateTime(2026, 9, 7)); // newest day first
    expect(days.first.total, Money.taka(2000));
    expect(days.first.count, 1);
    expect(days[1].day, DateTime(2026, 9, 5));
    expect(days[1].total, Money.taka(1500));
    expect(days[1].count, 2);
  });

  test('todaysSales counts only today\'s credit', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম');
    final now = DateTime.now();
    await repo.recordCredit(customerId: k.id, amount: Money.taka(700), at: now);
    await repo.recordCredit(customerId: k.id, amount: Money.taka(300), at: now);
    await repo.recordCredit(customerId: k.id, amount: Money.taka(9999), at: now.subtract(const Duration(days: 3)));
    await repo.recordPayment(customerId: k.id, amount: Money.taka(100), at: now); // not a sale

    expect(await repo.todaysSales(), Money.taka(1000)); // 700 + 300 only
  });

  test('records collection activities and promises, newest first', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম');

    await repo.addCollectionActivity(
      customerId: k.id,
      method: ContactMethod.phone,
      status: CollectionStatus.promiseToPay,
      note: 'শুক্রবার দেবে',
      at: DateTime(2026, 9, 1),
    );
    await repo.addCollectionActivity(
      customerId: k.id,
      method: ContactMethod.visit,
      status: CollectionStatus.paid,
      at: DateTime(2026, 9, 5),
    );
    await repo.addPromise(
      customerId: k.id,
      amount: Money.taka(20000),
      promiseDate: DateTime(2026, 9, 12),
    );

    final activities = await repo.collectionActivitiesOf(k.id);
    expect(activities.length, 2);
    expect(activities.first.status, CollectionStatus.paid); // newest first

    final promises = await repo.promisesOf(k.id);
    expect(promises.single.promisedAmount, Money.taka(20000));
    expect(promises.single.status, PromiseStatus.open);
  });
}
