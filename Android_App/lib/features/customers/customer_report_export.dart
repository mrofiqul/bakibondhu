import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/xlsx_writer.dart';
import 'package:bakibondhu/data/ledger_repository.dart';

/// Builds an `.xlsx` report of every customer of this shop (name, mobile,
/// address, outstanding due, status) and hands it to the OS share sheet, so the
/// owner can save it / send it to Excel, Drive, email, WhatsApp, etc.
Future<void> exportCustomerReport({
  required List<CustomerBalance> rows,
  required String shopName,
}) async {
  final title = shopName.trim().isEmpty ? S.appName : shopName.trim();
  final now = DateTime.now();

  final data = <List<Object?>>[
    [title],
    [S.customerReportTitle, 'তারিখ: ${_dmy(now)}'],
    <Object?>[],
    ['ক্রমিক', 'নাম', 'মোবাইল', 'ঠিকানা', 'বাকি (৳)', 'স্ট্যাটাস'],
  ];

  final sorted = [...rows]..sort((a, b) => b.balance.paisa.compareTo(a.balance.paisa));
  var totalDue = 0;
  var i = 0;
  for (final r in sorted) {
    i++;
    final p = r.balance.paisa;
    if (p > 0) totalDue += p;
    data.add([
      i,
      r.customer.name,
      r.customer.phone ?? '',
      r.customer.address ?? '',
      _taka(p),
      p > 0 ? 'বাকি' : (p < 0 ? 'জমা' : 'পরিশোধিত'),
    ]);
  }
  data.add(<Object?>[]);
  data.add(['', '', '', 'মোট বাকি (৳):', _taka(totalDue), '${sorted.length} জন']);

  final bytes = buildXlsx([
    XlsxSheet('কাস্টমার', data, cols: const [7, 24, 15, 22, 13, 11]),
  ]);

  final dir = await getTemporaryDirectory();
  final fname = 'bakibondhu-customers-${_stamp(now)}.xlsx';
  final file = File('${dir.path}/$fname');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [
      XFile(
        file.path,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: fname,
      )
    ],
    subject: '$title — ${S.customerReportTitle}',
  );
}

/// Paisa -> taka as a real number (2 dp) so Excel can total the column.
num _taka(int paisa) => (paisa / 100 * 100).round() / 100;

String _dmy(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _stamp(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
