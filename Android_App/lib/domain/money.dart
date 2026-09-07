/// Money for BakiBondhu.
///
/// Stored as an integer number of **paisa** (1 taka = 100 paisa) so we never
/// use floating-point for money — matching the spec rule that money is a fixed
/// decimal (DB `NUMERIC(14,2)`, API strings). All arithmetic stays exact.
class Money implements Comparable<Money> {
  /// The amount in paisa. May be negative (e.g. a customer advance/overpayment).
  final int paisa;

  const Money(this.paisa);

  /// Build from a taka amount, e.g. `Money.taka(45000)` or `Money.taka(12.50)`.
  factory Money.taka(num taka) => Money((taka * 100).round());

  static const Money zero = Money(0);

  Money operator +(Money other) => Money(paisa + other.paisa);
  Money operator -(Money other) => Money(paisa - other.paisa);

  bool operator <(Money other) => paisa < other.paisa;
  bool operator >(Money other) => paisa > other.paisa;
  bool operator <=(Money other) => paisa <= other.paisa;
  bool operator >=(Money other) => paisa >= other.paisa;

  bool get isPositive => paisa > 0;
  bool get isNegative => paisa < 0;
  bool get isZero => paisa == 0;

  /// The smaller of two amounts (used by FIFO allocation).
  static Money min(Money a, Money b) => a <= b ? a : b;

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);

  @override
  bool operator ==(Object other) => other is Money && other.paisa == paisa;

  @override
  int get hashCode => paisa.hashCode;

  /// Display like `৳1,24,500` (Bangladeshi lakh grouping), with paisa only when
  /// present, e.g. `৳45,000.50`.
  String format() {
    final whole = paisa ~/ 100;
    final frac = paisa.abs() % 100;
    final base = '৳${_groupLakh(whole)}';
    return frac == 0 ? base : '$base.${frac.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => format();

  /// Groups the integer part in the South-Asian style: last three digits, then
  /// groups of two — `124500` -> `1,24,500`.
  static String _groupLakh(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      grouped = '${parts.join(',')},$last3';
    }
    return negative ? '-$grouped' : grouped;
  }
}
