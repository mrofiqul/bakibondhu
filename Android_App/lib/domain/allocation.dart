import 'models.dart';
import 'money.dart';

/// One payment (or credit-adjustment) applied to one credit, for aging.
class Allocation {
  final String paymentTxnId;
  final String creditTxnId;
  final Money amount;

  const Allocation({
    required this.paymentTxnId,
    required this.creditTxnId,
    required this.amount,
  });

  @override
  String toString() => 'Allocation($paymentTxnId -> $creditTxnId: $amount)';
}

/// FIFO payment allocation — the Dart mirror of the DB function
/// `reallocate_customer` (DB spec §13c; Offline Sync §5).
///
/// Applies a customer's reducing txns (payment, adjustment_credit) to their
/// outstanding increasing txns (credit, adjustment_debit), **oldest due first**.
/// Reversed txns and reversal entries are excluded. It is deterministic and
/// idempotent — pass the customer's full ledger and it returns the complete set
/// of allocations. Balances never depend on this; it only attributes payments to
/// credits so aging reflects UNPAID credit.
List<Allocation> reallocateCustomer(List<TxnEntry> customerTxns) {
  final active = _activeTxns(customerTxns);

  final increasing = active.where((t) => t.type.isIncreasing).toList()
    ..sort(compareByDueThenCreated);
  final reducing = active.where((t) => t.type.isReducing).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // Working "remaining" per credit.
  final remaining = <String, Money>{for (final c in increasing) c.id: c.amount};

  final result = <Allocation>[];
  for (final pay in reducing) {
    var left = pay.amount;
    for (final credit in increasing) {
      if (left <= Money.zero) break;
      final rem = remaining[credit.id]!;
      if (rem <= Money.zero) continue;
      final take = Money.min(left, rem);
      result.add(Allocation(
        paymentTxnId: pay.id,
        creditTxnId: credit.id,
        amount: take,
      ));
      remaining[credit.id] = rem - take;
      left = left - take;
    }
    // left > 0 here => unapplied advance / overpayment, intentionally unallocated.
  }
  return result;
}

/// Active = not a reversal entry and not itself reversed.
List<TxnEntry> _activeTxns(List<TxnEntry> txns) {
  final reversedIds = txns
      .where((t) => t.reversalOfId != null)
      .map((t) => t.reversalOfId!)
      .toSet();
  return txns
      .where((t) => t.reversalOfId == null && !reversedIds.contains(t.id))
      .toList();
}

/// Ordering for allocation targets: due date ascending with nulls last, then by
/// creation time, then id — the same key as the SQL `ORDER BY`.
int compareByDueThenCreated(TxnEntry a, TxnEntry b) {
  final ad = a.dueDate;
  final bd = b.dueDate;
  if (ad == null && bd != null) return 1; // nulls last
  if (ad != null && bd == null) return -1;
  if (ad != null && bd != null) {
    final c = ad.compareTo(bd);
    if (c != 0) return c;
  }
  final c = a.createdAt.compareTo(b.createdAt);
  return c != 0 ? c : a.id.compareTo(b.id);
}
