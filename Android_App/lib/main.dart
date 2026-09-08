import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bakibondhu/app.dart';
import 'package:bakibondhu/data/local_database.dart';
import 'package:bakibondhu/data/shared_prefs_settings_store.dart';
import 'package:bakibondhu/data/sqflite_ledger_repository.dart';
import 'package:bakibondhu/sync/sqflite_sync_store.dart';

/// Entry point. Opens the local SQLite store and settings (offline-first),
/// then starts the app — on onboarding the first time, else on Home.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openLocalDatabase();
  final repo = SqfliteLedgerRepository(db);
  final syncStore = SqfliteSyncStore(db);

  final prefs = await SharedPreferences.getInstance();
  final settings = SharedPrefsSettingsStore(prefs);
  final onboarded = await settings.onboardingComplete();

  runApp(BakiBondhuApp(
    repo: repo,
    settings: settings,
    syncStore: syncStore,
    // syncEngine stays null until a backend/API is configured; the Sync Center
    // still shows local status without it.
    startOnboarding: !onboarded,
  ));
}
