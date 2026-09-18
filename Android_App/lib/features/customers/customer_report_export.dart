import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/xlsx_writer.dart';
import 'package:bakibondhu/data/ledger_repository.dart';

const _downloadsChannel = MethodChannel('bakibondhu/downloads');
const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Builds an `.xlsx` report of every customer of this shop (name, mobile,
/// address, outstanding due, status) and **downloads** it.
///
/// By default it saves straight to the public **Downloads** folder (via
/// MediaStore). Pass [chooseLocation] — or when the direct save isn't available
/// (e.g. older Android) — to open the system "Save to…" picker so the owner can
/// choose any folder. Returns the saved path/location, or null if the user
/// cancelled the picker.
Future<String?> downloadCustomerReport({
  required List<CustomerBalance> rows,
  required String shopName,
  bool chooseLocation = false,
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

  final base = 'bakibondhu-customers-${_stamp(now)}';

  if (!chooseLocation) {
    // Default: straight to the public Downloads folder (MediaStore).
    try {
      final saved = await _downloadsChannel.invokeMethod<String>(
        'saveToDownloads',
        {'name': '$base.xlsx', 'bytes': bytes, 'mime': _xlsxMime},
      );
      if (saved != null) return saved;
    } catch (_) {
      // Falls through to the picker (e.g. older Android or a save error).
    }
  }

  // "Save to…" picker — the user chooses the folder.
  return FileSaver.instance.saveAs(
    name: base,
    bytes: bytes,
    ext: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

/// Paisa -> taka as a real number (2 dp) so Excel can total the column.
num _taka(int paisa) => (paisa / 100 * 100).round() / 100;

String _dmy(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _stamp(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
