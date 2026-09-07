import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/aging.dart';
import 'package:bakibondhu/domain/balance.dart';
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
  Future<Customer> addCustomer({required String name, String? phone}) async {
    final c = Customer(id: _uuid.v4(), name: name, phone: phone);
    await _db.insert('customers', {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
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
}
