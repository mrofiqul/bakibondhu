import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/data/in_memory_ledger_repository.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
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

  test('customerByPhone finds an existing number, for per-shop uniqueness', () async {
    final repo = newRepo();
    await repo.addCustomer(name: 'করিম', phone: '01712345678');
    await repo.addCustomer(name: 'রহিম'); // no phone

    expect((await repo.customerByPhone('01712345678'))?.name, 'করিম');
    expect(await repo.customerByPhone('01799999999'), isNull); // not present
    expect(await repo.customerByPhone(''), isNull); // empty never matches
  });

  test('updateCustomer edits the profile; new number becomes findable', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম', phone: '01712345678');

    await repo.updateCustomer(
        id: k.id, name: 'করিম স্টোর', phone: '01799990000', address: 'ঢাকা');

    final updated = await repo.customer(k.id);
    expect(updated!.name, 'করিম স্টোর');
    expect(updated.address, 'ঢাকা');
    expect((await repo.customerByPhone('01799990000'))?.id, k.id); // new number
    expect(await repo.customerByPhone('01712345678'), isNull); // old number freed
  });

  test('deleteCustomer removes a customer with no ledger entries', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'রহিম', phone: '01712345678');

    await repo.deleteCustomer(k.id);

    expect(await repo.customer(k.id), isNull);
    expect(await repo.customers(), isEmpty);
    expect(await repo.customerByPhone('01712345678'), isNull); // number freed for reuse
  });

  test('deleteCustomer is blocked while the customer still owes money', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম');
    await repo.recordCredit(customerId: k.id, amount: Money.taka(5000));

    expect(() => repo.deleteCustomer(k.id),
        throwsA(isA<CustomerHasOutstandingDue>()));
    expect(await repo.customer(k.id), isNotNull); // still there
  });

  test('deleteCustomer is allowed once the balance is settled (পরিশোধিত)',
      () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম');
    await repo.recordCredit(customerId: k.id, amount: Money.taka(5000));
    await repo.recordPayment(customerId: k.id, amount: Money.taka(5000)); // net zero

    await repo.deleteCustomer(k.id); // no throw — settled customers are removable

    expect(await repo.customer(k.id), isNull);
    expect(await repo.transactionsOf(k.id), isEmpty); // history removed too
  });

  test('clearAllData wipes every local record (shop isolation on login)',
      () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'রহিম');
    await repo.recordCredit(customerId: k.id, amount: Money.taka(1000));
    await repo.addSale(amount: Money.taka(500));

    await repo.clearAllData();

    expect(await repo.customers(), isEmpty);
    expect(await repo.transactionsOf(k.id), isEmpty);
    expect(await repo.sales(), isEmpty);
    expect(await repo.totalReceivable(), Money.zero);
  });

  test('empty repository', () async {
    final repo = newRepo();
    expect(await repo.customers(), isEmpty);
    expect(await repo.totalReceivable(), Money.zero);
    expect(await repo.totalSales(), Money.zero);
    expect(await repo.salesBuckets(SalesPeriod.day), isEmpty);
  });

  test('sales are direct entries (not customer credit)', () async {
    final repo = newRepo();
    final k = await repo.addCustomer(name: 'করিম');
    // Customer credit is NOT a sale.
    await repo.recordCredit(customerId: k.id, amount: Money.taka(5000));
    expect(await repo.totalSales(), Money.zero);
    // A recorded sale is.
    await repo.addSale(amount: Money.taka(800), note: 'চাল');
    expect(await repo.totalSales(), Money.taka(800));
    expect((await repo.sales()).single.note, 'চাল');
  });

  test('sales total and buckets by day/month/quarter/year', () async {
    final repo = newRepo();
    await repo.addSale(amount: Money.taka(1000), at: DateTime(2026, 9, 5, 10));
    await repo.addSale(amount: Money.taka(500), at: DateTime(2026, 9, 5, 16));
    await repo.addSale(amount: Money.taka(2000), at: DateTime(2026, 9, 7, 9));
    await repo.addSale(amount: Money.taka(400), at: DateTime(2026, 6, 2, 9)); // Q2
    await repo.addSale(amount: Money.taka(9999), at: DateTime(2025, 12, 1, 9));

    expect(await repo.totalSales(), Money.taka(13899));

    final byDay = await repo.salesBuckets(SalesPeriod.day);
    expect(byDay.length, 4);
    expect(byDay.first.start, DateTime(2026, 9, 7)); // newest first
    expect(byDay.first.total, Money.taka(2000));
    expect(byDay[1].start, DateTime(2026, 9, 5));
    expect(byDay[1].total, Money.taka(1500));
    expect(byDay[1].count, 2);

    final byMonth = await repo.salesBuckets(SalesPeriod.month);
    expect(byMonth.length, 3);
    expect(byMonth.first.start, DateTime(2026, 9));
    expect(byMonth.first.total, Money.taka(3500));

    final byQuarter = await repo.salesBuckets(SalesPeriod.quarter);
    expect(byQuarter.length, 3);
    expect(byQuarter.first.start, DateTime(2026, 7)); // Q3 (Jul–Sep)
    expect(byQuarter.first.total, Money.taka(3500));

    final byYear = await repo.salesBuckets(SalesPeriod.year);
    expect(byYear.length, 2);
    expect(byYear.first.start, DateTime(2026));
    expect(byYear.first.total, Money.taka(3900)); // 3500 + 400
    expect(byYear[1].total, Money.taka(9999));
  });

  test('todaysSales counts only today', () async {
    final repo = newRepo();
    final now = DateTime.now();
    await repo.addSale(amount: Money.taka(700), at: now);
    await repo.addSale(amount: Money.taka(300), at: now);
    await repo.addSale(amount: Money.taka(9999), at: now.subtract(const Duration(days: 3)));
    expect(await repo.todaysSales(), Money.taka(1000)); // 700 + 300
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
