import 'package:bakibondhu/domain/aging.dart';
import 'package:bakibondhu/domain/collections.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// A customer paired with their current balance (for the Home list).
class CustomerBalance {
  final Customer customer;
  final Money balance;
  const CustomerBalance(this.customer, this.balance);
}

/// How to bucket the sales report.
enum SalesPeriod { day, month, quarter, year }

/// The local start-of-bucket for a date under [period] (used to group sales).
DateTime salesBucketStart(DateTime d, SalesPeriod period) {
  switch (period) {
    case SalesPeriod.day:
      return DateTime(d.year, d.month, d.day);
    case SalesPeriod.month:
      return DateTime(d.year, d.month);
    case SalesPeriod.quarter:
      return DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1);
    case SalesPeriod.year:
      return DateTime(d.year);
  }
}

/// One period's sales total, for the sales report.
class SalesBucket {
  final DateTime start; // local start of the bucket (day/month/quarter/year)
  final Money total; // sum of sales in the bucket
  final int count; // number of sales in the bucket
  const SalesBucket({required this.start, required this.total, required this.count});
}

/// The app's gateway to stored customers and transactions.
///
/// Two implementations exist: [InMemoryLedgerRepository] (pure Dart, used in
/// tests) and the sqflite-backed store used on device. Both derive balances and
/// aging from the append-only ledger via the domain functions, so the offline
/// numbers match the server exactly.
abstract class LedgerRepository {
  Future<Customer> addCustomer({required String name, String? phone});
  Future<List<Customer>> customers();
  Future<Customer?> customer(String id);

  /// Record a credit (baki given). Append-only.
  Future<TxnEntry> recordCredit({
    required String customerId,
    required Money amount,
    DateTime? dueDate,
    String? note,
    DateTime? at,
  });

  /// Record a payment (money received). Append-only.
  Future<TxnEntry> recordPayment({
    required String customerId,
    required Money amount,
    String? note,
    DateTime? at,
  });

  /// A customer's ledger, newest first.
  Future<List<TxnEntry>> transactionsOf(String customerId);

  Future<Money> balanceOf(String customerId);
  Future<Aging> agingOf(String customerId, {required DateTime today});

  /// Home list: every customer with a balance, biggest owed first.
  Future<List<CustomerBalance>> customersWithBalances();

  /// Home headline: total owed to the merchant (positive balances only).
  Future<Money> totalReceivable();

  // ---- sales (direct, not tied to a customer) ----

  /// Record a sale — an amount (and optional note) the owner enters after a
  /// sale. Not linked to any customer.
  Future<Sale> addSale({required Money amount, String? note, DateTime? at});

  /// A sale's ledger, newest first.
  Future<List<Sale>> sales();

  /// Total sales made today (the merchant's local date) — the Home headline.
  Future<Money> todaysSales();

  /// Total of all recorded sales (all-time).
  Future<Money> totalSales();

  /// Sales grouped into buckets of [period] (day/month/quarter/year), newest
  /// first — powers the sales report.
  Future<List<SalesBucket>> salesBuckets(SalesPeriod period);

  // ---- collections (spec §8.8/§8.9) ----

  Future<CollectionActivity> addCollectionActivity({
    required String customerId,
    required ContactMethod method,
    required CollectionStatus status,
    String? note,
    DateTime? nextFollowUp,
    DateTime? at,
  });

  /// A customer's collection activity, newest first.
  Future<List<CollectionActivity>> collectionActivitiesOf(String customerId);

  Future<PromiseToPay> addPromise({
    required String customerId,
    required Money amount,
    required DateTime promiseDate,
    DateTime? followUpDate,
    String? note,
    DateTime? at,
  });

  /// A customer's promises, newest first.
  Future<List<PromiseToPay>> promisesOf(String customerId);
}
