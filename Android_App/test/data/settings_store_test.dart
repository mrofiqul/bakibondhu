import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/data/settings_store.dart';

void main() {
  test('in-memory settings: defaults, set, and clear', () async {
    final s = InMemorySettingsStore();
    expect(await s.onboardingComplete(), isFalse);
    expect(await s.shopName(), isNull);

    await s.setShopName('করিম স্টোর');
    await s.setOnboardingComplete(true);
    expect(await s.shopName(), 'করিম স্টোর');
    expect(await s.onboardingComplete(), isTrue);

    await s.setShopName(''); // empty clears
    expect(await s.shopName(), isNull);
  });
}
