import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/core/bd_geo.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/features/auth/login_screen.dart';

/// Widget tests for the cascading zila → thana dropdowns on the register form.
/// The build() of LoginScreen is pure (AppScope is only touched on submit), so
/// a bare MaterialApp is enough. Run with `flutter test`.
void main() {
  group('bd_geo data', () {
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

  Finder zilaField() => find.byType(DropdownButtonFormField<String>).at(0);
  Finder thanaField() => find.byType(DropdownButtonFormField<String>).at(1);

  Future<void> openAndPick(WidgetTester tester, Finder field, String option) async {
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('zila is shown before thana', (tester) async {
    await pumpRegister(tester);
    // Both dropdowns exist, and the zila field sits above the thana field.
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(tester.getTopLeft(zilaField()).dy,
        lessThan(tester.getTopLeft(thanaField()).dy));
  });

  testWidgets('thana is disabled until a zila is chosen', (tester) async {
    await pumpRegister(tester);
    // The "pick a district first" helper is shown up front.
    expect(find.text(S.selectZilaFirst), findsOneWidget);

    // Pick the first district; the helper disappears (thana now enabled).
    await openAndPick(tester, zilaField(), kBdZilas.first);
    expect(find.text(S.selectZilaFirst), findsNothing);
  });

  testWidgets('thana options come from the selected zila', (tester) async {
    await pumpRegister(tester);

    final zila1 = kBdZilas.first;
    final thana1 = kBdThanasByZila[zila1]!.first;
    await openAndPick(tester, zilaField(), zila1);
    await openAndPick(tester, thanaField(), thana1);
    // The chosen thana is now displayed on the (closed) thana field.
    expect(find.text(thana1), findsOneWidget);
  });

  testWidgets('changing zila resets the thana selection', (tester) async {
    await pumpRegister(tester);

    final zila1 = kBdZilas.first;
    final thana1 = kBdThanasByZila[zila1]!.first;
    await openAndPick(tester, zilaField(), zila1);
    await openAndPick(tester, thanaField(), thana1);
    expect(find.text(thana1), findsOneWidget);

    // Switch to a different zila whose thana list does NOT contain thana1.
    final zila2 = kBdZilas.firstWhere(
        (z) => z != zila1 && !kBdThanasByZila[z]!.contains(thana1));
    await openAndPick(tester, zilaField(), zila2);

    // Old thana is cleared and no longer displayed.
    expect(find.text(thana1), findsNothing);
    // The thana dropdown now offers the new zila's options.
    final thana2 = kBdThanasByZila[zila2]!.first;
    await tester.tap(thanaField());
    await tester.pumpAndSettle();
    expect(find.text(thana2), findsWidgets);
  });
}
