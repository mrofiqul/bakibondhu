import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/money.dart';

/// Small display helpers shared across screens.

/// A short date like `৬/৯` (day/month). Full localized dates come with the
/// Add-transaction screen; this keeps history rows compact for now.
String shortDate(DateTime d) => '${d.day}/${d.month}';

/// How to describe a customer's balance in Bangla.
/// Positive = they owe; negative = they hold an advance; zero = settled.
String balanceLabel(Money balance) {
  if (balance.isZero) return S.settled;
  if (balance.isNegative) return '${S.advance} ${Money(-balance.paisa).format()}';
  return '${balance.format()} $_baki';
}

const String _baki = 'বাকি';
