import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/money.dart';

/// Small display helpers shared across screens.

/// A short date like `৬/৯` (day/month). Full localized dates come with the
/// Add-transaction screen; this keeps history rows compact for now.
String shortDate(DateTime d) => '${d.day}/${d.month}';

const List<String> _bnMonths = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
];

/// A friendly day label for the daily sales report: "আজ" / "গতকাল" for the
/// most recent days, otherwise `12 সেপ্টেম্বর 2026`.
String dayLabel(DateTime day, {DateTime? today}) {
  final t = today ?? DateTime.now();
  final td = DateTime(t.year, t.month, t.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = td.difference(d).inDays;
  if (diff == 0) return S.today;
  if (diff == 1) return S.yesterday;
  return '${day.day} ${_bnMonths[day.month - 1]} ${day.year}';
}

/// How to describe a customer's balance in Bangla.
/// Positive = they owe; negative = they hold an advance; zero = settled.
String balanceLabel(Money balance) {
  if (balance.isZero) return S.settled;
  if (balance.isNegative) return '${S.advance} ${Money(-balance.paisa).format()}';
  return '${balance.format()} $_baki';
}

const String _baki = 'বাকি';
