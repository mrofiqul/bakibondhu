import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/core/validators.dart';

void main() {
  test('Bangladesh mobile: accepts valid, normalises country code', () {
    expect(isBdMobile('01712345678'), true);
    expect(isBdMobile('01312345678'), true);
    expect(isBdMobile('01912345678'), true);
    expect(isBdMobile('+8801712345678'), true);
    expect(isBdMobile('8801712345678'), true);
    expect(isBdMobile('017 1234 5678'), true); // spaces/dashes stripped
    expect(normalizeBdMobile('+880 17-1234-5678'), '01712345678');
  });

  test('Bangladesh mobile: rejects invalid', () {
    expect(isBdMobile('01212345678'), false); // 012 not a valid operator
    expect(isBdMobile('0171234567'), false); // 10 digits (too short)
    expect(isBdMobile('017123456789'), false); // 12 digits (too long)
    expect(isBdMobile('1712345678'), false); // missing leading 0
    expect(isBdMobile('abcd'), false);
  });

  test('bdMobileValidator: required vs optional', () {
    expect(bdMobileValidator(''), isNotNull); // required by default
    expect(bdMobileValidator('   '), isNotNull);
    expect(bdMobileValidator('01712345678'), isNull);
    expect(bdMobileValidator('0123'), isNotNull); // invalid
    expect(bdMobileValidator('', required: false), isNull); // optional empty ok
  });
}
