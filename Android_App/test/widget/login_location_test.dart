import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/core/bd_geo.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/features/auth/login_screen.dart';

/// Widget tests for the cascading bivag → zila → thana dropdowns on the register
/// form. The build() of LoginScreen is pure (AppScope is only touched on submit),
/// so a bare MaterialApp is enough. Run with `flutter test`.
void main() {
  group('bd_geo data', () {
    test('8 bivags cover all 64 zilas exactly once', () {
      expect(kBdBivags.length, 8);
      final seen = <String>[];
      for (final b in kBdBivags) {
        final zilas = kBdZilasByBivag[b];
        expect(zilas, isNotNull, reason: 'no zila list for $b');
        expect(zilas!, isNotEmpty, reason: '$b has no zilas');
        seen.addAll(zilas);
      }
      expect(seen.length, 64);
      expect(seen.toSet().length, 64, reason: 'a zila is listed under two bivags');
      expect(seen.toSet(), kBdZilas.toSet());
    });

    test('all 64 zilas each have at least one thana, with no duplicates', () {
      expect(kBdZilas.length, 64);
      for (final z in kBdZilas) {
        final thanas = kBdThanasByZila[z];
        expect(thanas, isNotNull, reason: 'no thana list for $z');
        expect(thanas!, isNotEmpty, reason: '$z has no thanas');
        expect(thanas.toSet().length, thanas.length, reason: '$z has duplicate thanas');
      }
    });

    test('metropolitan-city thanas are present under their districts', () {
      expect(kBdThanasByZila['ঢাকা'], containsAll(<String>['মিরপুর', 'গুলশান', 'ধানমন্ডি', 'উত্তরা পূর্ব']));
      expect(kBdThanasByZila['চট্টগ্রাম'], containsAll(<String>['পাঁচলাইশ', 'হালিশহর']));
      expect(kBdThanasByZila['খুলনা'], contains('খালিশপুর'));
      expect(kBdThanasByZila['রাজশাহী'], contains('বোয়ালিয়া'));
      expect(kBdThanasByZila['সিলেট'], contains('দক্ষিণ সুরমা'));
      expect(kBdThanasByZila['বরিশাল'], contains('কাউনিয়া'));
    });
  });

  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LoginScreen(startInRegister: true),
    ));
    await tester.pumpAndSettle();
  }

  Finder bivagField() => find.byType(DropdownButtonFormField<String>).at(0);
  Finder zilaField() => find.byType(DropdownButtonFormField<String>).at(1);
  Finder thanaField() => find.byType(DropdownButtonFormField<String>).at(2);

  Future<void> openAndPick(WidgetTester tester, Finder field, String option) async {
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('bivag, then zila, then thana — in that vertical order', (tester) async {
    await pumpRegister(tester);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(tester.getTopLeft(bivagField()).dy, lessThan(tester.getTopLeft(zilaField()).dy));
    expect(tester.getTopLeft(zilaField()).dy, lessThan(tester.getTopLeft(thanaField()).dy));
  });

  testWidgets('zila is disabled until a bivag is chosen', (tester) async {
    await pumpRegister(tester);
    expect(find.text(S.selectBivagFirst), findsOneWidget); // helper under zila

    await openAndPick(tester, bivagField(), kBdBivags.first);
    expect(find.text(S.selectBivagFirst), findsNothing);
  });

  testWidgets('thana is disabled until a zila is chosen', (tester) async {
    await pumpRegister(tester);
    await openAndPick(tester, bivagField(), kBdBivags.first);
    // Bivag chosen but zila not yet → thana still shows its "pick a zila" helper.
    expect(find.text(S.selectZilaFirst), findsOneWidget);

    await openAndPick(tester, zilaField(), kBdZilasByBivag[kBdBivags.first]!.first);
    expect(find.text(S.selectZilaFirst), findsNothing);
  });

  testWidgets('zila options come from the bivag; thana from the zila', (tester) async {
    await pumpRegister(tester);

    final bivag = kBdBivags.first;
    final zila = kBdZilasByBivag[bivag]!.first;
    final thana = kBdThanasByZila[zila]!.first;

    await openAndPick(tester, bivagField(), bivag);
    await openAndPick(tester, zilaField(), zila);
    expect(find.text(zila), findsOneWidget); // shown on the closed zila field
    await openAndPick(tester, thanaField(), thana);
    expect(find.text(thana), findsOneWidget);
  });

  testWidgets('changing bivag resets zila and thana', (tester) async {
    await pumpRegister(tester);

    final bivag1 = kBdBivags.first;
    final zila1 = kBdZilasByBivag[bivag1]!.first;
    final thana1 = kBdThanasByZila[zila1]!.first;
    await openAndPick(tester, bivagField(), bivag1);
    await openAndPick(tester, zilaField(), zila1);
    await openAndPick(tester, thanaField(), thana1);
    expect(find.text(zila1), findsOneWidget);
    expect(find.text(thana1), findsOneWidget);

    // Switch to a bivag whose zila list does NOT contain zila1.
    final bivag2 = kBdBivags.firstWhere(
        (b) => b != bivag1 && !kBdZilasByBivag[b]!.contains(zila1));
    await openAndPick(tester, bivagField(), bivag2);

    // Old zila and thana are cleared.
    expect(find.text(zila1), findsNothing);
    expect(find.text(thana1), findsNothing);
    // The zila dropdown now offers the new bivag's districts.
    final zila2 = kBdZilasByBivag[bivag2]!.first;
    await tester.tap(zilaField());
    await tester.pumpAndSettle();
    expect(find.text(zila2), findsWidgets);
  });
}
