import 'package:bakibondhu/core/strings_bn.dart';

/// Form validators and normalisers shared across screens.

/// Bangladesh mobile: 11 digits, `01` + operator digit (3–9) + 8 digits,
/// e.g. `01712345678`. Operators: 013–019.
final RegExp _bdMobile = RegExp(r'^01[3-9]\d{8}$');

/// Normalises a Bangladeshi mobile number to the 11-digit `01XXXXXXXXX` form:
/// strips spaces/dashes and a `+880` / `880` country prefix.
String normalizeBdMobile(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('880')) d = '0${d.substring(3)}';
  return d;
}

bool isBdMobile(String input) => _bdMobile.hasMatch(normalizeBdMobile(input));

/// Validator for a required Bangladeshi mobile number field.
/// Returns null when valid, or a Bangla error string.
String? bdMobileValidator(String? v, {bool required = true}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return required ? S.mobileRequired : null;
  return isBdMobile(s) ? null : S.invalidMobile;
}
