import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bakibondhu/app.dart';
import 'package:bakibondhu/data/local_database.dart';
import 'package:bakibondhu/data/shared_prefs_settings_store.dart';
import 'package:bakibondhu/data/sqflite_ledger_repository.dart';

/// Entry point. Opens the local SQLite store and settings (offline-first),
/// then starts the app — on onboarding the first time, else on Home.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openLocalDatabase();
  final repo = SqfliteLedgerRepository(db);

  final prefs = await SharedPreferences.getInstance();
  final settings = SharedPrefsSettingsStore(prefs);
  final onboarded = await settings.onboardingComplete();

  runApp(BakiBondhuApp(
    repo: repo,
    settings: settings,
    startOnboarding: !onboarded,
  ));
}
