<?php
// Minimal .xlsx (Office Open XML / SpreadsheetML) writer — no PhpSpreadsheet,
// no composer, no zip extension. An .xlsx is a ZIP of XML parts; we build the
// parts as strings and pack them with a hand-rolled DEFLATE zip using the
// built-in crc32() + gzdeflate(). Values are written as numbers or inline
// strings (so no sharedStrings table is needed). UTF-8 throughout, so Bangla
// text round-trips.

/** 0-based column index -> spreadsheet column letters (0->A, 26->AA). */
function bb_xlsx_col(int $i): string
{
    $s = '';
    $i++;
    while ($i > 0) {
        $m = ($i - 1) % 26;
        $s = chr(65 + $m) . $s;
        $i = intdiv($i - 1, 26);
    }
    return $s;
}

function bb_xlsx_esc(string $s): string
{
    // Strip control chars XML 1.0 forbids, then escape.
    $s = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', '', $s);
    return htmlspecialchars($s, ENT_QUOTES | ENT_XML1, 'UTF-8');
}

/**
 * One worksheet XML from rows of cells. A cell is int|float (number),
 * string (inline text), or null/'' (blank). $cols is an optional list of
 * column widths (chars).
 */
function bb_xlsx_sheet(array $rows, array $cols = []): string
{
    $xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
         . '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">';
    if ($cols) {
        $xml .= '<cols>';
        foreach ($cols as $i => $w) {
            $n = $i + 1;
            $xml .= '<col min="' . $n . '" max="' . $n . '" width="' . $w . '" customWidth="1"/>';
        }
        $xml .= '</cols>';
    }
    $xml .= '<sheetData>';
    $r = 0;
    foreach ($rows as $row) {
        $r++;
        $xml .= '<row r="' . $r . '">';
        $c = 0;
        foreach ($row as $val) {
            $ref = bb_xlsx_col($c) . $r;
            $c++;
            if ($val === null || $val === '') continue;
            if (is_int($val) || is_float($val)) {
                $xml .= '<c r="' . $ref . '"><v>' . $val . '</v></c>';
            } else {
                $xml .= '<c r="' . $ref . '" t="inlineStr"><is><t xml:space="preserve">'
                      . bb_xlsx_esc((string) $val) . '</t></is></c>';
            }
        }
        $xml .= '</row>';
    }
    $xml .= '</sheetData></worksheet>';
    return $xml;
}

/** Sanitize a worksheet name: <=31 chars, none of []:*?/\, non-empty, unique. */
function bb_xlsx_sheetname(string $name, array &$used): string
{
    $name = trim(preg_replace('#[\[\]\:\*\?/\\\\]#u', ' ', $name));
    if ($name === '') $name = 'Sheet';
    if (mb_strlen($name, 'UTF-8') > 31) $name = mb_substr($name, 0, 31, 'UTF-8');
    $base = $name;
    $i = 2;
    while (isset($used[mb_strtolower($name, 'UTF-8')])) {
        $suffix = ' ' . $i++;
        $name = mb_substr($base, 0, 31 - mb_strlen($suffix, 'UTF-8'), 'UTF-8') . $suffix;
    }
    $used[mb_strtolower($name, 'UTF-8')] = true;
    return $name;
}

/** Pack {path => bytes} into a DEFLATE zip (the .xlsx container). */
function bb_zip(array $files): string
{
    $local = '';
    $central = '';
    $offset = 0;
    $count = 0;
    foreach ($files as $name => $content) {
        $crc  = crc32($content);
        $ulen = strlen($content);
        $comp = gzdeflate($content, 6);
        if ($comp === false) $comp = $content; // fall back to store
        $clen = strlen($comp);
        $method = ($comp === $content && $ulen > 0) ? 0 : 8; // 0=store 8=deflate
        $nlen = strlen($name);
        $lh = "PK\x03\x04" . pack('v', 20) . pack('v', 0) . pack('v', $method)
            . pack('v', 0) . pack('v', 0)
            . pack('V', $crc) . pack('V', $clen) . pack('V', $ulen)
            . pack('v', $nlen) . pack('v', 0) . $name;
        $local .= $lh . $comp;
        $central .= "PK\x01\x02" . pack('v', 20) . pack('v', 20) . pack('v', 0) . pack('v', $method)
            . pack('v', 0) . pack('v', 0)
            . pack('V', $crc) . pack('V', $clen) . pack('V', $ulen)
            . pack('v', $nlen) . pack('v', 0) . pack('v', 0) . pack('v', 0) . pack('v', 0)
            . pack('V', 0) . pack('V', $offset) . $name;
        $offset += strlen($lh) + $clen;
        $count++;
    }
    $eocd = "PK\x05\x06" . pack('v', 0) . pack('v', 0)
          . pack('v', $count) . pack('v', $count)
          . pack('V', strlen($central)) . pack('V', $offset) . pack('v', 0);
    return $local . $central . $eocd;
}

/**
 * Build a complete .xlsx from sheets: [ ['name'=>..,'rows'=>[[..],..],'cols'=>[..]], .. ].
 * Returns the raw file bytes.
 */
function bb_xlsx_build(array $sheets): string
{
    if (!$sheets) $sheets = [['name' => 'Sheet1', 'rows' => []]];
    $used = [];
    $names = [];
    foreach ($sheets as $s) $names[] = bb_xlsx_sheetname($s['name'] ?? 'Sheet', $used);
    $n = count($sheets);

    $files = [];
    // [Content_Types].xml
    $ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        . '<Default Extension="xml" ContentType="application/xml"/>'
        . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>';
    for ($i = 1; $i <= $n; $i++) {
        $ct .= '<Override PartName="/xl/worksheets/sheet' . $i . '.xml" '
             . 'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
    }
    $ct .= '</Types>';
    $files['[Content_Types].xml'] = $ct;

    $files['_rels/.rels'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        . '</Relationships>';

    // workbook.xml + its rels
    $wb = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        . 'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>';
    $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
    for ($i = 1; $i <= $n; $i++) {
        $wb .= '<sheet name="' . bb_xlsx_esc($names[$i - 1]) . '" sheetId="' . $i . '" r:id="rId' . $i . '"/>';
        $rels .= '<Relationship Id="rId' . $i . '" '
              . 'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
              . 'Target="worksheets/sheet' . $i . '.xml"/>';
        $files['xl/worksheets/sheet' . $i . '.xml'] = bb_xlsx_sheet($sheets[$i - 1]['rows'] ?? [], $sheets[$i - 1]['cols'] ?? []);
    }
    $wb .= '</sheets></workbook>';
    $rels .= '</Relationships>';
    $files['xl/workbook.xml'] = $wb;
    $files['xl/_rels/workbook.xml.rels'] = $rels;

    return bb_zip($files);
}
