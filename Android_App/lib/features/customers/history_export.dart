import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// Builds a plain-text Bangla statement of a customer's transaction history,
/// suitable for copying or sharing (WhatsApp, email, save-to-file, …).
///
/// [history] is newest-first (as the detail screen holds it); the statement
/// lists oldest-first with a running balance so it reads like a passbook.
String buildHistoryStatement({
  required Customer customer,
  required List<TxnEntry> history,
  required Money balance,
  required String shopName,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final b = StringBuffer();

  b.writeln('${S.appName} · ${S.historyExportTitle}');
  b.writeln('${S.shopLabel}: $shopName');
  final phone = customer.phone;
  b.writeln('${S.customerLabel}: ${customer.name}'
      '${(phone != null && phone.isNotEmpty) ? ' · $phone' : ''}');
  b.writeln('${S.dateLabel}: ${_fullDate(today)}');
  b.writeln(_rule);

  if (history.isEmpty) {
    b.writeln(S.noHistory);
  } else {
    final oldestFirst = history.reversed.toList();
    var running = 0;
    for (final t in oldestFirst) {
      running += t.type.balanceSign * t.amount.paisa;
      final sign = t.type.isIncreasing ? '+' : '−';
      b.writeln('${_fullDate(t.createdAt)}  ·  ${_typeLabel(t.type)}'
          '  ·  $sign${t.amount.format()}');
      if (t.note != null && t.note!.isNotEmpty) {
        b.writeln('   • ${t.note}');
      }
      b.writeln('   ${S.runningDue}: ${balanceLabel(Money(running))}');
    }
  }

  b.writeln(_rule);
  b.writeln('${S.totalTransactions}: ${history.length}');
  b.writeln('${S.currentBalanceLabel}: ${balanceLabel(balance)}');
  b.writeln();
  b.writeln(S.madeWithApp);
  return b.toString().trimRight();
}

const String _rule = '────────────────────';

String _fullDate(DateTime d) => '${d.day} ${bnMonth(d.month)} ${d.year}';

String _typeLabel(TxnType t) => switch (t) {
      TxnType.credit => S.gaveCredit,
      TxnType.payment => S.gotPayment,
      TxnType.adjustmentDebit => S.adjustmentUp,
      TxnType.adjustmentCredit => S.adjustmentDown,
    };
