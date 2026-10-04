import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/config.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/data/auth_api.dart';
import 'package:bakibondhu/data/in_memory_ledger_repository.dart';
import 'package:bakibondhu/data/session.dart';
import 'package:bakibondhu/data/settings_store.dart';
import 'package:bakibondhu/features/subscription/subscription_screen.dart';
import 'package:bakibondhu/sync/sync_store.dart';

/// Confirms the Subscription screen renders the yearly plan (20% off) correctly.
/// Run with `flutter test test/widget/subscription_test.dart`.
Widget _app() => AppScope(
      repo: InMemoryLedgerRepository(),
      settings: InMemorySettingsStore(),
      syncStore: InMemorySyncStore(const []),
      session: Session(const FlutterSecureStorage()),
      authApi: AuthApi(baseUrl: Uri.parse('http://localhost')),
      child: const MaterialApp(home: SubscriptionScreen()),
    );

void main() {
  setUp(() => S.lang = AppLang.bn); // assert the Bangla labels

  // The yearly figures must match the formula: 12 × monthly × (100 - 20)%.
  test('yearly constants = 12× monthly × 0.8', () {
    expect(kYearlyDiscountPct, 20);
    expect(kPriceBdtPerYear, kPriceBdtPerMonth * 12 * 80 ~/ 100); // 960
    expect(kSaveBdtPerYear, kPriceBdtPerMonth * 12 - kPriceBdtPerYear); // 240
  });

  testWidgets('Bangladesh: yearly shows ৳960, 20% off, save ৳240',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.subInsideBd)); // force Bangladesh
    await tester.pumpAndSettle();

    // Monthly first.
    expect(find.textContaining('৳$kPriceBdtPerMonth'), findsWidgets); // ৳100
    expect(find.text(S.subPerMonth), findsOneWidget); // "/ মাস"

    // Switch to Yearly.
    await tester.tap(
        find.text('${S.subYearly} · ${S.subYearlyOff(kYearlyDiscountPct)}'));
    await tester.pumpAndSettle();

    expect(find.textContaining('৳$kPriceBdtPerYear'), findsWidgets); // ৳960
    expect(find.text(S.subPerYear), findsOneWidget); // "/ বছর"
    expect(find.textContaining(S.subYearlyOff(kYearlyDiscountPct)),
        findsWidgets); // ২০% ছাড়
    expect(find.text(S.subSaveYear('৳$kSaveBdtPerYear')),
        findsOneWidget); // বছরে ৳240 সাশ্রয়
  });

  testWidgets('Outside Bangladesh: yearly shows \$11.52, save \$2.88',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.subOutsideBd)); // force outside BD
    await tester.pumpAndSettle();
    await tester.tap(
        find.text('${S.subYearly} · ${S.subYearlyOff(kYearlyDiscountPct)}'));
    await tester.pumpAndSettle();

    expect(find.textContaining('\$$kPriceUsdPerYear'), findsWidgets); // $11.52
    expect(find.text(S.subSaveYear('\$$kSaveUsdPerYear')),
        findsOneWidget); // বছরে $2.88 সাশ্রয়
  });
}
