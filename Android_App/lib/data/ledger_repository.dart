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

/// One day's sales total (credit given), for the daily sales report.
class DailySales {
  final DateTime day; // local date at midnight
  final Money total; // sum of credit given that day
  final int count; // number of credit entries that day
  const DailySales({required this.day, required this.total, required this.count});
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

  /// Total sales = the value of all goods given on credit (all-time). Payments
  /// and adjustments are not sales; only `credit` entries count.
  Future<Money> totalSales();

  /// Sales made today (the merchant's local date) — the Home headline figure.
  Future<Money> todaysSales();

  /// Sales grouped by local calendar day, newest day first (daily sales report).
  Future<List<DailySales>> dailySales();

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
