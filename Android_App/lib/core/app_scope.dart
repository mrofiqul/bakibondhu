import 'package:flutter/widgets.dart';

import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/data/settings_store.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';

/// Makes shared services available to any widget below via `AppScope.*(context)`
/// so screens don't construct their own storage. [syncEngine] is null until a
/// backend/API is configured; the Sync Center still shows status without it.
class AppScope extends InheritedWidget {
  final LedgerRepository repo;
  final SettingsStore settings;
  final SyncStore syncStore;
  final SyncEngine? syncEngine;

  const AppScope({
    required this.repo,
    required this.settings,
    required this.syncStore,
    this.syncEngine,
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
  static SyncStore syncStoreOf(BuildContext context) => _of(context).syncStore;
  static SyncEngine? syncEngineOf(BuildContext context) => _of(context).syncEngine;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.repo != repo ||
      oldWidget.settings != settings ||
      oldWidget.syncStore != syncStore ||
      oldWidget.syncEngine != syncEngine;
}
