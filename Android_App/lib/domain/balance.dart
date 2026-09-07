import 'models.dart';
import 'money.dart';

/// Balance rules — the single source of truth for what a customer owes.
///
/// Mirrors the DB view `customer_balances`: balances are always COMPUTED from
/// the transaction log, never stored. Positive = the customer owes the shop.

/// `balance = Σ amount × balance_sign` over one customer's transactions.
Money customerBalance(Iterable<TxnEntry> txns) {
  var total = Money.zero;
  for (final t in txns) {
    total = t.type.isIncreasing ? total + t.amount : total - t.amount;
  }
  return total;
}

/// Total credit given to a customer (sum of `credit` entries).
Money totalCredit(Iterable<TxnEntry> txns) => _sumWhere(txns, TxnType.credit);

/// Total received from a customer (sum of `payment` entries).
Money totalPaid(Iterable<TxnEntry> txns) => _sumWhere(txns, TxnType.payment);

/// The Home headline — total owed to the merchant across everyone.
///
/// Sums only POSITIVE customer balances; a customer's advance (negative balance)
/// does not reduce what the whole market owes you (DB rule DM-4).
Money totalOwed(Iterable<Money> customerBalances) {
  var total = Money.zero;
  for (final b in customerBalances) {
    if (b.isPositive) total = total + b;
  }
  return total;
}

Money _sumWhere(Iterable<TxnEntry> txns, TxnType type) {
  var total = Money.zero;
  for (final t in txns) {
    if (t.type == type) total = total + t.amount;
  }
  return total;
}
