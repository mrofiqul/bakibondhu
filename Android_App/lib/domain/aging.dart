import 'allocation.dart';
import 'models.dart';
import 'money.dart';

/// Aging buckets for one customer (days overdue on UNPAID credit).
///
/// Mirrors the DB view `customer_aging` (as corrected in the spec review): it
/// ages the unpaid portion of each credit, using FIFO allocation, so the buckets
/// reconcile with the customer's balance.
class Aging {
  final Money bucket0to7;
  final Money bucket8to30;
  final Money bucket31to60;
  final Money bucket61to90;
  final Money bucket90plus;

  const Aging({
    this.bucket0to7 = Money.zero,
    this.bucket8to30 = Money.zero,
    this.bucket31to60 = Money.zero,
    this.bucket61to90 = Money.zero,
    this.bucket90plus = Money.zero,
  });

  Money get total =>
      bucket0to7 + bucket8to30 + bucket31to60 + bucket61to90 + bucket90plus;
}

/// Computes aging for one customer as of [today].
///
/// [today] should be "today" in the business timezone (Asia/Dhaka) — the caller
/// supplies it so the calculation is deterministic and testable. Credits with no
/// due date, and not-yet-due credits, are excluded (they don't age).
Aging customerAging(List<TxnEntry> customerTxns, {required DateTime today}) {
  final allocations = reallocateCustomer(customerTxns);

  // How much has been allocated (paid off) against each credit.
  final allocatedByCredit = <String, Money>{};
  for (final a in allocations) {
    allocatedByCredit[a.creditTxnId] =
        (allocatedByCredit[a.creditTxnId] ?? Money.zero) + a.amount;
  }

  final reversedIds = customerTxns
      .where((t) => t.reversalOfId != null)
      .map((t) => t.reversalOfId!)
      .toSet();
  bool isActive(TxnEntry t) =>
      t.reversalOfId == null && !reversedIds.contains(t.id);

  var b0 = Money.zero,
      b8 = Money.zero,
      b31 = Money.zero,
      b61 = Money.zero,
      b90 = Money.zero;

  for (final c in customerTxns) {
    if (!isActive(c) || !c.type.isIncreasing || c.dueDate == null) continue;
    final outstanding = c.amount - (allocatedByCredit[c.id] ?? Money.zero);
    if (!outstanding.isPositive) continue;

    final days = _daysBetween(c.dueDate!, today);
    if (days < 0) continue; // not yet due
    if (days <= 7) {
      b0 = b0 + outstanding;
    } else if (days <= 30) {
      b8 = b8 + outstanding;
    } else if (days <= 60) {
      b31 = b31 + outstanding;
    } else if (days <= 90) {
      b61 = b61 + outstanding;
    } else {
      b90 = b90 + outstanding;
    }
  }

  return Aging(
    bucket0to7: b0,
    bucket8to30: b8,
    bucket31to60: b31,
    bucket61to90: b61,
    bucket90plus: b90,
  );
}

/// Whole days from [from] to [to], counting calendar dates only.
int _daysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
