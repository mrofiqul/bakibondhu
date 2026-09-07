import 'package:bakibondhu/domain/aging.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// A customer paired with their current balance (for the Home list).
class CustomerBalance {
  final Customer customer;
  final Money balance;
  const CustomerBalance(this.customer, this.balance);
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
}
