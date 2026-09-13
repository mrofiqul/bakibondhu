import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/aging.dart';
import 'package:bakibondhu/domain/balance.dart';
import 'package:bakibondhu/domain/collections.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// The on-device [LedgerRepository], backed by SQLite (offline-first).
///
/// It persists customers and the append-only transaction ledger; balances and
/// aging are computed in Dart from those rows (same domain functions as the
/// in-memory store), so what the merchant sees offline matches the server.
class SqfliteLedgerRepository implements LedgerRepository {
  final Database _db;
  final Uuid _uuid;

  SqfliteLedgerRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  // ---- mapping helpers ------------------------------------------------------

  Customer _customerFromRow(Map<String, Object?> r) => Customer(
        id: r['id'] as String,
        name: r['name'] as String,
        phone: r['phone'] as String?,
        address: r['address'] as String?,
      );

  TxnEntry _txnFromRow(Map<String, Object?> r) => TxnEntry(
        id: r['id'] as String,
        customerId: r['customer_id'] as String,
        type: _typeFromCode(r['type'] as String),
        amount: Money(r['amount_paisa'] as int),
        dueDate: (r['due_date'] as String?) == null
            ? null
            : DateTime.parse(r['due_date'] as String),
        note: r['note'] as String?,
        reversalOfId: r['reversal_of_id'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  static String _typeCode(TxnType t) {
    switch (t) {
      case TxnType.credit:
        return 'credit';
      case TxnType.payment:
        return 'payment';
      case TxnType.adjustmentDebit:
        return 'adjustment_debit';
      case TxnType.adjustmentCredit:
        return 'adjustment_credit';
    }
  }

  static TxnType _typeFromCode(String code) {
    switch (code) {
      case 'credit':
        return TxnType.credit;
      case 'payment':
        return TxnType.payment;
      case 'adjustment_debit':
        return TxnType.adjustmentDebit;
      case 'adjustment_credit':
        return TxnType.adjustmentCredit;
      default:
        throw ArgumentError('unknown transaction type: $code');
    }
  }

  // ---- customers ------------------------------------------------------------

  @override
  Future<Customer> addCustomer(
      {required String name, String? phone, String? address}) async {
    final c = Customer(id: _uuid.v4(), name: name, phone: phone, address: address);
    await _db.insert('customers', {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
      'address': c.address,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'sync_status': 'PENDING',
    });
    return c;
  }

  @override
  Future<List<Customer>> customers() async {
    final rows = await _db.query('customers', orderBy: 'name');
    return rows.map(_customerFromRow).toList();
  }

  @override
  Future<Customer?> customer(String id) async {
    final rows = await _db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  @override
  Future<Customer?> customerByPhone(String phone) async {
    if (phone.isEmpty) return null;
    final rows = await _db.query('customers',
        where: 'phone = ?', whereArgs: [phone], limit: 1);
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  // ---- transactions (append-only) ------------------------------------------

  @override
  Future<TxnEntry> recordCredit({
    required String customerId,
    required Money amount,
    DateTime? dueDate,
    String? note,
    DateTime? at,
  }) =>
      _insertTxn(customerId, TxnType.credit, amount, dueDate, note, at);

  @override
  Future<TxnEntry> recordPayment({
    required String customerId,
    required Money amount,
    String? note,
    DateTime? at,
  }) =>
      _insertTxn(customerId, TxnType.payment, amount, null, note, at);

  Future<TxnEntry> _insertTxn(String customerId, TxnType type, Money amount,
      DateTime? dueDate, String? note, DateTime? at) async {
    if (amount.isNegative) {
      throw ArgumentError('amount must be >= 0');
    }
    final t = TxnEntry(
      id: _uuid.v4(),
      customerId: customerId,
      type: type,
      amount: amount,
      dueDate: dueDate,
      note: note,
      createdAt: at ?? DateTime.now(),
    );
    await _db.insert('transactions', {
      'id': t.id,
      'customer_id': t.customerId,
      'type': _typeCode(t.type),
      'amount_paisa': t.amount.paisa,
      'due_date': t.dueDate?.toIso8601String(),
      'note': t.note,
      'reversal_of_id': t.reversalOfId,
      'created_at': t.createdAt.toUtc().toIso8601String(),
      'sync_status': 'PENDING',
    });
    return t;
  }

  Future<List<TxnEntry>> _txnsOf(String customerId, {String order = 'created_at ASC'}) async {
    final rows = await _db.query('transactions',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: order);
    return rows.map(_txnFromRow).toList();
  }

  @override
  Future<List<TxnEntry>> transactionsOf(String customerId) =>
      // Newest first; rowid breaks ties so same-timestamp inserts stay ordered.
      _txnsOf(customerId, order: 'created_at DESC, rowid DESC');

  @override
  Future<Money> balanceOf(String customerId) async =>
      customerBalance(await _txnsOf(customerId));

  @override
  Future<Aging> agingOf(String customerId, {required DateTime today}) async =>
      customerAging(await _txnsOf(customerId), today: today);

  @override
  Future<List<CustomerBalance>> customersWithBalances() async {
    final result = <CustomerBalance>[];
    for (final c in await customers()) {
      result.add(CustomerBalance(c, customerBalance(await _txnsOf(c.id))));
    }
    result.sort((a, b) => b.balance.compareTo(a.balance)); // biggest owed first
    return result;
  }

  @override
  Future<Money> totalReceivable() async {
    final all = await _db.query('transactions');
    final byCustomer = <String, List<TxnEntry>>{};
    for (final r in all) {
      final t = _txnFromRow(r);
      byCustomer.putIfAbsent(t.customerId, () => []).add(t);
    }
    return totalOwed(byCustomer.values.map(customerBalance));
  }

  // ---- sales (direct, not tied to a customer) ------------------------------

  Sale _saleFromRow(Map<String, Object?> r) => Sale(
        id: r['id'] as String,
        amount: Money(r['amount_paisa'] as int),
        note: r['note'] as String?,
        soldAt: DateTime.parse(r['sold_at'] as String),
      );

  @override
  Future<Sale> addSale(
      {required Money amount, String? note, DateTime? at}) async {
    if (amount.isNegative) throw ArgumentError('amount must be >= 0');
    final s = Sale(
        id: _uuid.v4(), amount: amount, note: note, soldAt: at ?? DateTime.now());
    await _db.insert('sales', {
      'id': s.id,
      'amount_paisa': s.amount.paisa,
      'note': s.note,
      'sold_at': s.soldAt.toUtc().toIso8601String(),
      'sync_status': 'PENDING',
    });
    return s;
  }

  @override
  Future<List<Sale>> sales() async {
    final rows = await _db.query('sales', orderBy: 'sold_at DESC, rowid DESC');
    return rows.map(_saleFromRow).toList();
  }

  @override
  Future<Money> totalSales() async {
    final rows = await _db
        .rawQuery('SELECT COALESCE(SUM(amount_paisa), 0) AS s FROM sales');
    return Money((rows.first['s'] as int?) ?? 0);
  }

  @override
  Future<Money> todaysSales() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final b in await salesBuckets(SalesPeriod.day)) {
      if (b.start == today) return b.total;
    }
    return Money.zero;
  }

  @override
  Future<List<SalesBucket>> salesBuckets(SalesPeriod period) async {
    // sold_at is stored UTC; bucket by the merchant's LOCAL calendar.
    final rows = await _db.query('sales', columns: ['amount_paisa', 'sold_at']);
    final byBucket = <DateTime, List<int>>{};
    for (final r in rows) {
      final local = DateTime.parse(r['sold_at'] as String).toLocal();
      final key = salesBucketStart(local, period);
      byBucket.putIfAbsent(key, () => []).add(r['amount_paisa'] as int);
    }
    return [
      for (final e in byBucket.entries)
        SalesBucket(
          start: e.key,
          total: Money(e.value.fold(0, (a, b) => a + b)),
          count: e.value.length,
        )
    ]..sort((a, b) => b.start.compareTo(a.start));
  }

  // ---- collections ----

  @override
  Future<CollectionActivity> addCollectionActivity({
    required String customerId,
    required ContactMethod method,
    required CollectionStatus status,
    String? note,
    DateTime? nextFollowUp,
    DateTime? at,
  }) async {
    final activity = CollectionActivity(
      id: _uuid.v4(),
      customerId: customerId,
      method: method,
      status: status,
      note: note,
      nextFollowUp: nextFollowUp,
      contactedAt: at ?? DateTime.now(),
    );
    await _db.insert('collection_activities', {
      'id': activity.id,
      'customer_id': customerId,
      'method': contactMethodCodes[method],
      'status': collectionStatusCodes[status],
      'note': note,
      'contacted_at': activity.contactedAt.toUtc().toIso8601String(),
      'next_follow_up': nextFollowUp?.toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'sync_status': 'PENDING',
    });
    return activity;
  }

  @override
  Future<List<CollectionActivity>> collectionActivitiesOf(String customerId) async {
    final rows = await _db.query('collection_activities',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'contacted_at DESC, rowid DESC');
    return rows.map((r) => CollectionActivity(
          id: r['id'] as String,
          customerId: r['customer_id'] as String,
          method: contactMethodFromCode(r['method'] as String),
          status: collectionStatusFromCode(r['status'] as String),
          note: r['note'] as String?,
          contactedAt: DateTime.parse(r['contacted_at'] as String),
          nextFollowUp: (r['next_follow_up'] as String?) == null
              ? null
              : DateTime.parse(r['next_follow_up'] as String),
        )).toList();
  }

  @override
  Future<PromiseToPay> addPromise({
    required String customerId,
    required Money amount,
    required DateTime promiseDate,
    DateTime? followUpDate,
    String? note,
    DateTime? at,
  }) async {
    final promise = PromiseToPay(
      id: _uuid.v4(),
      customerId: customerId,
      promisedAmount: amount,
      promiseDate: promiseDate,
      followUpDate: followUpDate,
      customerNote: note,
      createdAt: at ?? DateTime.now(),
    );
    await _db.insert('promise_to_pay', {
      'id': promise.id,
      'customer_id': customerId,
      'promised_amount_paisa': amount.paisa,
      'promise_date': promiseDate.toIso8601String(),
      'follow_up_date': followUpDate?.toIso8601String(),
      'customer_note': note,
      'status': promiseStatusCodes[PromiseStatus.open],
      'created_at': promise.createdAt.toUtc().toIso8601String(),
      'sync_status': 'PENDING',
    });
    return promise;
  }

  @override
  Future<List<PromiseToPay>> promisesOf(String customerId) async {
    final rows = await _db.query('promise_to_pay',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'created_at DESC, rowid DESC');
    return rows.map((r) => PromiseToPay(
          id: r['id'] as String,
          customerId: r['customer_id'] as String,
          promisedAmount: Money(r['promised_amount_paisa'] as int),
          promiseDate: DateTime.parse(r['promise_date'] as String),
          followUpDate: (r['follow_up_date'] as String?) == null
              ? null
              : DateTime.parse(r['follow_up_date'] as String),
          customerNote: r['customer_note'] as String?,
          status: promiseStatusFromCode(r['status'] as String),
          createdAt: DateTime.parse(r['created_at'] as String),
        )).toList();
  }
}
