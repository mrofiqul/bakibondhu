import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/aging.dart';
import 'package:bakibondhu/domain/balance.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// In-memory [LedgerRepository] — used by tests and as a reference for the
/// sqflite store. Balances/aging are derived from the ledger via the domain
/// functions, so this behaves identically to the persistent store.
class InMemoryLedgerRepository implements LedgerRepository {
  final Map<String, Customer> _customers = {};
  final List<TxnEntry> _txns = [];
  final String Function() _newId;

  /// [newId] is injectable so tests can use deterministic ids; production passes
  /// a UUID generator (offline id-generation, spec §19).
  InMemoryLedgerRepository({String Function()? newId})
      : _newId = newId ?? _defaultId;

  static int _seq = 0;
  static String _defaultId() => 'id-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  @override
  Future<Customer> addCustomer({required String name, String? phone}) async {
    final c = Customer(id: _newId(), name: name, phone: phone);
    _customers[c.id] = c;
    return c;
  }

  @override
  Future<List<Customer>> customers() async => _customers.values.toList();

  @override
  Future<Customer?> customer(String id) async => _customers[id];

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
}
