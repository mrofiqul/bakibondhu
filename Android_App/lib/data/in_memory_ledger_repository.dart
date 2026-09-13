import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/aging.dart';
import 'package:bakibondhu/domain/balance.dart';
import 'package:bakibondhu/domain/collections.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// In-memory [LedgerRepository] — used by tests and as a reference for the
/// sqflite store. Balances/aging are derived from the ledger via the domain
/// functions, so this behaves identically to the persistent store.
class InMemoryLedgerRepository implements LedgerRepository {
  final Map<String, Customer> _customers = {};
  final List<TxnEntry> _txns = [];
  final List<Sale> _sales = [];
  final String Function() _newId;

  /// [newId] is injectable so tests can use deterministic ids; production passes
  /// a UUID generator (offline id-generation, spec §19).
  InMemoryLedgerRepository({String Function()? newId})
      : _newId = newId ?? _defaultId;

  static int _seq = 0;
  static String _defaultId() => 'id-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  @override
  Future<Customer> addCustomer(
      {required String name, String? phone, String? address}) async {
    final c = Customer(id: _newId(), name: name, phone: phone, address: address);
    _customers[c.id] = c;
    return c;
  }

  @override
  Future<List<Customer>> customers() async => _customers.values.toList();

  @override
  Future<Customer?> customer(String id) async => _customers[id];

  @override
  Future<Customer?> customerByPhone(String phone) async {
    if (phone.isEmpty) return null;
    for (final c in _customers.values) {
      if (c.phone == phone) return c;
    }
    return null;
  }

  @override
  Future<Customer> updateCustomer(
      {required String id,
      required String name,
      String? phone,
      String? address}) async {
    final c = Customer(id: id, name: name, phone: phone, address: address);
    _customers[id] = c;
    return c;
  }

  @override
  Future<void> deleteCustomer(String id) async {
    if (_txns.any((t) => t.customerId == id)) {
      throw const CustomerHasTransactions();
    }
    _customers.remove(id);
  }

  @override
  Future<TxnEntry> recordCredit({
    required String customerId,
    required Money amount,
    DateTime? dueDate,
    String? note,
    DateTime? at,
  }) =>
      _record(customerId, TxnType.credit, amount, dueDate, note, at);

  @override
  Future<TxnEntry> recordPayment({
    required String customerId,
    required Money amount,
    String? note,
    DateTime? at,
  }) =>
      _record(customerId, TxnType.payment, amount, null, note, at);

  Future<TxnEntry> _record(String customerId, TxnType type, Money amount,
      DateTime? dueDate, String? note, DateTime? at) async {
    assert(_customers.containsKey(customerId), 'unknown customer');
    assert(!amount.isNegative, 'amount must be >= 0');
    final t = TxnEntry(
      id: _newId(),
      customerId: customerId,
      type: type,
      amount: amount,
      dueDate: dueDate,
      note: note,
      createdAt: at ?? DateTime.now(),
    );
    _txns.add(t);
    return t;
  }

  List<TxnEntry> _of(String customerId) =>
      _txns.where((t) => t.customerId == customerId).toList();

  @override
  Future<List<TxnEntry>> transactionsOf(String customerId) async {
    // Newest first; ties (same timestamp) break by insertion order so the most
    // recently recorded entry always sorts first.
    final indexed = <MapEntry<int, TxnEntry>>[];
    for (var i = 0; i < _txns.length; i++) {
      if (_txns[i].customerId == customerId) indexed.add(MapEntry(i, _txns[i]));
    }
    indexed.sort((a, b) {
      final byTime = b.value.createdAt.compareTo(a.value.createdAt);
      return byTime != 0 ? byTime : b.key.compareTo(a.key);
    });
    return [for (final e in indexed) e.value];
  }

  @override
  Future<Money> balanceOf(String customerId) async =>
      customerBalance(_of(customerId));

  @override
  Future<Aging> agingOf(String customerId, {required DateTime today}) async =>
      customerAging(_of(customerId), today: today);

  @override
  Future<List<CustomerBalance>> customersWithBalances() async {
    final rows = _customers.values
        .map((c) => CustomerBalance(c, customerBalance(_of(c.id))))
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance)); // biggest owed first
    return rows;
  }

  @override
  Future<Money> totalReceivable() async =>
      totalOwed(_customers.keys.map((id) => customerBalance(_of(id))));

  @override
  Future<Sale> addSale(
      {required Money amount, String? note, DateTime? at}) async {
    assert(!amount.isNegative, 'amount must be >= 0');
    final s = Sale(
        id: _newId(), amount: amount, note: note, soldAt: at ?? DateTime.now());
    _sales.add(s);
    return s;
  }

  @override
  Future<List<Sale>> sales() async {
    final list = [..._sales]..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    return list;
  }

  @override
  Future<Money> totalSales() async =>
      Money(_sales.fold(0, (sum, s) => sum + s.amount.paisa));

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
    final byBucket = <DateTime, List<int>>{};
    for (final s in _sales) {
      final key = salesBucketStart(s.soldAt.toLocal(), period);
      byBucket.putIfAbsent(key, () => []).add(s.amount.paisa);
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

  final List<CollectionActivity> _activities = [];
  final List<PromiseToPay> _promises = [];

  @override
  Future<CollectionActivity> addCollectionActivity({
    required String customerId,
    required ContactMethod method,
    required CollectionStatus status,
    String? note,
    DateTime? nextFollowUp,
    DateTime? at,
  }) async {
    final a = CollectionActivity(
      id: _newId(),
      customerId: customerId,
      method: method,
      status: status,
      note: note,
      nextFollowUp: nextFollowUp,
      contactedAt: at ?? DateTime.now(),
    );
    _activities.add(a);
    return a;
  }

  @override
  Future<List<CollectionActivity>> collectionActivitiesOf(String customerId) async {
    final list = _activities.where((a) => a.customerId == customerId).toList()
      ..sort((a, b) => b.contactedAt.compareTo(a.contactedAt));
    return list;
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
    final p = PromiseToPay(
      id: _newId(),
      customerId: customerId,
      promisedAmount: amount,
      promiseDate: promiseDate,
      followUpDate: followUpDate,
      customerNote: note,
      createdAt: at ?? DateTime.now(),
    );
    _promises.add(p);
    return p;
  }

  @override
  Future<List<PromiseToPay>> promisesOf(String customerId) async {
    final list = _promises.where((p) => p.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
