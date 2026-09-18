import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A minimal, dependency-free `.xlsx` (Office Open XML) writer.
///
/// An `.xlsx` is just a ZIP of XML parts. We build the parts as strings and
/// pack them into a DEFLATE zip using `dart:io`'s [ZLibCodec] (raw deflate) and
/// a small CRC-32 — so no extra package is added to the APK. Cell values are
/// written as numbers or inline strings (no shared-strings table needed), and
/// everything is UTF-8, so Bangla text round-trips. This mirrors the server's
/// `php_backend/xlsx.php` byte-for-byte in structure.

class XlsxSheet {
  final String name;

  /// Rows of cells. A cell is [num] (number), [String] (inline text), or
  /// null/'' (blank).
  final List<List<Object?>> rows;

  /// Optional per-column widths (in characters).
  final List<double>? cols;

  const XlsxSheet(this.name, this.rows, {this.cols});
}

/// Builds the complete `.xlsx` file bytes from [sheets].
Uint8List buildXlsx(List<XlsxSheet> sheets) {
  if (sheets.isEmpty) sheets = const [XlsxSheet('Sheet1', [])];
  final used = <String>{};
  final names = sheets.map((s) => _sheetName(s.name, used)).toList();
  final n = sheets.length;

  final files = <String, List<int>>{};

  final ct = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
    ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
    ..write('<Default Extension="xml" ContentType="application/xml"/>')
    ..write('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>');
  for (var i = 1; i <= n; i++) {
    ct.write('<Override PartName="/xl/worksheets/sheet$i.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
  }
  ct.write('</Types>');
  files['[Content_Types].xml'] = utf8.encode(ct.toString());

  files['_rels/.rels'] = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>');

  final wb = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>');
  final rels = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
  for (var i = 1; i <= n; i++) {
    wb.write('<sheet name="${_esc(names[i - 1])}" sheetId="$i" r:id="rId$i"/>');
    rels.write('<Relationship Id="rId$i" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet$i.xml"/>');
    files['xl/worksheets/sheet$i.xml'] = utf8.encode(_sheetXml(sheets[i - 1]));
  }
  wb.write('</sheets></workbook>');
  rels.write('</Relationships>');
  files['xl/workbook.xml'] = utf8.encode(wb.toString());
  files['xl/_rels/workbook.xml.rels'] = utf8.encode(rels.toString());

  return _zip(files);
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// 0-based column index -> A, B, ..., Z, AA, ...
String _col(int i) {
  var s = '';
  i++;
  while (i > 0) {
    final m = (i - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    i = (i - 1) ~/ 26;
  }
  return s;
}

String _sheetName(String name, Set<String> used) {
  var n = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  if (n.isEmpty) n = 'Sheet';
  if (n.length > 31) n = n.substring(0, 31);
  final base = n;
  var i = 2;
  while (used.contains(n.toLowerCase())) {
    final suffix = ' $i';
    i++;
    final keep = (31 - suffix.length).clamp(0, base.length);
    n = base.substring(0, keep) + suffix;
  }
  used.add(n.toLowerCase());
  return n;
}

String _sheetXml(XlsxSheet s) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  final cols = s.cols;
  if (cols != null && cols.isNotEmpty) {
    b.write('<cols>');
    for (var i = 0; i < cols.length; i++) {
      b.write('<col min="${i + 1}" max="${i + 1}" width="${cols[i]}" customWidth="1"/>');
    }
    b.write('</cols>');
  }
  b.write('<sheetData>');
  for (var r = 0; r < s.rows.length; r++) {
    b.write('<row r="${r + 1}">');
    final row = s.rows[r];
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      if (v == null || v == '') continue;
      final ref = '${_col(c)}${r + 1}';
      if (v is num) {
        b.write('<c r="$ref"><v>$v</v></c>');
      } else {
        b.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc(v.toString())}</t></is></c>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

// ---- zip container ----------------------------------------------------------

final ZLibCodec _deflate = ZLibCodec(raw: true, level: 6);

Uint8List _zip(Map<String, List<int>> files) {
  final local = BytesBuilder();
  final central = BytesBuilder();
  var offset = 0;
  var count = 0;

  files.forEach((name, content) {
    final nameBytes = utf8.encode(name);
    final crc = _crc32(content);
    final ulen = content.length;
    final comp = _deflate.encode(content);
    final clen = comp.length;
    const method = 8; // deflate

    final lh = BytesBuilder();
    lh.add(const [0x50, 0x4b, 0x03, 0x04]);
    _u16(lh, 20);
    _u16(lh, 0);
    _u16(lh, method);
    _u16(lh, 0);
    _u16(lh, 0);
    _u32(lh, crc);
    _u32(lh, clen);
    _u32(lh, ulen);
    _u16(lh, nameBytes.length);
    _u16(lh, 0);
    lh.add(nameBytes);
    final lhBytes = lh.toBytes();
    local.add(lhBytes);
    local.add(comp);

    central.add(const [0x50, 0x4b, 0x01, 0x02]);
    _u16(central, 20);
    _u16(central, 20);
    _u16(central, 0);
    _u16(central, method);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, crc);
    _u32(central, clen);
    _u32(central, ulen);
    _u16(central, nameBytes.length);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, 0);
    _u32(central, offset);
    central.add(nameBytes);

    offset += lhBytes.length + clen;
    count++;
  });

  final out = BytesBuilder();
  out.add(local.toBytes());
  final centralBytes = central.toBytes();
  out.add(centralBytes);
  out.add(const [0x50, 0x4b, 0x05, 0x06]);
  _u16(out, 0);
  _u16(out, 0);
  _u16(out, count);
  _u16(out, count);
  _u32(out, centralBytes.length);
  _u32(out, offset);
  _u16(out, 0);
  return out.toBytes();
}

void _u16(BytesBuilder b, int v) => b.add([v & 0xff, (v >> 8) & 0xff]);
void _u32(BytesBuilder b, int v) =>
    b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : (crc >> 1);
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
