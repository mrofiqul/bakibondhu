import 'package:flutter/widgets.dart';

import 'package:bakibondhu/data/auth_api.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/data/session.dart';
import 'package:bakibondhu/data/settings_store.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';

/// Makes shared services available to any widget below via `AppScope.*(context)`
/// so screens don't construct their own storage. [syncEngine] is null until a
/// backend/API is configured; [session] holds the (optional) signed-in JWT.
class AppScope extends InheritedWidget {
  final LedgerRepository repo;
  final SettingsStore settings;
  final SyncStore syncStore;
  final SyncEngine? syncEngine;
  final Session session;
  final AuthApi authApi;

  const AppScope({
    required this.repo,
    required this.settings,
    required this.syncStore,
    required this.session,
    required this.authApi,
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
  static Session sessionOf(BuildContext context) => _of(context).session;
  static AuthApi authApiOf(BuildContext context) => _of(context).authApi;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.repo != repo ||
      oldWidget.settings != settings ||
      oldWidget.syncStore != syncStore ||
      oldWidget.syncEngine != syncEngine ||
      oldWidget.session != session ||
      oldWidget.authApi != authApi;
}
