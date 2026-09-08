import 'package:flutter/widgets.dart';

import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/data/settings_store.dart';

/// Makes the [LedgerRepository] and [SettingsStore] available to any widget
/// below — `AppScope.of(context)` for the repo, `AppScope.settingsOf(context)`
/// for settings — so screens don't construct their own storage.
class AppScope extends InheritedWidget {
  final LedgerRepository repo;
  final SettingsStore settings;

  const AppScope({
    required this.repo,
    required this.settings,
    required super.child,
    super.key,
  });

  static AppScope _of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!;
  }

  static LedgerRepository of(BuildContext context) => _of(context).repo;
  static SettingsStore settingsOf(BuildContext context) => _of(context).settings;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.repo != repo || oldWidget.settings != settings;
}
