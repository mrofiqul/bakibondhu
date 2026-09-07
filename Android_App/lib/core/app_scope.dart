import 'package:flutter/widgets.dart';

import 'package:bakibondhu/data/ledger_repository.dart';

/// Makes the [LedgerRepository] available to any widget below it —
/// `AppScope.of(context)` — so screens don't construct their own storage.
class AppScope extends InheritedWidget {
  final LedgerRepository repo;

  const AppScope({required this.repo, required super.child, super.key});

  static LedgerRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!.repo;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.repo != repo;
}
