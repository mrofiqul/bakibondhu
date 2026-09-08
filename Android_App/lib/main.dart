import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:bakibondhu/app.dart';
import 'package:bakibondhu/data/local_database.dart';
import 'package:bakibondhu/data/shared_prefs_settings_store.dart';
import 'package:bakibondhu/data/sqflite_ledger_repository.dart';
import 'package:bakibondhu/sync/http_sync_api.dart';
import 'package:bakibondhu/sync/sqflite_sync_store.dart';
import 'package:bakibondhu/sync/sync_engine.dart';

/// Backend base URL. Defaults to the Android-emulator host loopback (10.0.2.2)
/// pointing at the dev API on :5080. Override at build/run time with:
///   flutter run --dart-define=SYNC_BASE_URL=http://192.168.0.10:5080
const String kSyncBaseUrl =
    String.fromEnvironment('SYNC_BASE_URL', defaultValue: 'http://10.0.2.2:5080');

/// Entry point. Opens the local SQLite store and settings (offline-first),
/// wires the sync engine to the backend, then starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openLocalDatabase();
  final repo = SqfliteLedgerRepository(db);
  final syncStore = SqfliteSyncStore(db);

  final prefs = await SharedPreferences.getInstance();
  final settings = SharedPrefsSettingsStore(prefs);
  final onboarded = await settings.onboardingComplete();

  // A stable per-install device id (idempotency key on the server).
  var deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }

  final syncApi = HttpSyncApi(
    baseUrl: Uri.parse(kSyncBaseUrl),
    accessToken: () => 'dev-token', // real JWT once auth exists
  );
  final syncEngine =
      SyncEngine(api: syncApi, store: syncStore, deviceId: deviceId);

  runApp(BakiBondhuApp(
    repo: repo,
    settings: settings,
    syncStore: syncStore,
    syncEngine: syncEngine,
    startOnboarding: !onboarded,
  ));
}
