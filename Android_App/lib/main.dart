import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:bakibondhu/app.dart';
import 'package:bakibondhu/core/config.dart';
import 'package:bakibondhu/core/language.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/data/auth_api.dart';
import 'package:bakibondhu/data/infinityfree_client.dart';
import 'package:bakibondhu/data/local_database.dart';
import 'package:bakibondhu/data/session.dart';
import 'package:bakibondhu/data/shared_prefs_settings_store.dart';
import 'package:bakibondhu/data/sqflite_ledger_repository.dart';
import 'package:bakibondhu/sync/http_sync_api.dart';
import 'package:bakibondhu/sync/sqflite_sync_store.dart';
import 'package:bakibondhu/sync/auto_sync.dart';
import 'package:bakibondhu/sync/sync_engine.dart';

/// Entry point. Opens the local SQLite store, settings and session
/// (offline-first), wires the sync engine + auth to the backend, then starts.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openLocalDatabase();
  final repo = SqfliteLedgerRepository(db);
  final syncStore = SqfliteSyncStore(db);

  final prefs = await SharedPreferences.getInstance();
  final settings = SharedPrefsSettingsStore(prefs);
  final onboarded = await settings.onboardingComplete();

  // Apply the UI language before the first frame. If the owner has chosen one,
  // honour it; otherwise default by device region — English outside Bangladesh,
  // Bangla for Bangladesh (or unknown).
  final savedCode = await settings.language();
  final AppLang startLang;
  if (savedCode != null) {
    startLang = langFromCode(savedCode);
  } else {
    final country =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode
            ?.toUpperCase();
    startLang = (country != null && country.isNotEmpty && country != 'BD')
        ? AppLang.en
        : AppLang.bn;
  }
  S.lang = startLang;
  appLanguage.value = startLang;

  final session = Session(const FlutterSecureStorage());
  await session.load();

  // Opening screen: show the Login/Register landing only until the user has
  // either signed in or finished offline setup (shop-name onboarding).
  final startLanding = !onboarded && session.token == null;

  final baseUrl = Uri.parse(kSyncBaseUrl);

  // Shared HTTP client that passes free-host "browser check" challenges so the
  // app can reach the backend (see InfinityFreeClient); inert on normal hosts.
  final httpClient = InfinityFreeClient();

  final authApi = AuthApi(baseUrl: baseUrl, client: httpClient);

  // A stable per-install device id (idempotency key on the server).
  var deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }

  final syncApi = HttpSyncApi(
    baseUrl: baseUrl,
    accessToken: () => session.token ?? '', // empty until logged in
    client: httpClient,
  );
  final syncEngine = SyncEngine(
    api: syncApi,
    store: syncStore,
    deviceId: deviceId,
    // Keep the trial-ending reminder current if the admin changes the expiry.
    onExpiryPulled: (expiresAt) => session.updateExpiresAt(expiresAt),
  );

  // Auto-sync: pushes/pulls whenever the device is online (startup, reconnect,
  // app resume, and a light pending-changes poll) — no manual "Sync now" needed.
  AutoSync(engine: syncEngine, session: session, store: syncStore).start();

  runApp(BakiBondhuApp(
    repo: repo,
    settings: settings,
    syncStore: syncStore,
    syncEngine: syncEngine,
    session: session,
    authApi: authApi,
    startLanding: startLanding,
  ));
}
