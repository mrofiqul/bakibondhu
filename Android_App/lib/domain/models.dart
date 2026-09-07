import 'money.dart';

/// How a transaction type affects a customer's receivable balance.
///
/// The **sign**, not a stored negative amount, decides direction — matching the
/// DB rule `amount >= 0` with `balance_sign` on `transaction_types`.
enum TxnType {
  /// Baki given — বাকি দিলাম. Increases what the customer owes (+1).
  credit,

  /// Money received — টাকা পেলাম. Decreases what the customer owes (-1).
  payment,

  /// Correction that increases the receivable (+1).
  adjustmentDebit,

  /// Correction / reversal that decreases the receivable (-1).
  adjustmentCredit,
}

extension TxnTypeX on TxnType {
  /// +1 increases what is owed, -1 decreases it.
  int get balanceSign {
    switch (this) {
      case TxnType.credit:
      case TxnType.adjustmentDebit:
        return 1;
      case TxnType.payment:
      case TxnType.adjustmentCredit:
        return -1;
    }
  }

  /// A "debit leg" that can be settled (credit, adjustment_debit).
  bool get isIncreasing => balanceSign == 1;

  /// A "credit leg" that settles debits (payment, adjustment_credit).
  bool get isReducing => balanceSign == -1;
}

/// A customer (party) the merchant extends credit to.
class Customer {
  final String id;
  final String name;
  final String? phone;

  const Customer({required this.id, required this.name, this.phone});
}

/// One append-only ledger entry. Never edited or deleted; a mistake is fixed by
/// adding a reversing entry (see [reversalOfId]).
class TxnEntry {
  final String id;
  final String customerId;
  final TxnType type;

  /// Always >= 0; direction comes from [type].
  final Money amount;

  /// Due date for credits (used by aging). Null for payments / undated credits.
  final DateTime? dueDate;

  /// When the entry was recorded (drives ordering of payments).
  final DateTime createdAt;

  /// When set, this entry reverses the transaction with this id. Both the
  /// original and this reversal are excluded from balances-aging attribution.
  final String? reversalOfId;

  const TxnEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.dueDate,
    this.reversalOfId,
  });
}
