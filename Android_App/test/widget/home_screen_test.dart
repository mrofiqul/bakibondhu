import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:bakibondhu/data/auth_api.dart';
import 'package:bakibondhu/data/in_memory_ledger_repository.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/data/session.dart';
import 'package:bakibondhu/data/settings_store.dart';
import 'package:bakibondhu/domain/money.dart';
import 'package:bakibondhu/features/dashboard/home_screen.dart';
import 'package:bakibondhu/sync/sync_store.dart';

/// Widget tests for the Home screen. Run with `flutter test` (needs the Flutter
/// SDK; the pure-Dart harness can't render widgets).
Widget _app(LedgerRepository repo) => AppScope(
      repo: repo,
      settings: InMemorySettingsStore(),
      syncStore: InMemorySyncStore(const []),
      session: Session(const FlutterSecureStorage()),
      authApi: AuthApi(baseUrl: Uri.parse('http://localhost')),
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  testWidgets('empty state prompts to add the first customer', (tester) async {
    await tester.pumpWidget(_app(InMemoryLedgerRepository()));
    await tester.pumpAndSettle();

    expect(find.text(S.emptyTitle), findsOneWidget);
    expect(find.text(S.newCustomer), findsOneWidget); // the FAB label
  });

  testWidgets('shows the total and a customer once data exists', (tester) async {
    final repo = InMemoryLedgerRepository();
    final k = await repo.addCustomer(name: 'করিম স্টোর', phone: '01712345678');
    await repo.recordCredit(customerId: k.id, amount: Money.taka(45000));

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('করিম স্টোর'), findsOneWidget);
    // ৳45,000 appears in both the total card and the customer row.
    expect(find.textContaining('৳45,000'), findsWidgets);
  });

  testWidgets('search filters the customer list by name and mobile', (tester) async {
    final repo = InMemoryLedgerRepository();
    await repo.addCustomer(name: 'করিম স্টোর', phone: '01712345678');
    await repo.addCustomer(name: 'রহিম', phone: '01899990000');

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('করিম স্টোর'), findsOneWidget);
    expect(find.text('রহিম'), findsOneWidget);

    // Filter by name → only করিম remains.
    await tester.enterText(find.byType(TextField), 'করিম');
    await tester.pumpAndSettle();
    expect(find.text('করিম স্টোর'), findsOneWidget);
    expect(find.text('রহিম'), findsNothing);

    // Filter by mobile → only রহিম matches.
    await tester.enterText(find.byType(TextField), '0189');
    await tester.pumpAndSettle();
    expect(find.text('রহিম'), findsOneWidget);
    expect(find.text('করিম স্টোর'), findsNothing);

    // No match → the no-results message shows.
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(S.noSearchResults('zzz')), findsOneWidget);
  });
}
